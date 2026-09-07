import 'package:flutter/material.dart';

/// One pin listed in the feed.
class Pin {
  const Pin({required this.title, required this.color, required this.height});

  /// The pin's title.
  final String title;

  /// The pin's background color.
  final Color color;

  /// The pin's height (logical pixels).
  final double height;
}

/// The four operations the long-press menu provides.
///
/// The declaration order matches the order along the long-press menu's arc,
/// starting from the top end.
enum PinAction {
  hide('非表示', 'ピンを非表示にする', Icons.visibility_off_outlined),
  reaction('リアクション', 'リアクションする', Icons.favorite_border),
  share('共有', '共有する', Icons.ios_share),
  save('保存', '保存する', Icons.bookmark_border);

  const PinAction(this.label, this.semanticsLabel, this.icon);

  /// The operation name shown on screen.
  final String label;

  /// The operation name a screen reader speaks.
  final String semanticsLabel;

  /// The icon drawn on the action button.
  final IconData icon;
}
