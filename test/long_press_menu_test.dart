import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinterest_long_press_menu/src/app.dart';
import 'package:pinterest_long_press_menu/src/keys.dart';
import 'package:pinterest_long_press_menu/src/long_press_menu.dart';
import 'package:pinterest_long_press_menu/src/long_press_menu_metrics.dart';
import 'package:pinterest_long_press_menu/src/menu_geometry.dart';
import 'package:pinterest_long_press_menu/src/pin.dart';
import 'package:pinterest_long_press_menu/src/sample_pins.dart';

/// 実機に近いスマートフォン縦向き。
const Size _phoneSize = Size(390, 844);

/// 下部ナビの帯より上で、ピンが完全に見えているとみなす範囲。
const Rect _pressableArea = Rect.fromLTRB(0, 0, 390, 740);

/// 認識を待つときに長押し時間へ足す余裕。
const Duration _afterRecognition = Duration(milliseconds: 50);

/// 強調判定の距離 (38.4) より確実に遠い距離。
const double _wellOutsideAnyButton = 60;

/// アクションボタン中心の許容誤差。
const double _centerTolerance = 0.5;

/// 縦ドラッグを開始させる最初の移動量。タッチスロップ (18) を確実に超える。
///
/// 縦ドラッグは複数回に分けて動かす。SDK 既定の [DragStartBehavior.start] では、
/// ジェスチャー競合を解決した分の移動がスクロールに反映されないため、1回の大きな
/// 移動だとスクロール量が 0 のままになる ([WidgetTester.drag] も同じ理由で内部的に
/// 分けている)。
const double _dragStartStep = 30;

/// 浮き上がったピンが元のピンに重なっているとみなす許容誤差。
///
/// 拡大も傾きも中心を軸にするので中心座標は動かない。押下点を基準に置いてしまう
/// 実装との差 (数十px) は見逃さない大きさにしてある。
const double _liftedPinTolerance = 4;

/// テストの画面サイズを固定し、終了時に元へ戻す。
void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// フィードの縦スクロール位置。
///
/// タブ行も横スクロールを持つので、縦向きの [Scrollable] だけを選ぶ。
ScrollPosition _feedScrollPosition(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byKey(SampleKeys.feed),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  return tester.state<ScrollableState>(scrollable).position;
}

/// 開いている長押しメニューと、押したままのジェスチャー。
class _OpenedMenu {
  _OpenedMenu({
    required this.gesture,
    required this.pressPoint,
    required this.buttonCenters,
  });

  /// まだ指を離していないジェスチャー。
  final TestGesture gesture;

  /// 長押しが認識された位置。
  final Offset pressPoint;

  /// 開いた直後のアクションボタン中心。[PinAction.values] の順。
  final List<Offset> buttonCenters;
}

/// [pressPoint] で長押しメニューを開き、開いたことを確かめてから返す。
Future<_OpenedMenu> _openLongPressMenu(
  WidgetTester tester,
  Offset pressPoint,
) async {
  final gesture = await tester.startGesture(pressPoint, pointer: 1);
  await tester.pump(LongPressMenuMetrics.longPressDuration + _afterRecognition);
  await tester.pumpAndSettle();

  expect(
    find.byKey(SampleKeys.dimming),
    findsOneWidget,
    reason: '長押しメニューが開いている',
  );
  for (final action in PinAction.values) {
    expect(
      find.byKey(SampleKeys.actionButton(action)),
      findsOneWidget,
      reason: '${action.name} のアクションボタンが開いている',
    );
  }

  return _OpenedMenu(
    gesture: gesture,
    pressPoint: pressPoint,
    buttonCenters: <Offset>[
      for (final action in PinAction.values)
        tester.getCenter(find.byKey(SampleKeys.actionButton(action))),
    ],
  );
}

/// いま強調されているアクション。[PinAction.values] の順。
List<PinAction> _highlightedActions(WidgetTester tester) {
  return <PinAction>[
    for (final action in PinAction.values)
      if (tester
          .widget<ActionButtonView>(find.byKey(SampleKeys.actionButton(action)))
          .highlighted)
        action,
  ];
}

/// 描画されたアクションボタンの強調を主張する。
///
/// [highlighted] のボタンは [LongPressMenuMetrics.highlightedActionButtonColor] の
/// 背景で [LongPressMenuMetrics.highlightScale] 倍、それ以外は
/// [LongPressMenuMetrics.actionButtonColor] の背景で等倍。
void _expectRenderedHighlight(WidgetTester tester, PinAction? highlighted) {
  for (final action in PinAction.values) {
    final button = find.byKey(SampleKeys.actionButton(action));
    final decoration =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: button,
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration
            as BoxDecoration?;
    final scale = tester
        .widget<AnimatedScale>(
          find.descendant(of: button, matching: find.byType(AnimatedScale)),
        )
        .scale;
    final isHighlighted = action == highlighted;

    expect(
      decoration?.color,
      isHighlighted
          ? LongPressMenuMetrics.highlightedActionButtonColor
          : LongPressMenuMetrics.actionButtonColor,
      reason: '${action.name} のボタンの背景色 (強調: $isHighlighted)',
    );
    expect(
      scale,
      isHighlighted ? LongPressMenuMetrics.highlightScale : 1.0,
      reason: '${action.name} のボタンの拡大率 (強調: $isHighlighted)',
    );
  }
}

