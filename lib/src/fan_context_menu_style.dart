import 'dart:ui';

/// Look-and-feel and timing values for the long-press menu.
///
/// The defaults are the values from the original sample. Not validated here
/// (validated when the host is built).
class FanContextMenuStyle {
  const FanContextMenuStyle({
    this.longPressDuration = const Duration(milliseconds: 500),
    this.openDuration = const Duration(milliseconds: 180),
    this.highlightDuration = const Duration(milliseconds: 120),
    this.dimmingOpacity = 0.6,
    this.liftScale = 1.08,
    this.tiltDegrees = -3.0,
    this.buttonDiameter = 48.0,
    this.highlightScale = 1.35,
    this.actionButtonEnterScale = 0.6,
    this.arcRadius = 66.0,
    this.sweepDegrees = 180.0,
    this.arcLiftDegrees = 40.0,
    this.actionButtonColor = const Color(0xFF3C3C3C),
    this.highlightedActionButtonColor = const Color(0xFFFFFFFF),
    this.iconColor = const Color(0xFFFFFFFF),
    this.highlightedIconColor = const Color(0xFF000000),
  });

  /// How long a long press takes to be recognized. Must be a positive
  /// duration.
  final Duration longPressDuration;

  /// How long the animation that opens/closes the long-press menu takes.
  /// Must be a positive duration.
  final Duration openDuration;

  /// How long the animation that switches an action button's highlight
  /// takes. Must be a positive duration.
  final Duration highlightDuration;

  /// The opacity of the dimming layer (between 0 and 1, inclusive).
  final double dimmingOpacity;

  /// The scale factor of the lifted copy. Must be a positive finite value.
  final double liftScale;

  /// The tilt of the lifted copy, in degrees. Must be finite (negative is
  /// allowed).
  final double tiltDegrees;

  /// The diameter of an action button. Must be a positive finite value.
  final double buttonDiameter;

  /// The scale factor of a highlighted action button. Must be a positive
  /// finite value.
  final double highlightScale;

  /// The initial scale factor of an action button as it appears from the
  /// press point. Must be a positive finite value.
  final double actionButtonEnterScale;

  /// The radius of the long-press menu's arc. Must be a positive finite
  /// value.
  final double arcRadius;

  /// The sweep angle of the long-press menu's arc, in degrees. Must be
  /// greater than 0 and at most 360.
  final double sweepDegrees;

  /// The angle that tilts the arc's center upward from horizontal, in
  /// degrees. Must be finite (negative is allowed).
  final double arcLiftDegrees;

  /// The color of a non-highlighted action button.
  final Color actionButtonColor;

  /// The color of a highlighted action button.
  final Color highlightedActionButtonColor;

  /// The color of a non-highlighted icon.
  final Color iconColor;

  /// The color of a highlighted icon.
  final Color highlightedIconColor;

  /// The hit-test threshold for highlighting (the distance between the
  /// finger and the nearest action button's center).
  ///
  /// A derived value, not something the app using this package sets:
  /// buttonDiameter * highlightScale / 2 + 6.
  double get highlightThreshold => buttonDiameter * highlightScale / 2 + 6;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FanContextMenuStyle &&
        other.runtimeType == runtimeType &&
        other.longPressDuration == longPressDuration &&
        other.openDuration == openDuration &&
        other.highlightDuration == highlightDuration &&
        other.dimmingOpacity == dimmingOpacity &&
        other.liftScale == liftScale &&
        other.tiltDegrees == tiltDegrees &&
        other.buttonDiameter == buttonDiameter &&
        other.highlightScale == highlightScale &&
        other.actionButtonEnterScale == actionButtonEnterScale &&
        other.arcRadius == arcRadius &&
        other.sweepDegrees == sweepDegrees &&
        other.arcLiftDegrees == arcLiftDegrees &&
        other.actionButtonColor == actionButtonColor &&
        other.highlightedActionButtonColor == highlightedActionButtonColor &&
        other.iconColor == iconColor &&
        other.highlightedIconColor == highlightedIconColor;
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    longPressDuration,
    openDuration,
    highlightDuration,
    dimmingOpacity,
    liftScale,
    tiltDegrees,
    buttonDiameter,
    highlightScale,
    actionButtonEnterScale,
    arcRadius,
    sweepDegrees,
    arcLiftDegrees,
    actionButtonColor,
    highlightedActionButtonColor,
    iconColor,
    highlightedIconColor,
  );
}
