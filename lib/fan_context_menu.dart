/// A package that provides a long-press menu showing fan-shaped action
/// buttons around the press point.
///
/// The app using this package wraps the screen (or the area where the
/// long-press menu is used) with the host (FanContextMenuHost), and wraps
/// each pin that should show the long-press menu with the target
/// (FanContextMenuTarget).
library;

export 'src/fan_context_menu_action.dart';
// FanContextMenuHostState is an implementation detail the target uses to
// report open/close, finger movement, execute, and cancel to the host
// (hidden from the public entry point).
export 'src/fan_context_menu_host.dart' hide FanContextMenuHostState;
export 'src/fan_context_menu_style.dart';
export 'src/fan_context_menu_target.dart';