/// [duration] のあいだフレームを刻んで進める。
///
/// 一度に進めると、閉じるアニメーションの完了フレームを飛ばすことがある。
Future<void> _pumpFrames(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

/// 実行時に出るメッセージ。
String _executeMessage(Pin pin, PinAction action) =>
    '『${pin.title}』を${action.label}';

/// 長押しメニューが閉じていることを主張する。
void _expectMenuClosed() {
  expect(find.byKey(SampleKeys.dimming), findsNothing, reason: '暗転が消えている');
  expect(
    find.byKey(SampleKeys.liftedPin),
    findsNothing,
    reason: '浮き上がったピンが消えている',
  );
  for (final action in PinAction.values) {
    expect(
      find.byKey(SampleKeys.actionButton(action)),
      findsNothing,
      reason: '${action.name} のアクションボタンが消えている',
    );
  }
}

/// 4つのアクションボタンの中心が [pressPoint] を基準にした配置と一致することを主張する。
void _expectButtonCentersFor(List<Offset> actual, Offset pressPoint) {
  final expected = actionButtonCenters(
    pressPoint: pressPoint,
    screenSize: _phoneSize,
  );
  expect(actual.length, PinAction.values.length);
  for (var i = 0; i < expected.length; i++) {
    expect(
      actual[i].dx,
      closeTo(expected[i].dx, _centerTolerance),
      reason: '${PinAction.values[i].name} (index $i) の dx',
    );
    expect(
      actual[i].dy,
      closeTo(expected[i].dy, _centerTolerance),
      reason: '${PinAction.values[i].name} (index $i) の dy',
    );
  }
}

void main() {
  group('AC-2 ピンを500ms静止で長押し', () {
    testWidgets('暗転し、押したピンが浮き上がり、押下点の周りに4ボタンが 非表示・リアクション・共有・保存 の順で出る', (
      tester,
    ) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pinRect = tester.getRect(find.byKey(SampleKeys.pin(0)));
      // ピンの中心から外した点を押し、配置の基準がピンではなく押下点であることを見る。
      final pressPoint = pinRect.center.translate(0, -40);
      expect(pinRect.contains(pressPoint), isTrue, reason: '押下点はピンの上にある');

      final menu = await _openLongPressMenu(tester, pressPoint);

      expect(find.byKey(SampleKeys.dimming), findsOneWidget, reason: '暗転');
      expect(
        find.byKey(SampleKeys.liftedPin),
        findsOneWidget,
        reason: '浮き上がったピン',
      );
      _expectButtonCentersFor(menu.buttonCenters, pressPoint);
      expect(
        (tester.getCenter(find.byKey(SampleKeys.liftedPin)) - pinRect.center)
            .distance,
        lessThan(_liftedPinTolerance),
        reason: '浮き上がったピンは元のピンの位置に重なる',
      );

      await menu.gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('AC-3 認識前 (500ms未満) に縦に動かす', () {
    testWidgets('メニューは出ず、フィードがスクロールする', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(_feedScrollPosition(tester).pixels, 0, reason: '開始時はスクロールしていない');

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(SampleKeys.pin(0))),
        pointer: 1,
      );
      await tester.pump(const Duration(milliseconds: 100));
      // 合計 120 を [_dragStartStep] の分と残りに分けて動かす。
      await gesture.moveBy(const Offset(0, -_dragStartStep));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -90));
      await tester.pump();

      expect(
        find.byKey(SampleKeys.dimming),
        findsNothing,
        reason: '認識前に動かしたので長押しメニューは開かない',
      );
      expect(
        _feedScrollPosition(tester).pixels,
        greaterThan(0),
        reason: 'フィードがスクロールする',
      );

      await tester.pump(
        LongPressMenuMetrics.longPressDuration + _afterRecognition,
      );
      expect(
        find.byKey(SampleKeys.dimming),
        findsNothing,
        reason: '認識時間を過ぎても長押しメニューは開かない',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('AC-4 開いた状態で指を各ボタンへ動かし、離れる', () {
    testWidgets('乗ったボタンだけが強調され、離れると戻る。強調は常に最大1つ', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final menu = await _openLongPressMenu(tester, pressPoint);

      for (var i = 0; i < menu.buttonCenters.length; i++) {
        expect(
          (menu.buttonCenters[i] - pressPoint).distance,
          greaterThan(_wellOutsideAnyButton),
          reason: '押下点は ${PinAction.values[i].name} のボタンから十分離れている',
        );
      }
      expect(_highlightedActions(tester), isEmpty, reason: '開いた直後は強調なし');

      for (final action in PinAction.values) {
        await menu.gesture.moveTo(menu.buttonCenters[action.index]);
        await tester.pumpAndSettle();

        expect(
          _highlightedActions(tester),
          <PinAction>[action],
          reason: '${action.name} のボタンに乗ると ${action.name} だけが強調される',
        );
        _expectRenderedHighlight(tester, action);
      }

      await menu.gesture.moveTo(pressPoint);
      await tester.pumpAndSettle();
      expect(_highlightedActions(tester), isEmpty, reason: '指が離れると強調が戻る');

      await menu.gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('AC-5 4操作それぞれを強調して離す', () {
    for (final action in PinAction.values) {
      testWidgets('${action.label} を強調して離すとメッセージが出て閉じ、ピンは変わらない', (
        tester,
      ) async {
        _setScreenSize(tester, _phoneSize);
        await tester.pumpWidget(const App());
        await tester.pumpAndSettle();

        final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
        final menu = await _openLongPressMenu(tester, pressPoint);

        await menu.gesture.moveTo(menu.buttonCenters[action.index]);
        await tester.pumpAndSettle();
        expect(_highlightedActions(tester), <PinAction>[
          action,
        ], reason: '離す直前に ${action.name} が強調されている');

        await menu.gesture.up();
        await _pumpFrames(
          tester,
          LongPressMenuMetrics.openDuration + const Duration(milliseconds: 100),
        );

        expect(
          find.text(_executeMessage(samplePins.first, action)),
          findsOneWidget,
          reason: '${action.name} を実行したメッセージ',
        );
        _expectMenuClosed();

        for (var i = 0; i < samplePins.length; i++) {
          expect(
            find.byKey(SampleKeys.pin(i)),
            findsOneWidget,
            reason: 'index $i のピンが残っている',
          );
          expect(
            find.text(samplePins[i].title),
            findsOneWidget,
            reason: 'index $i の題名 ${samplePins[i].title} が変わっていない',
          );
        }
        expect(
          find.byKey(SampleKeys.pin(samplePins.length)),
          findsNothing,
          reason: 'ピンが増えていない',
        );

        await tester.pumpAndSettle();
      });
    }
  });

  group('AC-6 ボタンの外で離す / ジェスチャーのキャンセル', () {
    testWidgets('ボタンの外で離すとメッセージなしで閉じる', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final menu = await _openLongPressMenu(tester, pressPoint);

      for (var i = 0; i < menu.buttonCenters.length; i++) {
        expect(
          (menu.buttonCenters[i] - pressPoint).distance,
          greaterThan(_wellOutsideAnyButton),
          reason: '押下点は ${PinAction.values[i].name} のボタンから十分離れている',
        );
      }
      await menu.gesture.moveTo(pressPoint);
      await tester.pumpAndSettle();
      expect(_highlightedActions(tester), isEmpty, reason: '離す直前は強調なし');

      await menu.gesture.up();
      await _pumpFrames(
        tester,
        LongPressMenuMetrics.openDuration + const Duration(milliseconds: 100),
      );

      _expectMenuClosed();
      expect(find.textContaining('『'), findsNothing, reason: 'メッセージが出ていない');

      await tester.pumpAndSettle();
    });

    testWidgets('強調中にジェスチャーが中断されるとメッセージなしで閉じる', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final menu = await _openLongPressMenu(tester, pressPoint);

      await menu.gesture.moveTo(menu.buttonCenters[PinAction.save.index]);
      await tester.pumpAndSettle();
      expect(_highlightedActions(tester), <PinAction>[
        PinAction.save,
      ], reason: '中断される直前に保存が強調されている');

      await menu.gesture.cancel();
      await _pumpFrames(
        tester,
        LongPressMenuMetrics.openDuration + const Duration(milliseconds: 100),
      );

      _expectMenuClosed();
      expect(find.textContaining('『'), findsNothing, reason: 'メッセージが出ていない');

      await tester.pumpAndSettle();
    });
  });

  group('AC-7 表示中にスクロール操作・他のピンのタップ・2本目の指', () {
    testWidgets('フィードは動かず、他の操作は起きず、メニューは開いたまま', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final otherPinCenter = tester.getCenter(find.byKey(SampleKeys.pin(1)));
      final menu = await _openLongPressMenu(tester, pressPoint);
      final pixelsWhenOpened = _feedScrollPosition(tester).pixels;

      final scrollFinger = await tester.startGesture(
        const Offset(195, 700),
        pointer: 2,
      );
      await tester.pump();
      // 合計 200 を [_dragStartStep] の分と残りに分けて動かす。1回にまとめると、
      // 暗転層がポインタを吸収していなくてもスクロールしない空振りの主張になる。
      await scrollFinger.moveBy(const Offset(0, -_dragStartStep));
      await tester.pump();
      await scrollFinger.moveBy(const Offset(0, -170));
      await tester.pump();
      await scrollFinger.up();
      await tester.pumpAndSettle();

      expect(
        _feedScrollPosition(tester).pixels,
        moreOrLessEquals(pixelsWhenOpened, epsilon: 0.01),
        reason: '2本目の指ではフィードがスクロールしない',
      );
      expect(
        find.byKey(SampleKeys.dimming),
        findsOneWidget,
        reason: 'スクロール操作のあともメニューは開いたまま',
      );

      final tapFinger = await tester.startGesture(otherPinCenter, pointer: 3);
      await tester.pump(const Duration(milliseconds: 50));
      await tapFinger.up();
      await tester.pumpAndSettle();

      expect(
        find.byKey(SampleKeys.dimming),
        findsOneWidget,
        reason: '他のピンを押してもメニューは開いたまま',
      );
      expect(
        find.byKey(SampleKeys.liftedPin),
        findsOneWidget,
        reason: '浮き上がったピンは1枚のまま',
      );
      expect(find.textContaining('『'), findsNothing, reason: 'メッセージが出ていない');
      expect(
        _feedScrollPosition(tester).pixels,
        moreOrLessEquals(pixelsWhenOpened, epsilon: 0.01),
        reason: '他のピンを押してもフィードは動かない',
      );
      _expectButtonCentersFor(<Offset>[
        for (final action in PinAction.values)
          tester.getCenter(find.byKey(SampleKeys.actionButton(action))),
      ], pressPoint);

      // 1本目の指はまだ押したまま。離すと通常どおり閉じる。
      await menu.gesture.up();
      await tester.pumpAndSettle();
      _expectMenuClosed();
    });
  });

  group('AC-11 多数のピンでスクロール後', () {
    testWidgets('スクロール後のピンでも押下点を基準に4ボタンが出る', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(SampleKeys.feed), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        _feedScrollPosition(tester).pixels,
        greaterThan(0),
        reason: 'フィードがスクロールした',
      );

      int? scrolledIndex;
      for (var i = 0; i < samplePins.length; i++) {
        final rect = tester.getRect(find.byKey(SampleKeys.pin(i)));
        if (rect.top >= _pressableArea.top &&
            rect.bottom <= _pressableArea.bottom &&
            rect.left >= _pressableArea.left &&
            rect.right <= _pressableArea.right) {
          scrolledIndex = i;
          break;
        }
      }
      expect(scrolledIndex, isNotNull, reason: 'スクロール後に画面内へ収まっているピンがある');

      final pressPoint = tester.getCenter(
        find.byKey(SampleKeys.pin(scrolledIndex!)),
      );
      final menu = await _openLongPressMenu(tester, pressPoint);

      expect(find.byKey(SampleKeys.dimming), findsOneWidget, reason: '暗転');
      _expectButtonCentersFor(menu.buttonCenters, pressPoint);

      await menu.gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('AC-15 メニュー表示中の下部ナビ', () {
    testWidgets('ナビも暗転し、2本目の指でナビを押しても何も起きない', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final navRect = tester.getRect(find.byKey(SampleKeys.bottomNav));
      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final menu = await _openLongPressMenu(tester, pressPoint);

      final dimmingRect = tester.getRect(find.byKey(SampleKeys.dimming));
      expect(
        dimmingRect.left,
        lessThanOrEqualTo(navRect.left),
        reason: '暗転がナビの左端まで届く',
      );
      expect(
        dimmingRect.top,
        lessThanOrEqualTo(navRect.top),
        reason: '暗転がナビの上端まで届く',
      );
      expect(
        dimmingRect.right,
        greaterThanOrEqualTo(navRect.right),
        reason: '暗転がナビの右端まで届く',
      );
      expect(
        dimmingRect.bottom,
        greaterThanOrEqualTo(navRect.bottom),
        reason: '暗転がナビの下端まで届く',
      );

      final navFinger = await tester.startGesture(navRect.center, pointer: 2);
      await tester.pump(const Duration(milliseconds: 50));
      await navFinger.up();
      await tester.pumpAndSettle();

      expect(
        find.byKey(SampleKeys.dimming),
        findsOneWidget,
        reason: 'ナビを押してもメニューは開いたまま',
      );
      expect(find.textContaining('『'), findsNothing, reason: 'メッセージが出ていない');

      await menu.gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
