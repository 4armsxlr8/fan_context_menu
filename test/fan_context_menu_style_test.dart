// Style の色・寸法・時間が表示と動作に反映されることのテスト (AC-15)。

import 'package:fan_context_menu/fan_context_menu.dart';
// パッケージ本体の test/ だけが使ってよい内部 Widget。
import 'package:fan_context_menu/src/long_press_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fan_context_menu_test_helpers.dart';

/// 省略時とはすべて違う基準値。
///
/// 時間は省略時より短くし、省略時の時間を待たずに開閉することで反映を見る。
const FanContextMenuStyle _customStyle = FanContextMenuStyle(
  longPressDuration: Duration(milliseconds: 300),
  openDuration: Duration(milliseconds: 60),
  highlightDuration: Duration(milliseconds: 40),
  dimmingOpacity: 0.35,
  liftScale: 1.2,
  tiltDegrees: -6,
  buttonDiameter: 60,
  highlightScale: 1.5,
  actionButtonEnterScale: 0.4,
  arcRadius: 90,
  sweepDegrees: 160,
  arcLiftDegrees: 30,
  actionButtonColor: Color(0xFF112233),
  highlightedActionButtonColor: Color(0xFF445566),
  iconColor: Color(0xFF778899),
  highlightedIconColor: Color(0xFFAABBCC),
);

/// 開ききる・閉じきるのを待つときに開閉時間へ足す余裕 (3 フレーム)。
const Duration _afterOpenMotion = Duration(milliseconds: 48);

/// 暗転の濃さが一致しているとみなす許容誤差。
const double _alphaTolerance = 0.001;

/// アクションボタン中心と押下点の距離が半径と一致しているとみなす許容誤差。
const double _radiusTolerance = 2;

void main() {
  group('AC-15 色・寸法・時間の基準値を変えて開く', () {
    testWidgets('指定した長押し時間 (300ms) で開き、省略時の 500ms は待たない', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      expect(
        _customStyle.longPressDuration,
        lessThan(defaultStyle.longPressDuration),
        reason: '省略時より短い長押し時間で試す',
      );

      await tester.pumpWidget(hostApp(log: log, style: _customStyle));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        pressPointOn(tester, pressedPinIndex),
        pointer: 1,
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byType(DimmingLayer),
        findsNothing,
        reason: '指定した長押し時間の前は開かない',
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(
        find.byType(DimmingLayer),
        findsOneWidget,
        reason: '合計 350ms で開く (省略時の 500ms を待たない)',
      );
      expect(log, <String>['opened'], reason: '開いた時が 1 回通知される');

      await gesture.up();
      await pumpFrames(tester, _customStyle.openDuration + _afterOpenMotion);
    });

    testWidgets('指定した開閉時間 (60ms) で開ききり、閉じきる', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      expect(
        _customStyle.openDuration,
        lessThan(defaultStyle.openDuration),
        reason: '省略時より短い開閉時間で試す',
      );

      await tester.pumpWidget(hostApp(log: log, style: _customStyle));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        pressPointOn(tester, pressedPinIndex),
        pointer: 1,
      );
      await tester.pump(
        _customStyle.longPressDuration + const Duration(milliseconds: 1),
      );
      await tester.pump(_customStyle.openDuration + _afterOpenMotion);
      expect(
        find.byType(DimmingLayer),
        findsOneWidget,
        reason: '指定した長押し時間で開いている',
      );
      expect(
        dimmingAlpha(tester),
        closeTo(_customStyle.dimmingOpacity, _alphaTolerance),
        reason: '指定した開く時間で暗転が指定の濃さまで開ききる',
      );

      await gesture.up();
      await pumpFrames(tester, _customStyle.openDuration + _afterOpenMotion);
      expectMenuClosed();
    });

    testWidgets('指定した暗転の濃さ・ボタン直径・扇の半径で表示される', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(hostApp(log: log, style: _customStyle));
      await tester.pumpAndSettle();

      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
        style: _customStyle,
      );

      expect(
        dimmingAlpha(tester),
        closeTo(_customStyle.dimmingOpacity, _alphaTolerance),
        reason: '暗転が指定した濃さになる',
      );
      for (var index = 0; index < menu.buttonCenters.length; index++) {
        expect(
          tester.getSize(find.bySemanticsLabel(actionLabel(index))),
          Size(_customStyle.buttonDiameter, _customStyle.buttonDiameter),
          reason: '${actionLabel(index)} のボタンが指定した直径になる',
        );
        expect(
          (menu.buttonCenters[index] - menu.pressPoint).distance,
          closeTo(_customStyle.arcRadius, _radiusTolerance),
          reason: '${actionLabel(index)} のボタン中心が押下点から指定した半径のところに出る',
        );
      }

      await menu.gesture.up();
      await pumpFrames(tester, _customStyle.openDuration + _afterOpenMotion);
    });

    testWidgets('指定したボタン背景色・アイコン色・強調の倍率で表示される (非強調 / 強調)', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(hostApp(log: log, style: _customStyle));
      await tester.pumpAndSettle();

      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
        style: _customStyle,
      );
      expectRenderedHighlight(tester, highlighted: null, style: _customStyle);

      await menu.gesture.moveTo(menu.buttonCenters[1]);
      await tester.pumpAndSettle();
      expectRenderedHighlight(tester, highlighted: 1, style: _customStyle);

      await menu.gesture.up();
      await pumpFrames(tester, _customStyle.openDuration + _afterOpenMotion);
    });
  });
}
