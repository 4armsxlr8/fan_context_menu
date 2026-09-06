import 'package:flutter/material.dart';

import 'keys.dart';
import 'long_press_menu_metrics.dart';
import 'menu_geometry.dart';
import 'pin.dart';

/// 長押しメニューの開閉のうち、位置・拡大縮小の変化に使うカーブ。
const _openMotionCurve = Curves.easeOut;

/// 長押しメニューの開閉のうち、フェードの変化に使うカーブ。
const _openFadeCurve = Curves.ease;

/// 長押しメニューを構成する円形のアクションボタン1つ。
///
/// [highlighted] が true のとき白背景・黒アイコン・[LongPressMenuMetrics.highlightScale]
/// 倍で表示する。false のときは [LongPressMenuMetrics.actionButtonColor] 背景・白アイコン。
class ActionButtonView extends StatelessWidget {
  const ActionButtonView({
    super.key,
    required this.action,
    required this.highlighted,
  });

  /// このボタンが表す操作。
  final PinAction action;

  /// 指が乗って強調されているか。
  final bool highlighted;

  static const _icons = <PinAction, IconData>{
    PinAction.hide: Icons.visibility_off_outlined,
    PinAction.reaction: Icons.favorite_border,
    PinAction.share: Icons.ios_share,
    PinAction.save: Icons.bookmark_border,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: highlighted ? LongPressMenuMetrics.highlightScale : 1.0,
      duration: LongPressMenuMetrics.highlightDuration,
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: LongPressMenuMetrics.highlightDuration,
        curve: Curves.easeOut,
        width: LongPressMenuMetrics.buttonDiameter,
        height: LongPressMenuMetrics.buttonDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlighted
              ? LongPressMenuMetrics.highlightedActionButtonColor
              : LongPressMenuMetrics.actionButtonColor,
        ),
        child: Icon(
          _icons[action],
          color: highlighted ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

/// 長押しメニュー表示中に、押したピン以外の画面全体を暗くする層。
///
/// [absorbing] が true のあいだ [AbsorbPointer] でポインタを吸収し、フィードの
/// スクロールや他のピン・ナビへのタップを遮る。閉じるアニメーションの最中は
/// 呼び出し側が false を渡し、離した直後の操作をすぐ通す。[openProgress]
/// (0が閉、1が開) に応じて不透明度をフェードする。
class DimmingLayer extends StatelessWidget {
  const DimmingLayer({
    super.key,
    required this.openProgress,
    required this.absorbing,
  });

  /// 開閉の進み具合 (0 が閉、1 が開)。
  final double openProgress;

  /// ポインタを吸収するか。
  final bool absorbing;

  @override
  Widget build(BuildContext context) {
    final opacity =
        _openFadeCurve.transform(openProgress) *
        LongPressMenuMetrics.dimmingOpacity;
    return AbsorbPointer(
      absorbing: absorbing,
      child: Container(color: Colors.black.withValues(alpha: opacity)),
    );
  }
}

/// ピンの背景色・角丸。フィードのピンと [LiftedPinView] が共用する。
BoxDecoration pinDecoration(Pin pin) =>
    BoxDecoration(color: pin.color, borderRadius: BorderRadius.circular(16));

/// 長押しで押したピンの複製。
///
/// 元のピンと同じ位置・大きさに置かれ、中心を軸に拡大・傾き・影を付けて浮かせる。
/// [openProgress] (0が閉、1が開) に応じて、拡大・傾きなしの状態から
/// [LongPressMenuMetrics.liftScale] / [LongPressMenuMetrics.tiltDegrees] まで動く。
class LiftedPinView extends StatelessWidget {
  const LiftedPinView({
    super.key,
    required this.pin,
    required this.openProgress,
  });

  /// 浮き上がらせるピン。
  final Pin pin;

  /// 開閉の進み具合 (0 が閉、1 が開)。
  final double openProgress;

  @override
  Widget build(BuildContext context) {
    final motion = _openMotionCurve.transform(openProgress);
    final scale = Tween<double>(
      begin: 1.0,
      end: LongPressMenuMetrics.liftScale,
    ).transform(motion);
    final tiltDegrees = LongPressMenuMetrics.tiltDegrees * motion;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(scale, scale, 1, 1)
        ..rotateZ(degreesToRadians(tiltDegrees)),
      child: Container(
        decoration: pinDecoration(pin).copyWith(
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }
}

/// 開いている長押しメニューの中身 (暗転・浮き上がったピン・4つのアクションボタン)。
///
/// 呼び出し側 ([FeedPage]) が [openProgress] (0が閉、1が開) を渡す。ここではその
/// 進み具合に応じたフェード・移動・拡大縮小と、指が動くたびの強調を行う。
class LongPressMenuView extends StatelessWidget {
  const LongPressMenuView({
    super.key,
    required this.pin,
    required this.pinRect,
    required this.pressPoint,
    required this.buttonCenters,
    required this.highlightedAction,
    required this.openProgress,
    required this.absorbing,
  });

  /// 押されて浮き上がっているピン。
  final Pin pin;

  /// 元のピンの位置・大きさ。
  final Rect pinRect;

  /// 長押しが認識された押下点。アクションボタンはここから現れ、ここへ戻る。
  final Offset pressPoint;

  /// アクションボタン中心 (開ききったときの位置)。[PinAction.values] の順。
  final List<Offset> buttonCenters;

  /// いま強調されているアクション。無ければ null。
  final PinAction? highlightedAction;

  /// 開閉の進み具合 (0 が閉、1 が開)。
  final double openProgress;

  /// [DimmingLayer] がポインタを吸収するか。
  final bool absorbing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DimmingLayer(
            key: SampleKeys.dimming,
            openProgress: openProgress,
            absorbing: absorbing,
          ),
        ),
        Positioned.fromRect(
          rect: pinRect,
          child: LiftedPinView(
            key: SampleKeys.liftedPin,
            pin: pin,
            openProgress: openProgress,
          ),
        ),
        for (final action in PinAction.values)
          _AnimatedActionButton(
            action: action,
            pressPoint: pressPoint,
            targetCenter: buttonCenters[action.index],
            highlighted: highlightedAction == action,
            openProgress: openProgress,
          ),
      ],
    );
  }
}

