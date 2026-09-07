import 'package:flutter/widgets.dart';

/// One operation that the app using this package lists in the long-press
/// menu.
///
/// It has an icon widget and a spoken name, and is drawn as one action
/// button.
class FanContextMenuAction {
  /// Creates an action that draws [icon] and uses [semanticLabel] as the
  /// spoken name.
  ///
  /// Not validated here (semanticLabel is validated when the target is
  /// built).
  const FanContextMenuAction({required this.icon, required this.semanticLabel});

  /// The icon drawn on the action button.
  final Widget icon;

  /// The operation name a screen reader speaks.
  final String semanticLabel;
}
