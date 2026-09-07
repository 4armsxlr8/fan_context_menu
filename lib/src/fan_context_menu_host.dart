import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'fan_context_menu_style.dart';
import 'fan_context_menu_target.dart';
import 'long_press_menu.dart';
import 'menu_geometry.dart';

/// The widget the app using this package wraps around the screen (or the
/// area where the long-press menu is used), defining the area where the
/// long-press menu's dimming layer, lifted copy, and action buttons are
/// drawn.
///
/// When a descendant target ([FanContextMenuTarget]) recognizes a long
/// press, this widget draws the dimming layer, lifted copy, and action
/// buttons on top of [child] in a [Stack]. The open/close state, press
/// point, highlight, and hysteresis are all held by this widget's [State].
class FanContextMenuHost extends StatefulWidget {
  /// Throws [ArgumentError] if [style] is invalid.
  FanContextMenuHost({
    super.key,
    this.style = const FanContextMenuStyle(),
    required this.child,
  }) {
    _checkStyle(style);
  }

  /// Look-and-feel and timing values.
  final FanContextMenuStyle style;

  /// The widget tree the host wraps.
  final Widget child;

  /// The [style] of the nearest ancestor host. Null if there isn't one.
  static FanContextMenuStyle? maybeStyleOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_FanContextMenuHostInherited>()
        ?.style;
  }

  @override
  State<FanContextMenuHost> createState() => FanContextMenuHostState();
}

