// 利用例アプリで長押しメニューを開いてから閉じるまでのテスト
// (前 spec AC-2 / AC-3 / AC-4 / AC-5 / AC-6 / AC-7 / AC-11 / AC-15。新 spec AC-18)。
//
// 公開入口 (package:fan_context_menu/fan_context_menu.dart) と利用例アプリ自身の
// ファイルだけで書く。開閉はアクションボタンの見え方と実行メッセージで観測し、
// 強調は利用例アプリが鳴らす触覚の要求で観測する。暗転・浮き上がった複製の描画と
// アクションボタンの座標はパッケージ本体のテストに委ねる。

import 'package:fan_context_menu/fan_context_menu.dart';
import 'package:fan_context_menu_example/src/app.dart';
import 'package:fan_context_menu_example/src/keys.dart';
import 'package:fan_context_menu_example/src/pin.dart';
import 'package:fan_context_menu_example/src/sample_pins.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実機に近いスマートフォン縦向き。
const Size _phoneSize = Size(390, 844);

/// 下部ナビの帯より上で、ピンが完全に見えているとみなす範囲。
const Rect _pressableArea = Rect.fromLTRB(0, 0, 390, 740);

/// 省略時の基準値。時間と距離はここから読む。
const FanContextMenuStyle _style = FanContextMenuStyle();

/// 認識を待つときに長押し時間へ足す余裕。
const Duration _afterRecognition = Duration(milliseconds: 50);

/// アクションボタン中心の許容誤差。
const double _centerTolerance = 0.5;

/// アクションボタン中心が押下点から離れている距離の下限・上限。
///
/// 「押下点の周りに出る」ことだけを見る幅を持たせた範囲。正確な座標は
/// パッケージ本体の配置計算のテストで見る。
const double _minButtonDistance = 30;
const double _maxButtonDistance = 120;

/// 縦ドラッグを開始させる最初の移動量。タッチスロップ (18) を確実に超える。
///
/// 縦ドラッグは複数回に分けて動かす。SDK 既定の [DragStartBehavior.start] では、
/// ジェスチャー競合を解決した分の移動がスクロールに反映されないため、1回の大きな
/// 移動だとスクロール量が 0 のままになる ([WidgetTester.drag] も同じ理由で内部的に
/// 分けている)。
const double _dragStartStep = 30;

/// 触覚の要求が届くプラットフォームチャネルのメソッド名。
const String _hapticMethod = 'HapticFeedback.vibrate';

/// 指がアクションボタンに乗った瞬間の触覚。強調が変わったことの観測に使う。
const String _selectionClick = 'HapticFeedbackType.selectionClick';

/// テストの画面サイズを固定し、終了時に元へ戻す。
void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// 触覚の要求を出た順に記録し始め、終了時に記録をやめる。
List<Object?> _recordHapticRequests() {
  final requests = <Object?>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == _hapticMethod) {
      requests.add(call.arguments);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return requests;
}

/// [requests] のうち、指がアクションボタンに乗った瞬間の触覚の数。
int _selectionClickCount(List<Object?> requests) =>
    requests.where((request) => request == _selectionClick).length;

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

/// いま出ているアクションボタンの中心。[PinAction.values] の順。
List<Offset> _actionButtonCenters(WidgetTester tester) {
  return <Offset>[
    for (final action in PinAction.values)
      tester.getCenter(find.bySemanticsLabel(action.semanticsLabel)),
  ];
}

/// 4つのアクションボタンが出ていることを主張する。
///
/// アクションボタンは開いているあいだだけ、操作の読み上げ名を持つ意味ノードとして
/// 現れる (公開面からの観測方法)。
void _expectMenuOpen(String moment) {
  for (final action in PinAction.values) {
    expect(
      find.bySemanticsLabel(action.semanticsLabel),
      findsOneWidget,
      reason: '$moment: ${action.name} のアクションボタンが出ている',
    );
  }
}

