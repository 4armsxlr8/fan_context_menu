import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'fan_context_menu_action.dart';
import 'fan_context_menu_host.dart';

/// The widget the app using this package wraps around each pin. Shows
/// fan-shaped action buttons on long press.
///
/// This widget picks up the long-press gesture and reports its start,
/// movement, end, and cancellation as-is to the host's
/// ([FanContextMenuHost]) [FanContextMenuHostState]. The display (dimming,
/// lifted copy, action buttons) is all drawn by the host, so this widget
/// itself just draws [child] as-is.
///
/// Requires a host ancestor (reports via [FlutterError] in debug mode if
/// there isn't one).
class FanContextMenuTarget extends StatefulWidget {
  /// Throws [ArgumentError] if [actions] is invalid (the count is outside
  /// the 2-5 range, a semanticLabel is blank, or two semanticLabels in the
  /// same widget are duplicates).
  FanContextMenuTarget({
    super.key,
    required List<FanContextMenuAction> actions,
    required this.onAction,
    this.onOpened,
    this.onHighlightChanged,
    this.onClosed,
    this.liftedChildBuilder,
    required this.child,
  }) : actions = List.unmodifiable(_checkActions(actions));

  /// The list of actions listed in the long-press menu (already defensively
  /// copied).
  final List<FanContextMenuAction> actions;

  /// Called when the finger lifts while an action button is highlighted,
  /// executing that operation. Also called when execution goes through a
  /// custom accessibility action.
  final void Function(int index) onAction;

  /// Called when the long-press menu opens.
  final VoidCallback? onOpened;

  /// Called when the highlight changes (the index it landed on, or null once
  /// it leaves).
  final void Function(int? index)? onHighlightChanged;

  /// Called when the long-press menu closes without anything happening.
  final VoidCallback? onClosed;

  /// Changes how the lifted copy looks.
  ///
  /// If omitted, the same [child] widget instance is drawn a second time. A
  /// [child] with a [GlobalKey] or in-progress input state can't be
  /// duplicated as-is (a GlobalKey causes a "Duplicate GlobalKey" error), so
  /// in that case this builder must be used to replace how the copy looks.
  final Widget Function(BuildContext context, Widget child)? liftedChildBuilder;

  /// The widget this target wraps.
  final Widget child;

  @override
  State<FanContextMenuTarget> createState() => _FanContextMenuTargetState();
}

class _FanContextMenuTargetState extends State<FanContextMenuTarget> {
  /// The session for the currently in-progress long-press gesture.
  ///
  /// Null when [FanContextMenuHostState.requestOpen] rejected it because
  /// another long press was already open, or before it starts / after it
  /// ends (this pin's long press is doing nothing).
  Object? _session;

  /// The state of the nearest ancestor host. Obtained in
  /// [didChangeDependencies], the only way to reach the host.
  FanContextMenuHostState? _host;

  /// The recognizer that recognizes the long press. Recreated when
  /// [style.longPressDuration] or [MediaQuery.maybeGestureSettingsOf]
  /// changes.
  LongPressGestureRecognizer? _recognizer;

  /// The [style.longPressDuration] used when [_recognizer] was created.
  Duration? _recognizerLongPressDuration;

  /// The [MediaQuery.maybeGestureSettingsOf] used when [_recognizer] was
  /// created.
  DeviceGestureSettings? _recognizerGestureSettings;

  void _handleLongPressStart(LongPressStartDetails details) {
    final targetBox = context.findRenderObject()! as RenderBox;
    final session = _host?.requestOpen(
      details: details,
      targetBox: targetBox,
      target: widget,
    );
    // Record the session before calling onOpened. Even if onOpened throws,
    // the session is already recorded by this point, so the long-press menu
    // doesn't get stuck open (the exception isn't swallowed here; it
    // propagates to the caller, the gesture recognizer, as-is).
    _session = session;
    if (session != null) widget.onOpened?.call();
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final session = _session;
    if (session == null) return;
    _host?.updateFinger(session, details.globalPosition);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    final session = _session;
    _session = null;
    if (session == null) return;
    _host?.endGesture(session);
  }