/// The state of [FanContextMenuHost].
///
/// Also serves as the window that receives the long-press menu's open/close,
/// finger movement, execute, and cancel — called only from
/// [FanContextMenuTarget] (an implementation detail not exported from the
/// package's barrel file).
class FanContextMenuHostState extends State<FanContextMenuHost>
    with SingleTickerProviderStateMixin {
  /// Tracks how far the long-press menu's open/close has progressed (0 is
  /// closed, 1 is open).
  ///
  /// [_open] is kept during the close animation too, so it's cleared only
  /// after the animation completes (see [_closeMenu]).
  late final AnimationController _controller;

  /// The state of the open long-press menu. Null once fully closed.
  _OpenMenu? _open;

  /// The index of the action nearest the finger, currently highlighted.
  int? _highlightedIndex;

  /// The state of the nearest ancestor host. The only way for a target to
  /// reach the host, used in [didChangeDependencies]. Null if there isn't
  /// one.
  static FanContextMenuHostState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_FanContextMenuHostInherited>()
        ?.state;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// This host's [RenderBox].
  RenderBox get _hostBox => context.findRenderObject()! as RenderBox;

  /// Returns, as padding in the host's coordinate system, only the part of
  /// the screen's safe area that overlaps this host's rectangle.
  ///
  /// [MediaQuery.paddingOf] is relative to the screen, so if the host
  /// doesn't touch the screen's edges, using it directly would deduct too
  /// much. This finds the intersection of the host's on-screen rectangle and
  /// the screen's safe area, falling back to the host's rectangle itself
  /// when there is no intersection.
  EdgeInsets _effectivePaddingFor(RenderBox hostBox) {
    final screenPadding = MediaQuery.paddingOf(context);
    final safeArea = screenPadding.deflateRect(
      Offset.zero & MediaQuery.sizeOf(context),
    );
    final host = hostBox.localToGlobal(Offset.zero) & hostBox.size;

    var bounds = safeArea.intersect(host);
    if (bounds.isEmpty) bounds = host;
    bounds = bounds.shift(-host.topLeft);

    return EdgeInsets.fromLTRB(
      bounds.left,
      bounds.top,
      hostBox.size.width - bounds.right,
      hostBox.size.height - bounds.bottom,
    );
  }

  /// Called when [FanContextMenuTarget] recognizes a long press.
  ///
  /// If the long-press menu is already open (including during the close
  /// animation), does nothing and returns null (ignoring another finger's
  /// long press). Once opened, returns the session (the opened [_OpenMenu]
  /// itself) used to associate subsequent calls to [updateFinger] /
  /// [endGesture] / [cancelGesture].
  ///
  /// The caller ([FanContextMenuTarget]) records the session before calling
  /// onOpened (this function itself doesn't call onOpened; see
  /// [FanContextMenuTarget]'s implementation for why).
  Object? requestOpen({
    required LongPressStartDetails details,
    required RenderBox targetBox,
    required FanContextMenuTarget target,
  }) {
    if (_open != null) return null;

    final hostBox = _hostBox;
    final rect =
        targetBox.localToGlobal(Offset.zero, ancestor: hostBox) &
        targetBox.size;
    final pressPoint = hostBox.globalToLocal(details.globalPosition);
    // Don't use highlightThreshold directly as the arm distance. With a
    // style where arcRadius is smaller than highlightThreshold, moving
    // straight toward a button would never reach highlightThreshold and
    // could never arm, so base the arm distance on the arc's radius instead,
    // letting it arm earlier (with the defaults, this still equals
    // highlightThreshold).
    final armDistance = math.min(
      widget.style.highlightThreshold,
      math.max(0.0, widget.style.arcRadius - widget.style.buttonDiameter / 2),
    );
    final open = _OpenMenu(
      rect: rect,
      pressPoint: pressPoint,
      buttonCenters: actionButtonCenters(
        pressPoint: pressPoint,
        hostSize: hostBox.size,
        actionCount: target.actions.length,
        style: widget.style,
        padding: _effectivePaddingFor(hostBox),
      ),
      armDistance: armDistance,
      highlightArmed: false,
      target: target,
    );

    setState(() {
      _highlightedIndex = null;
      _open = open;
    });
    _controller.duration = widget.style.openDuration;
    _controller.forward(from: 0);
    return open;
  }

  /// The state of the open long-press menu that [session] corresponds to.
  /// Null if it doesn't correspond to any.
  _OpenMenu? _openFor(Object session) =>
      identical(_open, session) ? _open : null;

  /// Called when the finger's position moves. Notifies only when the
  /// highlight changes.
  void updateFinger(Object session, Offset globalPosition) {
    final open = _openFor(session);
    if (open == null) return;

    final fingerPosition = _hostBox.globalToLocal(globalPosition);
    if (!open.highlightArmed &&
        (fingerPosition - open.pressPoint).distance > open.armDistance) {
      open.highlightArmed = true;
    }
    final highlightedIndex = open.highlightArmed
        ? highlightedActionIndexAt(
            fingerPosition: fingerPosition,
            centers: open.buttonCenters,
            threshold: widget.style.highlightThreshold,
          )
        : null;
    if (highlightedIndex != _highlightedIndex) {
      setState(() => _highlightedIndex = highlightedIndex);
      open.target.onHighlightChanged?.call(highlightedIndex);
    }
  }

  /// Called when the finger lifts. Executes the highlighted action if one is
  /// highlighted; otherwise notifies that it closed without anything
  /// happening.
  void endGesture(Object session) {
    final open = _openFor(session);
    if (open == null) return;

    final highlightedIndex = _highlightedIndex;
    _closeMenu();
    if (highlightedIndex != null) {
      open.target.onAction(highlightedIndex);
    } else {
      open.target.onClosed?.call();
    }
  }

  /// Called when the gesture is cancelled. Notifies that it closed without
  /// anything happening.
  void cancelGesture(Object session) {
    final open = _openFor(session);
    if (open == null) return;

    _closeMenu();
    open.target.onClosed?.call();
  }

  /// Starts the close animation, then clears the display state once it
  /// finishes.
  ///
  /// The highlight is cleared here as well.
  void _closeMenu() {
    setState(() => _highlightedIndex = null);
    _controller.duration = widget.style.openDuration;
    _controller.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() => _open = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    // Call liftedChildBuilder once per open/close (not on every animation
    // frame). A Builder is inserted so the context passed to it is a
    // descendant of [_FanContextMenuHostInherited] (this method's own
    // context is an ancestor of the InheritedWidget it's about to create).
    final liftedChild = open == null
        ? null
        : (open.target.liftedChildBuilder == null
              ? open.target.child
              : Builder(
                  builder: (context) => open.target.liftedChildBuilder!(
                    context,
                    open.target.child,
                  ),
                ));

    return _FanContextMenuHostInherited(
      state: this,
      style: widget.style,
      child: Stack(
        // Don't force the host's constraints onto the app's child (pass the
        // parent's constraints through to child as-is, and let the Stack
        // itself size to child's size).
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => _buildMenu(open, child),
              child: liftedChild,
            ),
          ),
        ],
      ),
    );
  }

  /// If open, returns a [Stack] layering the dimming layer, lifted copy, and
  /// action buttons; if closed, returns a widget that draws nothing.
  /// [liftedChild] is the content of the lifted copy that [build] created
  /// once.
  Widget _buildMenu(_OpenMenu? open, Widget? liftedChild) {
    if (open == null) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned.fill(
          child: DimmingLayer(
            openProgress: _controller.value,
            // Don't absorb pointer input during the close animation, letting
            // an action right after the finger lifts go through immediately.
            absorbing: _controller.status != AnimationStatus.reverse,
            style: widget.style,
          ),
        ),
        Positioned.fromRect(
          rect: open.rect,
          child: LiftedChildView(
            openProgress: _controller.value,
            style: widget.style,
            child: liftedChild!,
          ),
        ),
        for (var index = 0; index < open.target.actions.length; index++)
          AnimatedActionButtonView(
            action: open.target.actions[index],
            pressPoint: open.pressPoint,
            targetCenter: open.buttonCenters[index],
            highlighted: _highlightedIndex == index,
            openProgress: _controller.value,
            style: widget.style,
          ),
      ],
    );
  }
}

