import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;

import 'long_press_menu_metrics.dart';
import 'pin.dart';

/// 長押しメニューの扇が開く向き。
enum FanDirection { left, right }

/// 押下点と画面サイズから扇の向きを決める。
///
/// 押下点の x が画面幅の半分以上なら左向き、未満なら右向き。
FanDirection fanDirectionFor({
  required Offset pressPoint,
  required Size screenSize,
}) {
  return pressPoint.dx >= screenSize.width / 2
      ? FanDirection.left
      : FanDirection.right;
}

/// 4つのアクションボタンの中心座標を計算する。
///
/// 押下点を中心とした円弧上に、[PinAction.values] の順 (弧に沿って上端側から
/// 非表示・リアクション・共有・保存) で等間隔に並べ、はみ出す分だけ全体を平行移動して
/// 収める。収め先は既定で画面全体だが、[padding] (安全領域) を渡すとその内側に狭まる。
List<Offset> actionButtonCenters({
  required Offset pressPoint,
  required Size screenSize,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final direction = fanDirectionFor(
    pressPoint: pressPoint,
    screenSize: screenSize,
  );
  final centerDegrees = direction == FanDirection.left
      ? 180 - LongPressMenuMetrics.arcLiftDegrees
      : LongPressMenuMetrics.arcLiftDegrees;
  final dir = direction == FanDirection.left ? 1 : -1;

  final actionCount = PinAction.values.length;
  final points = <Offset>[
    for (var i = 0; i < actionCount; i++)
      _pointOnArc(
        pressPoint: pressPoint,
        radius: LongPressMenuMetrics.arcRadius,
        degrees:
            centerDegrees +
            dir *
                (i / (actionCount - 1) - 0.5) *
                LongPressMenuMetrics.sweepDegrees,
      ),
  ];

  return _translateIntoScreen(
    points: points,
    bounds: padding.deflateRect(Offset.zero & screenSize),
    buttonDiameter: LongPressMenuMetrics.buttonDiameter,
  );
}

/// 指の位置に最も近いアクションボタンを返す。
///
/// [centers] は [PinAction.values] の順に並んでいるとみなす。最も近いボタンとの
/// 距離が [threshold] を超えていれば強調するボタンは無い (null)。
PinAction? highlightedActionAt({
  required Offset fingerPosition,
  required List<Offset> centers,
  required double threshold,
}) {
  var nearestIndex = -1;
  var nearestDistance = double.infinity;
  for (var i = 0; i < centers.length; i++) {
    final distance = (centers[i] - fingerPosition).distance;
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = i;
    }
  }
  if (nearestIndex == -1 || nearestDistance > threshold) {
    return null;
  }
  return PinAction.values[nearestIndex];
}

/// 度をラジアンに変換する。
double degreesToRadians(double degrees) => degrees * math.pi / 180;

Offset _pointOnArc({
  required Offset pressPoint,
  required double radius,
  required double degrees,
}) {
  final radians = degreesToRadians(degrees);
  return Offset(
    pressPoint.dx + radius * math.cos(radians),
    pressPoint.dy - radius * math.sin(radians),
  );
}

/// [points] の全外接矩形 (ボタン直径ぶんの余白込み) が [bounds] からはみ出す分だけ
/// 全体を平行移動する。
List<Offset> _translateIntoScreen({
  required List<Offset> points,
  required Rect bounds,
  required double buttonDiameter,
}) {
  final radius = buttonDiameter / 2;
  var outline = Rect.fromCircle(center: points.first, radius: radius);
  for (final point in points.skip(1)) {
    outline = outline.expandToInclude(
      Rect.fromCircle(center: point, radius: radius),
    );
  }

  var dx = 0.0;
  if (outline.left < bounds.left) dx = bounds.left - outline.left;
  if (outline.right + dx > bounds.right) {
    dx -= (outline.right + dx) - bounds.right;
  }

  var dy = 0.0;
  if (outline.top < bounds.top) dy = bounds.top - outline.top;
  if (outline.bottom + dy > bounds.bottom) {
    dy -= (outline.bottom + dy) - bounds.bottom;
  }

  return [for (final point in points) point.translate(dx, dy)];
}