/// 長押しメニューが閉じていることを主張する。
void _expectMenuClosed() {
  for (final action in PinAction.values) {
    expect(
      find.bySemanticsLabel(action.semanticsLabel),
      findsNothing,
      reason: '${action.name} のアクションボタンが消えている',
    );
  }
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
///
/// 開いているあいだは押したピンの child がもう一度描かれるので、ピンの Key や
/// 題名から位置を測るのは開く前に済ませておくこと。
Future<_OpenedMenu> _openLongPressMenu(
  WidgetTester tester,
  Offset pressPoint,
) async {
  final gesture = await tester.startGesture(pressPoint, pointer: 1);
  await tester.pump(_style.longPressDuration + _afterRecognition);
  await tester.pumpAndSettle();

  _expectMenuOpen('長押しの認識後');

  return _OpenedMenu(
    gesture: gesture,
    pressPoint: pressPoint,
    buttonCenters: _actionButtonCenters(tester),
  );
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

/// 閉じるアニメーションが終わるまで待つ。
Future<void> _pumpUntilClosed(WidgetTester tester) async {
  await _pumpFrames(
    tester,
    _style.openDuration + const Duration(milliseconds: 100),
  );
}

/// 実行時に出るメッセージ。
String _executeMessage(Pin pin, PinAction action) =>
    '『${pin.title}』を${action.label}';

/// 4つのアクションボタンが押下点の周りに出ていることを主張する。
///
/// 座標そのものはパッケージ本体の配置計算のテストで見る。ここでは押下点を基準に
/// した弧の上にあること (どのボタンも押下点から離れすぎず近すぎないこと) だけを見る。
void _expectButtonsAroundPressPoint(_OpenedMenu menu) {
  expect(menu.buttonCenters, hasLength(PinAction.values.length));
  for (var i = 0; i < menu.buttonCenters.length; i++) {
    final distance = (menu.buttonCenters[i] - menu.pressPoint).distance;
    expect(
      distance,
      inInclusiveRange(_minButtonDistance, _maxButtonDistance),
      reason: '${PinAction.values[i].name} のアクションボタンは押下点の周りにある',
    );
  }
}

/// 押下点がどのアクションボタンからも強調の当たり判定より遠いことを主張する。
void _expectPressPointOutsideEveryButton(_OpenedMenu menu) {
  for (var i = 0; i < menu.buttonCenters.length; i++) {
    expect(
      (menu.buttonCenters[i] - menu.pressPoint).distance,
      greaterThan(_style.highlightThreshold),
      reason: '押下点は ${PinAction.values[i].name} のアクションボタンから十分離れている',
    );
  }
}

void main() {
  group('前 spec AC-2 ピンを500ms静止で長押し', () {
    testWidgets('押下点の周りに 非表示・リアクション・共有・保存 の4つのアクションボタンが出る', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pinRect = tester.getRect(find.byKey(SampleKeys.pin(0)));
      // ピンの中心から外した点を押し、配置の基準がピンではなく押下点であることを見る。
      final pressPoint = pinRect.center.translate(0, -40);
      expect(pinRect.contains(pressPoint), isTrue, reason: '押下点はピンの上にある');

      final menu = await _openLongPressMenu(tester, pressPoint);

      _expectButtonsAroundPressPoint(menu);

      await menu.gesture.up();
      await _pumpUntilClosed(tester);
      _expectMenuClosed();
    });
  });

  group('前 spec AC-3 認識前 (500ms未満) に縦に動かす', () {
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

      _expectMenuClosed();
      expect(
        _feedScrollPosition(tester).pixels,
        greaterThan(0),
        reason: 'フィードがスクロールする',
      );

      await tester.pump(_style.longPressDuration + _afterRecognition);
      _expectMenuClosed();

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('前 spec AC-4 開いた状態で指を各ボタンへ動かし、離れる', () {
    testWidgets('乗ったボタンへ強調が1つずつ移り、離れると戻る', (tester) async {
      _setScreenSize(tester, _phoneSize);
      final hapticRequests = _recordHapticRequests();
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final menu = await _openLongPressMenu(tester, pressPoint);

      _expectPressPointOutsideEveryButton(menu);
      expect(
        _selectionClickCount(hapticRequests),
        0,
        reason: '開いた直後はどのアクションボタンにも乗っていない',
      );

      // 乗り換えるたびに触覚は1回だけ増える。同時に2つ強調されるなら、
      // 1回の乗り換えで2回増えてしまう。
      for (final action in PinAction.values) {
        await menu.gesture.moveTo(menu.buttonCenters[action.index]);
        await tester.pumpAndSettle();

        expect(
          _selectionClickCount(hapticRequests),
          action.index + 1,
          reason: '${action.name} のアクションボタンに乗ると強調が1つだけ移る',
        );
      }

      await menu.gesture.moveTo(pressPoint);
      await tester.pumpAndSettle();
      expect(
        _selectionClickCount(hapticRequests),
        PinAction.values.length,
        reason: 'アクションボタンから離れても強調は増えない',
      );

      await menu.gesture.up();
      await _pumpUntilClosed(tester);

      _expectMenuClosed();
      expect(
        find.textContaining('『'),
        findsNothing,
        reason: '指が離れて強調が戻っているので、離しても実行されない',
      );

      await tester.pumpAndSettle();
    });
  });

  group('前 spec AC-5 4操作それぞれを強調して離す', () {
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

        await menu.gesture.up();
        await _pumpUntilClosed(tester);

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

  group('前 spec AC-6 ボタンの外で離す / ジェスチャーのキャンセル', () {
    testWidgets('ボタンの外で離すとメッセージなしで閉じる', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final menu = await _openLongPressMenu(tester, pressPoint);

      _expectPressPointOutsideEveryButton(menu);
      await menu.gesture.moveTo(pressPoint);
      await tester.pumpAndSettle();

      await menu.gesture.up();
      await _pumpUntilClosed(tester);

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

      await menu.gesture.cancel();
      await _pumpUntilClosed(tester);

      _expectMenuClosed();
      expect(find.textContaining('『'), findsNothing, reason: 'メッセージが出ていない');

      await tester.pumpAndSettle();
    });
  });

  group('前 spec AC-7 表示中にスクロール操作・他のピンのタップ・2本目の指', () {
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
      // 長押しメニューがポインタを吸収していなくてもスクロールしない空振りの主張になる。
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
      _expectMenuOpen('スクロール操作のあと');

      final tapFinger = await tester.startGesture(otherPinCenter, pointer: 3);
      await tester.pump(const Duration(milliseconds: 50));
      await tapFinger.up();
      await tester.pumpAndSettle();

      _expectMenuOpen('他のピンを押したあと');
      expect(find.textContaining('『'), findsNothing, reason: 'メッセージが出ていない');
      expect(
        _feedScrollPosition(tester).pixels,
        moreOrLessEquals(pixelsWhenOpened, epsilon: 0.01),
        reason: '他のピンを押してもフィードは動かない',
      );
      final centersNow = _actionButtonCenters(tester);
      for (var i = 0; i < centersNow.length; i++) {
        expect(
          (centersNow[i] - menu.buttonCenters[i]).distance,
          lessThan(_centerTolerance),
          reason: '${PinAction.values[i].name} のアクションボタンは開いた時の位置のまま',
        );
      }

      // 1本目の指はまだ押したまま。離すと通常どおり閉じる。
      await menu.gesture.up();
      await _pumpUntilClosed(tester);
      _expectMenuClosed();
    });
  });

  group('前 spec AC-11 多数のピンでスクロール後', () {
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

      _expectButtonsAroundPressPoint(menu);

      await menu.gesture.up();
      await _pumpUntilClosed(tester);
      _expectMenuClosed();
    });
  });

  group('前 spec AC-15 メニュー表示中の下部ナビ', () {
    testWidgets('ナビはホストの内側にあり、2本目の指でナビを押しても何も起きない', (tester) async {
      _setScreenSize(tester, _phoneSize);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // ナビがホストの内側にある = 暗転もナビの上に掛かる範囲にいる。
      expect(
        find.descendant(
          of: find.byType(FanContextMenuHost),
          matching: find.byKey(SampleKeys.bottomNav),
        ),
        findsOneWidget,
        reason: '下部ナビはホストが暗転させる範囲の内側にある',
      );

      final navRect = tester.getRect(find.byKey(SampleKeys.bottomNav));
      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final menu = await _openLongPressMenu(tester, pressPoint);

      final navFinger = await tester.startGesture(navRect.center, pointer: 2);
      await tester.pump(const Duration(milliseconds: 50));
      await navFinger.up();
      await tester.pumpAndSettle();

      _expectMenuOpen('ナビを押したあと');
      expect(find.textContaining('『'), findsNothing, reason: 'メッセージが出ていない');

      await menu.gesture.up();
      await _pumpUntilClosed(tester);
      _expectMenuClosed();
    });
  });
}