/// The state of one open long-press menu.
class _OpenMenu {
  _OpenMenu({
    required this.rect,
    required this.pressPoint,
    required this.buttonCenters,
    required this.armDistance,
    required this.highlightArmed,
    required this.target,
  });

  /// The original target's position and size (in the host's coordinate
  /// system), measured when the long press started.
  final Rect rect;

  /// The press point where the long press was recognized (in the host's
  /// coordinate system).
  final Offset pressPoint;

  /// The action button centers (in the host's coordinate system), computed
  /// once when opened.
  final List<Offset> buttonCenters;

  /// The arm distance for highlight hysteresis (the highlight stays disabled
  /// until the finger moves farther than this distance from the press point
  /// at least once).
  final double armDistance;

  /// Whether highlight hysteresis is armed.
  ///
  /// Once armed, it stays armed until this menu closes.
  bool highlightArmed;

  /// The target that opened this menu (the action list, child, and
  /// callbacks are all read from here).
  final FanContextMenuTarget target;
}

/// Validates each value of [style], throwing [ArgumentError] if any is
/// invalid.
void _checkStyle(FanContextMenuStyle style) {
  _checkPositiveDuration(style.longPressDuration, 'style.longPressDuration');
  _checkPositiveDuration(style.openDuration, 'style.openDuration');
  _checkPositiveDuration(style.highlightDuration, 'style.highlightDuration');
  if (!(style.dimmingOpacity >= 0 && style.dimmingOpacity <= 1)) {
    throw ArgumentError.value(
      style.dimmingOpacity,
      'style.dimmingOpacity',
      'must be between 0 and 1, inclusive',
    );
  }
  _checkPositiveFinite(style.buttonDiameter, 'style.buttonDiameter');
  _checkPositiveFinite(style.arcRadius, 'style.arcRadius');
  _checkPositiveFinite(style.liftScale, 'style.liftScale');
  _checkPositiveFinite(style.highlightScale, 'style.highlightScale');
  _checkPositiveFinite(
    style.actionButtonEnterScale,
    'style.actionButtonEnterScale',
  );
  if (!(style.sweepDegrees > 0 && style.sweepDegrees <= 360)) {
    throw ArgumentError.value(
      style.sweepDegrees,
      'style.sweepDegrees',
      'must be greater than 0 and at most 360',
    );
  }
  _checkFiniteAngle(style.tiltDegrees, 'style.tiltDegrees');
  _checkFiniteAngle(style.arcLiftDegrees, 'style.arcLiftDegrees');
}

/// Throws [ArgumentError] unless [value] is a positive duration.
void _checkPositiveDuration(Duration value, String name) {
  if (value <= Duration.zero) {
    throw ArgumentError.value(value, name, 'must be a positive duration');
  }
}

/// Throws [ArgumentError] unless [value] is a positive finite value.
void _checkPositiveFinite(double value, String name) {
  if (!(value > 0) || !value.isFinite) {
    throw ArgumentError.value(value, name, 'must be a positive finite value');
  }
}

/// Throws [ArgumentError] unless [value] is finite (negative angles are
/// allowed).
void _checkFiniteAngle(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'must be a finite angle');
  }
}

class _FanContextMenuHostInherited extends InheritedWidget {
  const _FanContextMenuHostInherited({
    required this.state,
    required this.style,
    required super.child,
  });

  /// This host's state (the same shape as Flutter's `_FormScope` carrying a
  /// [FormState]).
  final FanContextMenuHostState state;

  /// This host's [style]. Used for the comparison in [updateShouldNotify]
  /// ([state] can't be used for that, since it always points to the same
  /// instance).
  final FanContextMenuStyle style;

  @override
  bool updateShouldNotify(_FanContextMenuHostInherited oldWidget) =>
      oldWidget.style != style;
}
