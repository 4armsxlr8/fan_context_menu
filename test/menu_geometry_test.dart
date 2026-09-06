import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinterest_long_press_menu/src/long_press_menu_metrics.dart';
import 'package:pinterest_long_press_menu/src/menu_geometry.dart';
import 'package:pinterest_long_press_menu/src/pin.dart';

/// 画面端ちょうどへ平行移動した結果が丸め誤差で -1e-14 になっても
/// 「画面外」と判定しないための余裕。
const double _epsilon = 1e-9;

/// 画面外にはみ出したアクションボタンがあればその説明を返す。すべて画面内なら null。
String? describeOutOfScreen(List<Offset> centers, Size screenSize) {
  final half = LongPressMenuMetrics.buttonDiameter / 2;
  for (var i = 0; i < centers.length; i++) {
    final center = centers[i];
    final left = center.dx - half;
    final top = center.dy - half;
    final right = center.dx + half;
    final bottom = center.dy + half;
    if (left < -_epsilon ||
        top < -_epsilon ||
        right > screenSize.width + _epsilon ||
        bottom > screenSize.height + _epsilon) {
      return 'index $i の矩形 LTRB($left, $top, $right, $bottom) が '
          '画面 ${screenSize.width}x${screenSize.height} からはみ出している';
    }
  }
  return null;
}

void main() {
  // 実機に近い画面。押下点を中央付近に取ると平行移動が起きないので、
  // 扇の向きと形をそのまま観測できる。
  const screenSize = Size(390, 844);

  group('AC-8 押下点の左右で扇の向きが決まる', () {
    test('押下点が右半分なら扇は左向きに開く', () {
      expect(
        fanDirectionFor(
          pressPoint: const Offset(300, 400),
          screenSize: screenSize,
        ),
        FanDirection.left,
      );
    });

    test('押下点が左半分なら扇は右向きに開く', () {
      expect(
        fanDirectionFor(
          pressPoint: const Offset(100, 400),
          screenSize: screenSize,
        ),
        FanDirection.right,
      );
    });

    test('押下点が幅のちょうど半分なら扇は左向きに開く', () {
      expect(
        fanDirectionFor(
          pressPoint: const Offset(195, 400),
          screenSize: screenSize,
        ),
        FanDirection.left,
      );
    });

    test('左向きのとき4つのアクションボタン中心の平均が押下点より左にある', () {
      const pressPoint = Offset(300, 400);
      final centers = actionButtonCenters(
        pressPoint: pressPoint,
        screenSize: screenSize,
      );

      final meanDx =
          centers.map((c) => c.dx).reduce((a, b) => a + b) / centers.length;
      expect(meanDx, lessThan(pressPoint.dx));
    });

    test('右向きのとき4つのアクションボタン中心の平均が押下点より右にある', () {
      const pressPoint = Offset(100, 400);
      final centers = actionButtonCenters(
        pressPoint: pressPoint,
        screenSize: screenSize,
      );

      final meanDx =
          centers.map((c) => c.dx).reduce((a, b) => a + b) / centers.length;
      expect(meanDx, greaterThan(pressPoint.dx));
    });

    test('右向き・押下点(100,400)の4点が手計算した座標と一致する', () {
      final centers = actionButtonCenters(
        pressPoint: const Offset(100, 400),
        screenSize: screenSize,
      );

      // 半径66・広がり180°・上へ40°。右向きの中心角は 40°、i=0 が +sweep/2 側。
      // 中心角は i=0 から順に 130°, 70°, 10°, -50°。
      // 各点は (100 + 66 cosθ, 400 - 66 sinθ)。この押下点でははみ出しが無く、
      // 平行移動は入らない。
      const expected = <Offset>[
        Offset(57.5760, 349.4411), // 非表示
        Offset(122.5733, 337.9803), // リアクション
        Offset(164.9973, 388.5392), // 共有
        Offset(142.4240, 450.5589), // 保存
      ];

      expect(centers.length, PinAction.values.length);
      for (var i = 0; i < expected.length; i++) {
        expect(
          centers[i].dx,
          closeTo(expected[i].dx, 0.01),
          reason: '${PinAction.values[i].name} (index $i) の dx',
        );
        expect(
          centers[i].dy,
          closeTo(expected[i].dy, 0.01),
          reason: '${PinAction.values[i].name} (index $i) の dy',
        );
      }
    });

    test('隣り合うアクションボタン中心の距離が等しい', () {
      final centers = actionButtonCenters(
        pressPoint: const Offset(100, 400),
        screenSize: screenSize,
      );

      // 広がり180°を4点に等分すると隣接の中心角は60°。
      // 半径66の弦長は 2 * 66 * sin(30°) = 66。
      for (var i = 0; i < centers.length - 1; i++) {
        expect(
          (centers[i + 1] - centers[i]).distance,
          closeTo(66.0, 0.01),
          reason: 'index $i と ${i + 1} の距離',
        );
      }
    });
  });

  group('AC-9 画面の端の近くで押下しても4ボタンが画面内に収まる', () {
    const pressPoints = <Offset>[
      Offset(10, 10), // 左上の近く
      Offset(380, 10), // 右上の近く
      Offset(10, 834), // 左下の近く
      Offset(380, 834), // 右下の近く
      Offset(195, 5), // 上端の近く・幅のちょうど半分
      Offset(0, 0), // 左上ちょうど
      Offset(390, 844), // 右下ちょうど
    ];

    for (final pressPoint in pressPoints) {
      test('押下点 (${pressPoint.dx}, ${pressPoint.dy})', () {
        final centers = actionButtonCenters(
          pressPoint: pressPoint,
          screenSize: screenSize,
        );

        expect(centers.length, PinAction.values.length);
        expect(describeOutOfScreen(centers, screenSize), isNull);
      });
    }
  });

  group('AC-10 幅320と430のどの押下点でも4ボタンが画面内に収まる', () {
    const height = 700.0;

    for (final width in <double>[320, 430]) {
      test('幅 $width を10px刻みで全走査する', () {
        final size = Size(width, height);
        for (var x = 0.0; x <= width; x += 10) {
          for (var y = 0.0; y <= height; y += 10) {
            final centers = actionButtonCenters(
              pressPoint: Offset(x, y),
              screenSize: size,
            );
            final failure = describeOutOfScreen(centers, size);
            expect(failure, isNull, reason: '押下点 ($x, $y): $failure');
          }
        }
      });
    }
  });
}
