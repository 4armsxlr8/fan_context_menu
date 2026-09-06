import 'dart:ui';

/// フィードに並ぶ1枚のピン。
class Pin {
  const Pin({required this.title, required this.color, required this.height});

  /// ピンの題名。
  final String title;

  /// ピンの背景色。
  final Color color;

  /// ピンの高さ (論理ピクセル)。
  final double height;
}

/// 長押しメニューが提供する4つの操作。
///
/// 宣言順は長押しメニューの弧に沿った上端側からの並びと一致する。
enum PinAction {
  hide('非表示', 'ピンを非表示にする'),
  reaction('リアクション', 'リアクションする'),
  share('共有', '共有する'),
  save('保存', '保存する');

  const PinAction(this.label, this.semanticsLabel);

  /// 画面に表示する操作名。
  final String label;

  /// スクリーンリーダーが読み上げる操作名。
  final String semanticsLabel;
}
