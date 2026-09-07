import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'fan_context_menu_action.dart';
import 'fan_context_menu_style.dart';
import 'menu_geometry.dart';

/// The curve used for the position and scale changes while the long-press
/// menu opens/closes.
const _openMotionCurve = Curves.easeOut;

/// The curve used for the fade change while the long-press menu opens/closes.
const _openFadeCurve = Curves.ease;

/// One circular action button that makes up the long-press menu.
///
/// When [highlighted] is true, it is drawn with a
/// [FanContextMenuStyle.highlightedActionButtonColor] background, a
/// [FanContextMenuStyle.highlightedIconColor] icon, and scaled by
/// [FanContextMenuStyle.highlightScale]. When false, it uses a
/// [FanContextMenuStyle.actionButtonColor] background and a
/// [FanContextMenuStyle.iconColor] icon.
///
/// The outermost widget is `Semantics(label: action.semanticLabel)`, which
/// lets a screen reader find this button uniquely.
class ActionButtonView extends StatelessWidget {
  const ActionButtonView({
    super.key,
    required this.action,
    required this.highlighted,
    required this.style,
  });

  /// The operation this button represents.
  final FanContextMenuAction action;

  /// Whether a finger is on it, highlighting it.
  final bool highlighted;

  /// Look-and-feel and timing values.
  final FanContextMenuStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: action.semanticLabel,
      child: AnimatedScale(
        scale: highlighted ? style.highlightScale : 1.0,
        duration: style.highlightDuration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: style.highlightDuration,
          curve: Curves.easeOut,
          width: style.buttonDiameter,
          height: style.buttonDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted
                ? style.highlightedActionButtonColor
                : style.actionButtonColor,
          ),
          child: IconTheme(
            data: IconThemeData(
              color: highlighted ? style.highlightedIconColor : style.iconColor,
            ),
            child: action.icon,
          ),
        ),
      ),
    );
  }
}

/// The layer that darkens the host's whole area while the long-press menu is
/// shown.
///
/// While [absorbing] is true, it absorbs pointer input with [AbsorbPointer],
/// blocking scrolling and other taps within the host. During the close
/// animation, the caller passes false, letting an action right after the
/// finger lifts go through immediately. The opacity fades up to
/// [FanContextMenuStyle.dimmingOpacity] according to [openProgress] (0 is
/// closed, 1 is open).
class DimmingLayer extends StatelessWidget {
  const DimmingLayer({
    super.key,
    required this.openProgress,
    required this.absorbing,
    required this.style,
  });

  /// How far open/close has progressed (0 is closed, 1 is open).
  final double openProgress;

  /// Whether to absorb pointer input.
  final bool absorbing;

  /// Look-and-feel and timing values.
  final FanContextMenuStyle style;

  @override
  Widget build(BuildContext context) {
    final opacity =
        _openFadeCurve.transform(openProgress) * style.dimmingOpacity;
    return AbsorbPointer(
      absorbing: absorbing,
      child: Container(
        color: const Color(0xFF000000).withValues(alpha: opacity),
      ),
    );
  }
}

/// The frame for the lifted copy of the child that was long-pressed.
///
/// The caller places it at the same position and size as the original
/// target, e.g. with [Positioned.fromRect]. It lifts [child] by scaling and
/// tilting it around its center. According to [openProgress] (0 is closed, 1
/// is open), it moves from no scale/tilt up to
/// [FanContextMenuStyle.liftScale] / [FanContextMenuStyle.tiltDegrees].
class LiftedChildView extends StatelessWidget {
  const LiftedChildView({
    super.key,
    required this.child,
    required this.openProgress,
    required this.style,
  });

  /// The widget being lifted (child, or the result of liftedChildBuilder).
  final Widget child;

  /// How far open/close has progressed (0 is closed, 1 is open).
  final double openProgress;

  /// Look-and-feel and timing values.
  final FanContextMenuStyle style;

  @override
  Widget build(BuildContext context) {
    final motion = _openMotionCurve.transform(openProgress);
    final scale = lerpDouble(1.0, style.liftScale, motion)!;
    final tiltDegrees = style.tiltDegrees * motion;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(scale, scale, 1, 1)
        ..rotateZ(degreesToRadians(tiltDegrees)),
      // Placing this inside Transform makes the shadow scale and tilt along
      // with it. The shape of child is unknown, so a rectangular shadow is
      // drawn behind it.
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x8A000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// One action button that appears/retreats while moving between the press
/// point and its final position, according to how far open/close has
/// progressed. Scale and opacity move along the same progress.
class AnimatedActionButtonView extends StatelessWidget {
  const AnimatedActionButtonView({
    super.key,
    required this.action,
    required this.pressPoint,
    required this.targetCenter,
    required this.highlighted,
    required this.openProgress,
    required this.style,
  });

  final FanContextMenuAction action;
  final Offset pressPoint;
  final Offset targetCenter;
  final bool highlighted;
  final double openProgress;
  final FanContextMenuStyle style;

  @override
  Widget build(BuildContext context) {
    final motion = _openMotionCurve.transform(openProgress);
    final fade = _openFadeCurve.transform(openProgress);
    final center = Offset.lerp(pressPoint, targetCenter, motion)!;
    final scale = lerpDouble(style.actionButtonEnterScale, 1.0, motion)!;
    return Positioned(
      left: center.dx - style.buttonDiameter / 2,
      top: center.dy - style.buttonDiameter / 2,
      child: Opacity(
        opacity: fade,
        child: Transform.scale(
          scale: scale,
          child: ActionButtonView(
            action: action,
            highlighted: highlighted,
            style: style,
          ),
        ),
      ),
    );
  }
}
