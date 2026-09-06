import 'package:flutter/foundation.dart';

import 'pin.dart';

/// テストから参照するための [Key] 一覧。
abstract final class SampleKeys {
  /// フィードのスクロール領域。
  static const feed = Key('feed');

  /// index番目のピン。
  static Key pin(int index) => Key('pin.$index');

  /// 見た目だけの下部ナビ。
  static const bottomNav = Key('bottomNav');

  /// 長押しメニュー表示中の暗転層。
  static const dimming = Key('longPressMenu.dimming');

  /// 長押しメニューのアクションボタン。
  static Key actionButton(PinAction action) =>
      Key('actionButton.${action.name}');

  /// 長押しで浮き上がったピン。
  static const liftedPin = Key('longPressMenu.liftedPin');
}
