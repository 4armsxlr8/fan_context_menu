import 'package:flutter/foundation.dart';

/// The [Key]s tests reference.
abstract final class SampleKeys {
  /// The feed's scrollable area.
  static const feed = Key('feed');

  /// The pin at the given index.
  static Key pin(int index) => Key('pin.$index');

  /// The visual-only bottom nav.
  static const bottomNav = Key('bottomNav');
}
