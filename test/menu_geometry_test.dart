import 'dart:math' as math;
import 'dart:ui';

import 'package:fan_context_menu/fan_context_menu.dart';
import 'package:fan_context_menu/src/menu_geometry.dart';
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';

/// 境界ちょうどへ平行移動した結果が丸め誤差で -1e-14 になっても
/// 「外にはみ出した」と判定しないための余裕。
const double _epsilon = 1e-9;

/// 既定値の Style。配置計算の収まりは既定値についてだけ保証する。
const FanContextMenuStyle _style = FanContextMenuStyle();

/// 広がり角だけを上限の 360 にした Style。他は既定値。
const FanContextMenuStyle _fullCircleStyle = FanContextMenuStyle(
  sweepDegrees: 360,
);

/// [bounds] からはみ出したアクションボタンがあればその説明を返す。
/// すべて内側に収まっていれば null。
String? _describeOutOfBounds(List<Offset> centers, Rect bounds) {
  final half = _style.buttonDiameter / 2;
  for (var i = 0; i < centers.length; i++) {
    final center = centers[i];
    final left = center.dx - half;
    final top = center.dy - half;
    final right = center.dx + half;
    final bottom = center.dy + half;
    if (left < bounds.left - _epsilon ||
        top < bounds.top - _epsilon ||
        right > bounds.right + _epsilon ||
        bottom > bounds.bottom + _epsilon) {
      return 'index $i の矩形 LTRB($left, $top, $right, $bottom) が '
          '$bounds からはみ出している';
    }
  }
  return null;
}

