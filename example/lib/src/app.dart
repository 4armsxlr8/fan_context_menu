import 'package:flutter/material.dart';

import 'feed_page.dart';
import 'pin.dart';
import 'sample_pins.dart';

/// The sample's root widget.
class App extends StatelessWidget {
  const App({super.key, this.pins = samplePins});

  /// The list of pins shown in the feed.
  final List<Pin> pins;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
      ),
      home: FeedPage(pins: pins),
    );
  }
}
