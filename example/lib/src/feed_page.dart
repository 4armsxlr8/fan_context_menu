import 'dart:math' as math;

import 'package:fan_context_menu/fan_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keys.dart';
import 'pin.dart';

/// How long an execution result message is shown.
const Duration _messageDuration = Duration(milliseconds: 1750);

/// The side length of one bottom-nav square.
const double _navSquareSize = 52;

/// The spacing between bottom-nav squares.
const double _navSpacing = 8;

/// The home screen.
///
/// Shows a header, tab row, and two columns of pins in a vertical scroll,
/// with a visual-only bottom nav layered on top. Showing, highlighting, and
/// executing the long-press menu is left to package:fan_context_menu's
/// [FanContextMenuHost] / [FanContextMenuTarget]; this screen only wraps the
/// whole thing with a host and wraps each pin with a target.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key, required this.pins});

  /// The list of pins shown in the feed.
  final List<Pin> pins;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  /// The message for the operation last executed. Null when nothing is
  /// shown.
  String? _executeMessage;

  /// A counter incremented on every execution. Used as a key that forces
  /// [ExecuteMessageView] to be recreated (and its display time to start
  /// over) even when the message text repeats.
  int _messageToken = 0;

  /// The widget that draws the list of pins. Recreated only when
  /// [widget.pins] changes, not on the setState calls that show/hide the
  /// message (avoiding rebuilding every pin).
  late Widget _pinsView;

  @override
  void initState() {
    super.initState();
    _pinsView = _buildPinsView(widget.pins);
  }

  @override
  void didUpdateWidget(FeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pins != widget.pins) {
      _pinsView = _buildPinsView(widget.pins);
    }
  }

  Widget _buildPinsView(List<Pin> pins) {
    return pins.isEmpty
        ? const _EmptyFeed()
        : _PinGrid(pins: pins, onAction: _showExecuteMessage);
  }

  /// Shows a message reporting that something was executed.
  void _showExecuteMessage(Pin pin, PinAction action) {
    setState(() {
      _messageToken++;
      _executeMessage = '『${pin.title}』を${action.label}';
    });
  }

  /// Clears the message only when [token] matches the one the message was
  /// issued with.
  ///
  /// Guards against clearing the next message as collateral damage when the
  /// next execution lands just before the previous message would have
  /// disappeared on its own ([ExecuteMessageView] is recreated keyed on
  /// [_messageToken], but the dismissal notification itself arrives
  /// asynchronously).
  void _dismissMessage(int token) {
    if (token != _messageToken) return;
    setState(() => _executeMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final navBottomOffset = math.max(
      32.0,
      MediaQuery.paddingOf(context).bottom,
    );
    // Clearance so the tail of the feed isn't hidden behind the nav.
    final trailingClearance = navBottomOffset + _navSquareSize + 16;
    // Fix the token this frame's ExecuteMessageView will use for its
    // dismissal notification.
    final messageToken = _messageToken;

    return Scaffold(
      body: FanContextMenuHost(
        child: Stack(
          children: [
            SingleChildScrollView(
              key: SampleKeys.feed,
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  const SizedBox(height: 8),
                  const _TabsRow(),
                  const SizedBox(height: 12),
                  _pinsView,
                  SizedBox(height: trailingClearance),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: navBottomOffset,
              child: Center(
                key: SampleKeys.bottomNav,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NavSquare(),
                    SizedBox(width: _navSpacing),
                    _NavSquare(),
                    SizedBox(width: _navSpacing),
                    _NavSquare(),
                  ],
                ),
              ),
            ),
            if (_executeMessage != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: trailingClearance,
                child: Center(
                  child: ExecuteMessageView(
                    key: ValueKey(messageToken),
                    message: _executeMessage!,
                    onDismissed: () => _dismissMessage(messageToken),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The header showing the "Fan Context Menu" text alongside two icons: a
/// plus and a speech bubble.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Fan Context Menu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Row(
            children: [
              Icon(Icons.add, color: Colors.white),
              SizedBox(width: 20),
              Icon(Icons.chat_bubble_outline, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

/// A visual-only tab row.
class _TabsRow extends StatelessWidget {
  const _TabsRow();

  static const _labels = <String>['すべて', '怪異', 'マインクラフトの建物', 'チュートリアル'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Text(
                _labels[i],
                style: TextStyle(
                  color: i == 0 ? Colors.white : Colors.white54,
                  fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The empty display shown centered when there are no pins.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: const Center(
        child: Text('アイデアはまだありません', style: TextStyle(color: Colors.white70)),
      ),
    );
  }
}

/// Distributes pins into two columns. Even indices go to the left column,
/// odd indices to the right.
class _PinGrid extends StatelessWidget {
  const _PinGrid({required this.pins, required this.onAction});

  final List<Pin> pins;

  /// Called when a pin's operation is executed.
  final void Function(Pin pin, PinAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < pins.length; i++) {
      final view = _PinView(index: i, pin: pins[i], onAction: onAction);
      (i.isEven ? left : right).add(view);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: left)),
          const SizedBox(width: 8),
          Expanded(child: Column(children: right)),
        ],
      ),
    );
  }
}

/// One pin: a solid-color rounded box with its title below.
///
/// Wraps the colored box with a target ([FanContextMenuTarget]) and leaves
/// showing, highlighting, and executing the long-press menu to
/// package:fan_context_menu. This screen is responsible for playing haptics
/// on the open and highlight-changed notifications (the package itself
/// never calls [HapticFeedback]).
///
/// Wraps the title's [Semantics] and the target with [MergeSemantics],
/// merging the title and the four operations' custom actions into a single
/// semantics node.
class _PinView extends StatelessWidget {
  const _PinView({
    required this.index,
    required this.pin,
    required this.onAction,
  });

  final int index;
  final Pin pin;
  final void Function(Pin pin, PinAction action) onAction;

  /// The list of actions listed in the long-press menu. Shared by every
  /// pin, so it's built only once.
  static final List<FanContextMenuAction> _actions = [
    for (final action in PinAction.values)
      FanContextMenuAction(
        icon: Icon(action.icon),
        semanticLabel: action.semanticsLabel,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FanContextMenuTarget(
              actions: _actions,
              onAction: (i) => onAction(pin, PinAction.values[i]),
              onOpened: HapticFeedback.mediumImpact,
              onHighlightChanged: (i) {
                if (i != null) HapticFeedback.selectionClick();
              },
              child: Container(
                key: SampleKeys.pin(index),
                height: pin.height,
                decoration: BoxDecoration(
                  color: pin.color,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Semantics(
              label: pin.title,
              excludeSemantics: true,
              child: Text(
                pin.title,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One square making up the visual-only bottom nav.
class _NavSquare extends StatelessWidget {
  const _NavSquare();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _navSquareSize,
      height: _navSquareSize,
      decoration: BoxDecoration(
        color: const Color(0xFF32332D),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

/// A brief message at the bottom of the screen reporting that an operation
/// was executed.
///
/// Automatically calls [onDismissed] once it has been shown for
/// [_messageDuration]. Timed with an [AnimationController] that keeps
/// ticking frames, so `pumpAndSettle` can wait for it to disappear (a plain
/// [Timer] would return without waiting).
class ExecuteMessageView extends StatefulWidget {
  const ExecuteMessageView({
    super.key,
    required this.message,
    required this.onDismissed,
  });

  /// The message to show.
  final String message;

  /// Called once the message has finished being shown.
  final VoidCallback onDismissed;

  @override
  State<ExecuteMessageView> createState() => _ExecuteMessageViewState();
}

class _ExecuteMessageViewState extends State<ExecuteMessageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _messageDuration)
      ..addStatusListener(_handleStatusChange)
      ..forward();
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          widget.message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
