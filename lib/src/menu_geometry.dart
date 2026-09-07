import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;

import 'fan_context_menu_style.dart';

/// The direction the long-press menu's fan opens toward.
enum FanDirection { left, right }

/// Determines the fan's direction from the press point and the host's size.
///
/// Left when the press point's x is at least half the host's width, right
/// otherwise.
FanDirection fanDirectionFor({
  required Offset pressPoint,
  required Size hostSize,
}) {
  return pressPoint.dx >= hostSize.width / 2
      ? FanDirection.left
      : FanDirection.right;
}

/// Computes the center coordinates of [actionCount] action buttons.
///
/// Places them evenly, in index order (along the arc starting from the top
/// end), on an arc centered on the press point, then translates the whole
/// set just enough to bring anything that overflows back in. The bounds
/// default to the whole host, but passing [padding] (the safe area) narrows
/// them to its interior.
/// When [style.sweepDegrees] is exactly 360, the two ends of the arc would
/// otherwise coincide, so the divisor for even spacing is [actionCount]
/// (excluding the endpoint), spacing the buttons evenly around the full
/// circle.
List<Offset> actionButtonCenters({
  required Offset pressPoint,
  required Size hostSize,
  required int actionCount,
  required FanContextMenuStyle style,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final direction = fanDirectionFor(pressPoint: pressPoint, hostSize: hostSize);
  final centerDegrees = direction == FanDirection.left
      ? 180 - style.arcLiftDegrees
      : style.arcLiftDegrees;
  final dir = direction == FanDirection.left ? 1 : -1;
  final divisor = style.sweepDegrees == 360 ? actionCount : actionCount - 1;

  final points = <Offset>[
    for (var i = 0; i < actionCount; i++)
      _pointOnArc(
        pressPoint: pressPoint,
        radius: style.arcRadius,
        degrees: centerDegrees + dir * (i / divisor - 0.5) * style.sweepDegrees,
      ),
  ];

  return _translateIntoScreen(
    points: points,
    bounds: padding.deflateRect(Offset.zero & hostSize),
    buttonDiameter: style.buttonDiameter,
  );
}

/// Returns the index of the action button nearest the finger position.
///
/// Assumes [centers] is ordered by index. If the distance to the nearest
/// button exceeds [threshold], no button is highlighted (null).
int? highlightedActionIndexAt({
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
  return nearestIndex;
}

/// Converts degrees to radians.
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

/// Translates the whole set of [points] just enough that the bounding
/// rectangle of all of them (padded by the button diameter) fits inside
/// [bounds].
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