  void _handleLongPressCancel() {
    final session = _session;
    _session = null;
    if (session == null) return;
    _host?.cancelGesture(session);
  }

  /// If there's an in-progress session, cancels it and reports that to the
  /// host, then drops [_session].
  ///
  /// Used when recreating the recognizer. [deactivate] cancels through the
  /// same procedure (deferring to the end of the frame, then calling
  /// [FanContextMenuHostState.cancelGesture]), but it differs in that it
  /// first waits until the end of the frame to check whether this widget
  /// comes back (reparented via a GlobalKey) before cancelling.
  void _dropGesture() {
    final session = _session;
    final host = _host;
    if (session == null || host == null) return;
    _session = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (host.mounted) host.cancelGesture(session);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _host = FanContextMenuHostState.maybeOf(context);
    final style = _host?.widget.style;
    if (style == null) return;

    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    if (_recognizer != null &&
        style.longPressDuration == _recognizerLongPressDuration &&
        gestureSettings == _recognizerGestureSettings) {
      return;
    }

    _dropGesture();
    _recognizer?.dispose();
    _recognizerLongPressDuration = style.longPressDuration;
    _recognizerGestureSettings = gestureSettings;
    _recognizer = LongPressGestureRecognizer(duration: style.longPressDuration)
      ..gestureSettings = gestureSettings
      ..onLongPressStart = _handleLongPressStart
      ..onLongPressMoveUpdate = _handleLongPressMoveUpdate
      ..onLongPressEnd = _handleLongPressEnd
      ..onLongPressCancel = _handleLongPressCancel;
  }

  @override
  void deactivate() {
    // If this widget is unmounted mid-gesture, the recognizer just resets
    // the already-recognized long press internally, and onLongPressEnd/
    // Cancel never arrives. Report the cancellation here so the host doesn't
    // get stuck open.
    //
    // deactivate is called during build, so calling cancelGesture
    // synchronously here (it calls setState internally) would crash with
    // "setState() or markNeedsBuild() called during build" if the host isn't
    // an ancestor of what's currently being built. Defer to the end of the
    // frame, and cancel only if this widget still hasn't come back by then
    // (i.e. it wasn't reparented via a GlobalKey). If it has come back, the
    // session simply continues.
    final session = _session;
    final host = _host;
    if (session != null && host != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted && host.mounted) {
          _session = null;
          host.cancelGesture(session);
        }
      });
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _recognizer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = _host;
    if (host == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('A target was placed outside of a host.'),
        ErrorDescription(
          'A target must be placed under a host, which defines the area '
          'where the dimming layer, lifted copy, and action buttons of the '
          'long-press menu are drawn.',
        ),
        ErrorHint(
          'Wrap the screen (or the area where the long-press menu is used) '
          'with a host.',
        ),
      ]);
    }
    return Semantics(
      container: true,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        for (var index = 0; index < widget.actions.length; index++)
          CustomSemanticsAction(
            label: widget.actions[index].semanticLabel,
          ): () =>
              widget.onAction(index),
      },
      child: Listener(
        onPointerDown: _recognizer!.addPointer,
        child: widget.child,
      ),
    );
  }
}

/// Validates [actions] and returns it as-is. Throws [ArgumentError] if the
/// count is outside the 2-5 range, a semanticLabel is blank, or a
/// semanticLabel is duplicated.
List<FanContextMenuAction> _checkActions(List<FanContextMenuAction> actions) {
  if (actions.length < 2 || actions.length > 5) {
    throw ArgumentError.value(
      actions.length,
      'actions.length',
      'must be between 2 and 5, inclusive',
    );
  }
  final seenLabels = <String>{};
  for (final action in actions) {
    if (action.semanticLabel.trim().isEmpty) {
      throw ArgumentError.value(
        action.semanticLabel,
        'actions[].semanticLabel',
        'must not be blank',
      );
    }
    if (!seenLabels.add(action.semanticLabel)) {
      throw ArgumentError.value(
        action.semanticLabel,
        'actions[].semanticLabel',
        'must not duplicate another spoken name',
      );
    }
  }
  return actions;
}
