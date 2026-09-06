import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinterest_long_press_menu/src/app.dart';
import 'package:pinterest_long_press_menu/src/keys.dart';
import 'package:pinterest_long_press_menu/src/long_press_menu.dart';
import 'package:pinterest_long_press_menu/src/long_press_menu_metrics.dart';
import 'package:pinterest_long_press_menu/src/pin.dart';
import 'package:pinterest_long_press_menu/src/sample_pins.dart';

/// 実機に近いスマートフォン縦向き。
const Size _phoneSize = Size(390, 844);

/// 認識を待つときに長押し時間へ足す余裕。
const Duration _afterRecognition = Duration(milliseconds: 50);

/// 強調判定の距離 (38.4) より確実に遠い距離。
const double _wellOutsideAnyButton = 60;

/// 触覚の要求が届くプラットフォームチャネルのメソッド名。
const String _hapticMethod = 'HapticFeedback.vibrate';

/// 長押しメニューが開いた瞬間の触覚。
const String _mediumImpact = 'HapticFeedbackType.mediumImpact';

/// 指がアクションボタンに乗った瞬間の触覚。
const String _selectionClick = 'HapticFeedbackType.selectionClick';

/// 同じアクションボタンの上で指を動かす距離。
///
/// アクションボタンどうしは 66px 離れており、強調判定の距離は 38.4px なので、
/// この範囲で動かしても乗っているアクションボタンは変わらない。
const List<double> _sameButtonNudges = <double>[5, 10];

/// テストの画面サイズを固定し、終了時に元へ戻す。
void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// 触覚の要求を出た順に記録し始め、終了時に記録をやめる。
///
/// 返すのは記録そのもの。引数を型変換せずそのまま入れるので、引数なしの
/// `HapticFeedback.vibrate()` が呼ばれた場合も null として現れる。
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

/// 開いている長押しメニューと、押したままのジェスチャー。
class _OpenedMenu {
  _OpenedMenu({required this.gesture, required this.buttonCenters});

  /// まだ指を離していないジェスチャー。
  final TestGesture gesture;

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

/// [duration] のあいだフレームを刻んで進める。
///
/// 一度に進めると、閉じるアニメーションの完了フレームを飛ばすことがある。
Future<void> _pumpFrames(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

/// [center] から [pressPoint] の方へ [distance] だけ寄せた点。
///
/// アクションボタンは押下点を中心とした円弧に並ぶので、押下点の方へ寄せても
/// 最も近いアクションボタンは変わらない。
Offset _towardPressPoint(Offset center, Offset pressPoint, double distance) {
  final toPressPoint = pressPoint - center;
  return center + toPressPoint / toPressPoint.distance * distance;
}

void main() {
  group('AC-14 長押しで開く → ボタンに乗る → 離れる → 別のボタンに乗る → 実行', () {
    testWidgets('触覚の要求は開いた時の1回と乗った時の2回の計3回。離れた時と実行時には出ない', (tester) async {
      _setScreenSize(tester, _phoneSize);
      final hapticRequests = _recordHapticRequests();

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      expect(hapticRequests, isEmpty, reason: '長押しの前は触覚を要求しない');

      // 弧に沿った両端。互いに十分離れており、乗り直しが1回ずつ数えられる。
      const firstAction = PinAction.hide;
      const secondAction = PinAction.save;

      final pressPoint = tester.getCenter(find.byKey(SampleKeys.pin(0)));
      final menu = await _openLongPressMenu(tester, pressPoint);

      expect(hapticRequests, <Object?>[
        _mediumImpact,
      ], reason: '長押しメニューが開いた瞬間に1回');

      // 押下点はどのアクションボタンからも遠い。あとで指を戻す先に使う。
      for (var i = 0; i < menu.buttonCenters.length; i++) {
        expect(
          (menu.buttonCenters[i] - pressPoint).distance,
          greaterThan(_wellOutsideAnyButton),
          reason: '押下点は ${PinAction.values[i].name} のアクションボタンから十分離れている',
        );
      }
      expect(_highlightedActions(tester), isEmpty, reason: '開いた直後は強調なし');

      await menu.gesture.moveTo(menu.buttonCenters[firstAction.index]);
      await tester.pumpAndSettle();
      expect(_highlightedActions(tester), <PinAction>[
        firstAction,
      ], reason: '${firstAction.name} のアクションボタンに乗っている');
      expect(hapticRequests, <Object?>[
        _mediumImpact,
        _selectionClick,
      ], reason: '${firstAction.name} のアクションボタンに乗った瞬間にもう1回');

      for (final nudge in _sameButtonNudges) {
        await menu.gesture.moveTo(
          _towardPressPoint(
            menu.buttonCenters[firstAction.index],
            pressPoint,
            nudge,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          _highlightedActions(tester),
          <PinAction>[firstAction],
          reason: '${nudge}px 動かしても ${firstAction.name} に乗ったまま',
        );
        expect(hapticRequests, <Object?>[
          _mediumImpact,
          _selectionClick,
        ], reason: '同じアクションボタンの上で動かしても増えない');
      }

      await menu.gesture.moveTo(pressPoint);
      await tester.pumpAndSettle();
      expect(_highlightedActions(tester), isEmpty, reason: 'どのアクションボタンからも離れた');
      expect(hapticRequests, <Object?>[
        _mediumImpact,
        _selectionClick,
      ], reason: 'アクションボタンから離れた時には出ない');

      await menu.gesture.moveTo(menu.buttonCenters[secondAction.index]);
      await tester.pumpAndSettle();
      expect(
        _highlightedActions(tester),
        <PinAction>[secondAction],
        reason: '${secondAction.name} のアクションボタンに乗っている',
      );
      expect(hapticRequests, <Object?>[
        _mediumImpact,
        _selectionClick,
        _selectionClick,
      ], reason: '別のアクションボタンに乗り直した瞬間にもう1回');

      await menu.gesture.up();
      await _pumpFrames(
        tester,
        LongPressMenuMetrics.openDuration + const Duration(milliseconds: 100),
      );

      expect(
        find.text('『${samplePins.first.title}』を${secondAction.label}'),
        findsOneWidget,
        reason: '${secondAction.name} が実行された',
      );
      expect(hapticRequests, <Object?>[
        _mediumImpact,
        _selectionClick,
        _selectionClick,
      ], reason: '実行された上で、実行時には出ない');

      await tester.pumpAndSettle();
    });
  });
}
