import 'dart:ui';

/// 長押しメニューの見た目・挙動の基準値。
abstract final class LongPressMenuMetrics {
  /// 長押しが認識されるまでの時間。
  static const Duration longPressDuration = Duration(milliseconds: 500);

  /// 長押しメニューが開閉するアニメーションの時間。
  static const Duration openDuration = Duration(milliseconds: 180);

  /// アクションボタンの強調が切り替わるアニメーションの時間。
  static const Duration highlightDuration = Duration(milliseconds: 120);

  /// 実行結果のメッセージを表示する時間。
  static const Duration messageDuration = Duration(milliseconds: 1750);

  /// 暗転層の不透明度。
  static const double dimmingOpacity = 0.6;

  /// 押されたピンが浮き上がる際の拡大率。
  static const double liftScale = 1.08;

  /// 押されたピンが浮き上がる際の傾き (度)。
  static const double tiltDegrees = -3.0;

  /// アクションボタンの直径。
  static const double buttonDiameter = 48.0;

  /// 強調されたアクションボタンの拡大率。
  static const double highlightScale = 1.35;

  /// アクションボタンが押下点から現れるときの初期拡大率。
  static const double actionButtonEnterScale = 0.6;

  /// 強調の当たり判定のしきい値 (指と最も近いアクションボタン中心の距離)。
  ///
  /// 強調されたときのボタンの半径に余裕を足した値。
  static const double highlightThreshold =
      buttonDiameter * highlightScale / 2 + 6;

  /// 長押しメニューの弧の半径。
  static const double arcRadius = 66.0;

  /// 長押しメニューの弧の広がり角 (度)。
  static const double sweepDegrees = 180.0;

  /// 弧の中心を水平から上へ傾ける角度 (度)。
  static const double arcLiftDegrees = 40.0;

  /// 非強調のアクションボタンの色。
  static const Color actionButtonColor = Color(0xFF3C3C3C);

  /// 強調されたアクションボタンの色。
  static const Color highlightedActionButtonColor = Color(0xFFFFFFFF);
}
