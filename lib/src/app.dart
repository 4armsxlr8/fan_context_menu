import 'package:flutter/material.dart';

import 'feed_page.dart';
import 'pin.dart';
import 'sample_pins.dart';

/// サンプルのルートウィジェット。
class App extends StatelessWidget {
  const App({super.key, this.pins = samplePins});

  /// フィードに表示するピンの一覧。
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