void main() {
  // 実機に近いホスト。押下点を中央付近に取ると平行移動が起きないので、
  // 扇の向きと形をそのまま観測できる。
  const hostSize = Size(390, 844);

  group('AC-17 押下点とホストの大きさで扇の向きが定まる', () {
    test('押下点が右半分なら扇は左向きに開く', () {
      expect(
        fanDirectionFor(pressPoint: const Offset(300, 400), hostSize: hostSize),
        FanDirection.left,
      );
    });

    test('押下点が左半分なら扇は右向きに開く', () {
      expect(
        fanDirectionFor(pressPoint: const Offset(100, 400), hostSize: hostSize),
        FanDirection.right,
      );
    });

    test('押下点がホスト幅のちょうど半分なら扇は左向きに開く', () {
      expect(
        fanDirectionFor(pressPoint: const Offset(195, 400), hostSize: hostSize),
        FanDirection.left,
      );
    });

    test('左向きのとき4つのアクションボタン中心の平均が押下点より左にある', () {
      const pressPoint = Offset(300, 400);
      final centers = actionButtonCenters(
        pressPoint: pressPoint,
        hostSize: hostSize,
        actionCount: 4,
        style: _style,
      );

      final meanDx =
          centers.map((c) => c.dx).reduce((a, b) => a + b) / centers.length;
      expect(meanDx, lessThan(pressPoint.dx));
    });

    test('右向きのとき4つのアクションボタン中心の平均が押下点より右にある', () {
      const pressPoint = Offset(100, 400);
      final centers = actionButtonCenters(
        pressPoint: pressPoint,
        hostSize: hostSize,
        actionCount: 4,
        style: _style,
      );

      final meanDx =
          centers.map((c) => c.dx).reduce((a, b) => a + b) / centers.length;
      expect(meanDx, greaterThan(pressPoint.dx));
    });
  });

  group('AC-17 ホストの四辺の近くで押下しても2〜5個がホスト内に収まる', () {
    const edgePressPoints = <Offset>[
      Offset(10, 10), // 左上の近く
      Offset(380, 10), // 右上の近く
      Offset(10, 834), // 左下の近く
      Offset(380, 834), // 右下の近く
      Offset(195, 5), // 上端の近く・幅のちょうど半分
      Offset(0, 0), // 左上ちょうど
      Offset(390, 844), // 右下ちょうど
    ];

    for (final pressPoint in edgePressPoints) {
      test('押下点 (${pressPoint.dx}, ${pressPoint.dy})', () {
        for (final count in const <int>[2, 3, 4, 5]) {
          final centers = actionButtonCenters(
            pressPoint: pressPoint,
            hostSize: hostSize,
            actionCount: count,
            style: _style,
          );

          expect(centers.length, count);
          final failure = _describeOutOfBounds(centers, Offset.zero & hostSize);
          expect(failure, isNull, reason: 'アクション $count 個: $failure');
        }
      });
    }
  });

  group('AC-17 幅320と430のどの押下点でも2〜5個がホスト内に収まる', () {
    const height = 700.0;

    for (final width in const <double>[320, 430]) {
      for (final count in const <int>[2, 3, 4, 5]) {
        test('幅 $width・アクション $count 個を10px刻みで全走査する', () {
          final size = Size(width, height);
          final bounds = Offset.zero & size;
          for (var x = 0.0; x <= width; x += 10) {
            for (var y = 0.0; y <= height; y += 10) {
              final centers = actionButtonCenters(
                pressPoint: Offset(x, y),
                hostSize: size,
                actionCount: count,
                style: _style,
              );
              final failure = _describeOutOfBounds(centers, bounds);
              expect(failure, isNull, reason: '押下点 ($x, $y): $failure');
            }
          }
        });
      }
    }
  });

  group('AC-9 指定数のアクションボタン中心が番号順で等間隔の弧に並ぶ', () {
    // はみ出しが無く平行移動が入らない押下点。弧の形をそのまま観測できる。
    const pressPoint = Offset(100, 400);

    for (final count in const <int>[2, 3, 4, 5]) {
      test('アクション $count 個の中心が押下点から半径ぶん離れ、隣接距離が等しい', () {
        final centers = actionButtonCenters(
          pressPoint: pressPoint,
          hostSize: hostSize,
          actionCount: count,
          style: _style,
        );

        expect(centers.length, count);
        for (var i = 0; i < centers.length; i++) {
          expect(
            (centers[i] - pressPoint).distance,
            closeTo(_style.arcRadius, 0.01),
            reason: 'index $i の押下点からの距離',
          );
        }

        final adjacent = (centers[1] - centers[0]).distance;
        for (var i = 1; i < centers.length - 1; i++) {
          expect(
            (centers[i + 1] - centers[i]).distance,
            closeTo(adjacent, 0.01),
            reason: 'index $i と ${i + 1} の距離',
          );
        }
      });
    }

    test('右向き・押下点(100,400)の4点が手計算した座標と一致する', () {
      final centers = actionButtonCenters(
        pressPoint: pressPoint,
        hostSize: hostSize,
        actionCount: 4,
        style: _style,
      );

      // 半径66・広がり180°・上へ40°。右向きの中心角は 40°、i=0 が +sweep/2 側。
      // 中心角は i=0 から順に 130°, 70°, 10°, -50°。
      // 各点は (100 + 66 cosθ, 400 - 66 sinθ)。この押下点でははみ出しが無く、
      // 平行移動は入らない。
      const expected = <Offset>[
        Offset(57.5760, 349.4411),
        Offset(122.5733, 337.9803),
        Offset(164.9973, 388.5392),
        Offset(142.4240, 450.5589),
      ];

      expect(centers.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(
          centers[i].dx,
          closeTo(expected[i].dx, 0.01),
          reason: 'index $i の dx',
        );
        expect(
          centers[i].dy,
          closeTo(expected[i].dy, 0.01),
          reason: 'index $i の dy',
        );
      }
    });

    test('隣り合う4つのアクションボタン中心の距離が等しい', () {
      final centers = actionButtonCenters(
        pressPoint: pressPoint,
        hostSize: hostSize,
        actionCount: 4,
        style: _style,
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

  group('AC-10 安全領域を渡すとその内側に収まる', () {
    test('安全領域 (padding) の内側にアクションボタンが収まる', () {
      const padding = EdgeInsets.fromLTRB(16, 60, 16, 34);
      final centers = actionButtonCenters(
        pressPoint: const Offset(5, 5),
        hostSize: hostSize,
        actionCount: 5,
        style: _style,
        padding: padding,
      );

      // 安全領域の内側 = ホスト 390x844 から左右16・上60・下34 を除いた矩形。
      const safeBounds = Rect.fromLTRB(16, 60, 374, 810);
      expect(centers.length, 5);
      expect(_describeOutOfBounds(centers, safeBounds), isNull);
    });
  });

  group('AC-22 広がり角が360ならアクションボタンが円周に等間隔で並ぶ', () {
    // 平行移動が起きない中央付近の押下点。円周の形をそのまま観測できる。
    const pressPoint = Offset(195, 400);

    for (final count in const <int>[2, 3, 4, 5]) {
      test('アクション $count 個が円周を $count 等分した位置に重ならず並ぶ', () {
        final centers = actionButtonCenters(
          pressPoint: pressPoint,
          hostSize: hostSize,
          actionCount: count,
          style: _fullCircleStyle,
        );

        expect(centers.length, count);

        // すべての中心が押下点から半径ぶん離れている。
        for (var i = 0; i < centers.length; i++) {
          expect(
            (centers[i] - pressPoint).distance,
            closeTo(_fullCircleStyle.arcRadius, 0.01),
            reason: 'index $i の押下点からの距離',
          );
        }

        // 隣接する中心の距離が、円周を count 等分した弦長と等しい。
        // 半径 r の円周を n 等分したときの弦長は 2 * r * sin(pi / n)。
        // 360 では弧の両端がつながるので、末尾と先頭も隣接とみなす。
        final expectedChord =
            2 * _fullCircleStyle.arcRadius * math.sin(math.pi / count);
        for (var i = 0; i < centers.length; i++) {
          final next = (i + 1) % centers.length;
          expect(
            (centers[next] - centers[i]).distance,
            closeTo(expectedChord, 0.01),
            reason: 'index $i と $next の距離',
          );
        }

        // どの2つの中心も同じ点に重ならない。
        for (var i = 0; i < centers.length; i++) {
          for (var j = i + 1; j < centers.length; j++) {
            expect(
              (centers[j] - centers[i]).distance,
              greaterThan(1.0),
              reason: 'index $i と $j が重なっている',
            );
          }
        }
      });
    }

    test('広がり角360でも四辺の近くの押下点で2〜5個がホスト内に収まる', () {
      const edgePressPoint = Offset(10, 10); // 左上の近く

      for (final count in const <int>[2, 3, 4, 5]) {
        final centers = actionButtonCenters(
          pressPoint: edgePressPoint,
          hostSize: hostSize,
          actionCount: count,
          style: _fullCircleStyle,
        );

        expect(centers.length, count);
        final failure = _describeOutOfBounds(centers, Offset.zero & hostSize);
        expect(failure, isNull, reason: 'アクション $count 個: $failure');
      }
    });
  });

  group('強調するアクションボタンの番号', () {
    const pressPoint = Offset(100, 400);

    test('指に最も近いアクションボタンの番号を返す', () {
      final centers = actionButtonCenters(
        pressPoint: pressPoint,
        hostSize: hostSize,
        actionCount: 4,
        style: _style,
      );

      // index 2 の中心 (164.9973, 388.5392) のすぐそば (約 5px)。
      // 隣り合う index 1・3 の中心からは 60px 以上離れている。
      expect(
        highlightedActionIndexAt(
          fingerPosition: const Offset(160, 390),
          centers: centers,
          threshold: _style.highlightThreshold,
        ),
        2,
      );
    });

    test('どのアクションボタンからもしきい値より遠ければ番号を返さない', () {
      final centers = actionButtonCenters(
        pressPoint: pressPoint,
        hostSize: hostSize,
        actionCount: 4,
        style: _style,
      );

      // 押下点にとどまっている指は、どの中心からも半径 66 だけ離れており、
      // しきい値 (48 * 1.35 / 2 + 6 = 38.4) を超えている。
      expect(
        highlightedActionIndexAt(
          fingerPosition: pressPoint,
          centers: centers,
          threshold: _style.highlightThreshold,
        ),
        isNull,
      );
    });
  });
}
