// 利用例アプリが鳴らす触覚フィードバックのテスト (前 spec AC-14。新 spec AC-18)。
//
// パッケージは触覚を鳴らさない。開いた時と強調が変わった時の通知を受けて
// 利用例アプリが鳴らすので、その要求の回数と順序をここで見る。

import 'package:fan_context_menu/fan_context_menu.dart';
import 'package:fan_context_menu_example/src/app.dart';
import 'package:fan_context_menu_example/src/keys.dart';
import 'package:fan_context_menu_example/src/pin.dart';
import 'package:fan_context_menu_example/src/sample_pins.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実機に近いスマートフォン縦向き。
const Size _phoneSize = Size(390, 844);

/// 省略時の基準値。時間と距離はここから読む。
const FanContextMenuStyle _style = FanContextMenuStyle();

/// 認識を待つときに長押し時間へ足す余裕。
const Duration _afterRecognition = Duration(milliseconds: 50);

/// 触覚の要求が届くプラットフォームチャネルのメソッド名。
const String _hapticMethod = 'HapticFeedback.vibrate';

/// 長押しメニューが開いた瞬間の触覚。
const String _mediumImpact = 'HapticFeedbackType.mediumImpact';

/// 指がアクションボタンに乗った瞬間の触覚。
const String _selectionClick = 'HapticFeedbackType.selectionClick';

/// 同じアクションボタンの上で指を動かす距離。
///
/// アクションボタンは押下点から [FanContextMenuStyle.arcRadius] のところにあり、
/// 強調の当たり判定は [FanContextMenuStyle.highlightThreshold] なので、この範囲で
/// 動かしても乗っているアクションボタンは変わらない。
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

  for (final action in PinAction.values) {
    expect(
      find.bySemanticsLabel(action.semanticsLabel),
      findsOneWidget,
      reason: '${action.name} のアクションボタンが開いている',
    );
  }

  return _OpenedMenu(
    gesture: gesture,
    buttonCenters: <Offset>[
      for (final action in PinAction.values)
        tester.getCenter(find.bySemanticsLabel(action.semanticsLabel)),
    ],
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

/// [center] から [pressPoint] の方へ [distance] だけ寄せた点。
///
/// アクションボタンは押下点を中心とした円弧に並ぶので、押下点の方へ寄せても
/// 最も近いアクションボタンは変わらない。
Offset _towardPressPoint(Offset center, Offset pressPoint, double distance) {
  final toPressPoint = pressPoint - center;
  return center + toPressPoint / toPressPoint.distance * distance;
}

void main() {
  group('前 spec AC-14 長押しで開く → ボタンに乗る → 離れる → 別のボタンに乗る → 実行', () {
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
      ], reason: '長押しメニューが開いた瞬間に1回。開いた直後はどのアクションボタンにも乗っていない');

      // 押下点はどのアクションボタンからも遠い。あとで指を戻す先に使う。
      for (var i = 0; i < menu.buttonCenters.length; i++) {
        expect(
          (menu.buttonCenters[i] - pressPoint).distance,
          greaterThan(_style.highlightThreshold),
          reason: '押下点は ${PinAction.values[i].name} のアクションボタンから十分離れている',
        );
      }

      await menu.gesture.moveTo(menu.buttonCenters[firstAction.index]);
      await tester.pumpAndSettle();
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
        expect(hapticRequests, <Object?>[
          _mediumImpact,
          _selectionClick,
        ], reason: '同じアクションボタンの上で ${nudge}px 動かしても増えない');
      }

      await menu.gesture.moveTo(pressPoint);
      await tester.pumpAndSettle();
      expect(hapticRequests, <Object?>[
        _mediumImpact,
        _selectionClick,
      ], reason: 'アクションボタンから離れた時には出ない');

      await menu.gesture.moveTo(menu.buttonCenters[secondAction.index]);
      await tester.pumpAndSettle();
      expect(hapticRequests, <Object?>[
        _mediumImpact,
        _selectionClick,
        _selectionClick,
      ], reason: '別のアクションボタンに乗り直した瞬間にもう1回');

      await menu.gesture.up();
      await _pumpFrames(
        tester,
        _style.openDuration + const Duration(milliseconds: 100),
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