/// 開閉の進み具合に応じて、押下点と最終位置のあいだを動きながら現れる/戻る
/// アクションボタン1つ。拡大・不透明度も同じ進み具合で動く。
class _AnimatedActionButton extends StatelessWidget {
  const _AnimatedActionButton({
    required this.action,
    required this.pressPoint,
    required this.targetCenter,
    required this.highlighted,
    required this.openProgress,
  });

  final PinAction action;
  final Offset pressPoint;
  final Offset targetCenter;
  final bool highlighted;
  final double openProgress;

  @override
  Widget build(BuildContext context) {
    final motion = _openMotionCurve.transform(openProgress);
    final fade = _openFadeCurve.transform(openProgress);
    final center = Offset.lerp(pressPoint, targetCenter, motion)!;
    final scale = Tween<double>(
      begin: LongPressMenuMetrics.actionButtonEnterScale,
      end: 1.0,
    ).transform(motion);
    return Positioned(
      left: center.dx - LongPressMenuMetrics.buttonDiameter / 2,
      top: center.dy - LongPressMenuMetrics.buttonDiameter / 2,
      child: Opacity(
        opacity: fade,
        child: Transform.scale(
          scale: scale,
          child: ActionButtonView(
            key: SampleKeys.actionButton(action),
            action: action,
            highlighted: highlighted,
          ),
        ),
      ),
    );
  }
}

/// 操作を実行したことを画面下部に短く伝えるメッセージ。
///
/// [LongPressMenuMetrics.messageDuration] だけ表示すると自動的に [onDismissed] を
/// 呼ぶ。フレームを刻み続ける [AnimationController] で時間を計るため、
/// `pumpAndSettle` で消えるまで待てる (素の [Timer] だと待たずに終わってしまう)。
class ExecuteMessageView extends StatefulWidget {
  const ExecuteMessageView({
    super.key,
    required this.message,
    required this.onDismissed,
  });

  /// 表示するメッセージ。
  final String message;

  /// 表示し終えたときに呼ぶ。
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
    _controller =
        AnimationController(
            vsync: this,
            duration: LongPressMenuMetrics.messageDuration,
          )
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
