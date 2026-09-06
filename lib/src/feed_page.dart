import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'keys.dart';
import 'long_press_menu.dart';
import 'long_press_menu_metrics.dart';
import 'menu_geometry.dart';
import 'pin.dart';

/// 下部ナビの正方形1つの一辺の長さ。
const double _navSquareSize = 52;

/// 下部ナビの正方形どうしの間隔。
const double _navSpacing = 8;

/// ホーム画面。
///
/// ヘッダ・タブ行・2列のピンを縦スクロールで表示し、最前面に見た目だけの
/// 下部ナビを重ねる。ピンの通常タップとナビのタップでは何も起きない。
class FeedPage extends StatefulWidget {
  const FeedPage({super.key, required this.pins});

  /// フィードに表示するピンの一覧。
  final List<Pin> pins;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

/// 開いている長押しメニューの状態。常にまとめて立ち、まとめて消える。
class _OpenLongPressMenu {
  _OpenLongPressMenu({
    required this.pinIndex,
    required this.pinRect,
    required this.pressPoint,
    required this.buttonCenters,
  });

  /// 長押しメニューが表示されているピンの index。
  final int pinIndex;

  /// 長押し開始時に測った、元のピンの位置・大きさ。
  final Rect pinRect;

  /// 長押しが認識された押下点。アクションボタンの開始位置・終了位置の基準。
  final Offset pressPoint;

  /// 開いたときに一度だけ計算するアクションボタン中心。[PinAction.values] の順。
  final List<Offset> buttonCenters;
}

class _FeedPageState extends State<FeedPage>
    with SingleTickerProviderStateMixin {
  /// 長押しメニューの開閉の進み具合 (0 が閉、1 が開) を管理する。
  ///
  /// 閉じるアニメーションのあいだも [_openMenu] の表示用の状態を残すので、
  /// 完了を待ってから消す ([_closeMenu] 参照)。
  late final AnimationController _menuController;

  /// [_PinGrid] へ渡すコールバック一式。[widget.pins] が変わっても不変。
  late final _PinCallbacks _pinCallbacks = _PinCallbacks(
    onLongPressStart: _handleLongPressStart,
    onLongPressMoveUpdate: _handleLongPressMoveUpdate,
    onLongPressEnd: _handleLongPressEnd,
    onLongPressCancel: _handleLongPressCancel,
    onCustomSemanticsAction: _handleCustomSemanticsAction,
  );

  /// ピン一覧の表示。[widget.pins] が変わったときだけ作り直す
  /// ([didUpdateWidget] 参照)。強調・長押しメニューの状態が変わるたびの
  /// [build] では同じインスタンスを置くことで、その配下の再ビルドを飛ばす。
  late Widget _pinsView;

  /// 開いている長押しメニューの状態。閉じきっていれば null。
  _OpenLongPressMenu? _openMenu;

  /// 指に最も近く強調されているアクション。
  PinAction? _highlightedAction;

  /// 強調のヒステリシス。
  ///
  /// 指が押下点から [LongPressMenuMetrics.highlightThreshold] より遠くへ
  /// 一度離れるまでは強調を無効にする (画面端の近くでボタンが押下点のすぐ近くへ
  /// 平行移動されたとき、指の微小な揺れで強調 → 実行されてしまうのを防ぐ)。
  /// 一度有効になったら、このメニューが閉じるまで有効のまま。
  bool _highlightArmed = false;

  /// 直前に実行した操作のメッセージ。表示していなければ null。
  String? _executeMessage;

  /// 実行のたびに増やす通し番号。同じ文言のメッセージが続いても
  /// [ExecuteMessageView] を作り直させ、表示時間を最初から数え直させるための鍵。
  int _messageToken = 0;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: LongPressMenuMetrics.openDuration,
    );
    _pinsView = _buildPinsView();
  }

  @override
  void didUpdateWidget(FeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pins != widget.pins) {
      _pinsView = _buildPinsView();
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  Widget _buildPinsView() {
    return widget.pins.isEmpty
        ? const _EmptyFeed()
        : _PinGrid(pins: widget.pins, callbacks: _pinCallbacks);
  }

  void _handleLongPressStart(
    int index,
    Rect pinRect,
    LongPressStartDetails details,
  ) {
    // 既に開いている (閉じるアニメーション中も含む) あいだは、別の指の長押しを無視する。
    if (_openMenu != null) return;
    final pressPoint = details.globalPosition;
    setState(() {
      _highlightedAction = null;
      _highlightArmed = false;
      _openMenu = _OpenLongPressMenu(
        pinIndex: index,
        pinRect: pinRect,
        pressPoint: pressPoint,
        buttonCenters: actionButtonCenters(
          pressPoint: pressPoint,
          screenSize: MediaQuery.sizeOf(context),
          padding: MediaQuery.paddingOf(context),
        ),
      );
    });
    _menuController.forward(from: 0);
    // 長押しメニューが開いた瞬間の触覚。
    HapticFeedback.mediumImpact();
  }

  void _handleLongPressMoveUpdate(
    int index,
    LongPressMoveUpdateDetails details,
  ) {
    final menu = _openMenu;
    if (menu == null || menu.pinIndex != index) return;
    final fingerPosition = details.globalPosition;
    if (!_highlightArmed &&
        (fingerPosition - menu.pressPoint).distance >
            LongPressMenuMetrics.highlightThreshold) {
      _highlightArmed = true;
    }
    final action = _highlightArmed
        ? highlightedActionAt(
            fingerPosition: fingerPosition,
            centers: menu.buttonCenters,
            threshold: LongPressMenuMetrics.highlightThreshold,
          )
        : null;
    if (action != _highlightedAction) {
      setState(() => _highlightedAction = action);
      // 指が別のアクションボタンに乗った瞬間の触覚。離れた時には出さない。
      if (action != null) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handleLongPressEnd(int index, LongPressEndDetails details) {
    final menu = _openMenu;
    if (menu == null || menu.pinIndex != index) return;
    final action = _highlightedAction;
    if (action != null) {
      setState(() => _showExecuteMessage(widget.pins[index], action));
    }
    _closeMenu();
  }

  /// 読み上げのカスタムアクションを実行したときの処理。
  ///
  /// 長押しの実行と同じメッセージを出すだけで、暗転・複製・アクションボタンの
  /// 状態は立てず、[HapticFeedback] も鳴らさない。
  void _handleCustomSemanticsAction(int index, PinAction action) {
    setState(() => _showExecuteMessage(widget.pins[index], action));
  }

  /// 実行したことを伝えるメッセージを出す。長押しの実行と読み上げの
  /// カスタムアクションの実行が共用する。
  void _showExecuteMessage(Pin pin, PinAction action) {
    _messageToken++;
    _executeMessage = '『${pin.title}』を${action.label}';
  }

  void _handleLongPressCancel(int index) {
    final menu = _openMenu;
    if (menu == null || menu.pinIndex != index) return;
    _closeMenu();
  }

  /// 長押しメニューを閉じるアニメーションを開始し、終わったら表示用の状態を消す。
  ///
  /// 強調はここでまとめて消す (呼び出し元での個別のクリアは不要)。
  void _closeMenu() {
    setState(() => _highlightedAction = null);
    _menuController.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() => _openMenu = null);
    });
  }

  /// [token] が発行時のメッセージのものと一致するときだけメッセージを消す。
  ///
  /// 前のメッセージが消える寸前に次の実行が重なっても、次のメッセージまで
  /// 巻き添えで消さないための確認 ([ExecuteMessageView] は [_messageToken] を
  /// 鍵にして作り直されるが、消える通知自体は非同期に届くため)。
  void _dismissMessage(int token) {
    if (token != _messageToken) return;
    setState(() => _executeMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final navBottomOffset = math.max(
      32.0,
      MediaQuery.paddingOf(context).bottom,
    );
    // ピンの末尾がナビに隠れないための余白。
    final trailingClearance = navBottomOffset + _navSquareSize + 16;
    // このフレームで作る ExecuteMessageView が消える通知に使う番号を固定する。
    final messageToken = _messageToken;

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            key: SampleKeys.feed,
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: 8),
                const _TabsRow(),
                const SizedBox(height: 12),
                _pinsView,
                SizedBox(height: trailingClearance),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: navBottomOffset,
            child: Center(
              key: SampleKeys.bottomNav,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavSquare(),
                  SizedBox(width: _navSpacing),
                  _NavSquare(),
                  SizedBox(width: _navSpacing),
                  _NavSquare(),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _menuController,
            builder: (context, _) {
              final menu = _openMenu;
              if (menu == null) {
                return const SizedBox.shrink();
              }
              return SizedBox.expand(
                child: LongPressMenuView(
                  pin: widget.pins[menu.pinIndex],
                  pinRect: menu.pinRect,
                  pressPoint: menu.pressPoint,
                  buttonCenters: menu.buttonCenters,
                  highlightedAction: _highlightedAction,
                  openProgress: _menuController.value,
                  // 閉じるアニメーションのあいだはポインタを吸収せず、離した直後の
                  // 操作をすぐ通す。
                  absorbing: _menuController.status != AnimationStatus.reverse,
                ),
              );
            },
          ),
          if (_executeMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: trailingClearance,
              child: Center(
                child: ExecuteMessageView(
                  key: ValueKey(messageToken),
                  message: _executeMessage!,
                  onDismissed: () => _dismissMessage(messageToken),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 「Pinterest」の文字と、+・吹き出しの2アイコンを並べるヘッダ。
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Pinterest',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Row(
            children: [
              Icon(Icons.add, color: Colors.white),
              SizedBox(width: 20),
              Icon(Icons.chat_bubble_outline, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

/// 見た目だけのタブ行。
class _TabsRow extends StatelessWidget {
  const _TabsRow();

  static const _labels = <String>['すべて', '怪異', 'マインクラフトの建物', 'チュートリアル'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Text(
                _labels[i],
                style: TextStyle(
                  color: i == 0 ? Colors.white : Colors.white54,
                  fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ピンが0件のときに中央へ出す空表示。
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: const Center(
        child: Text('アイデアはまだありません', style: TextStyle(color: Colors.white70)),
      ),
    );
  }
}

/// [_PinView] が親 ([_FeedPageState]) へ通知するコールバック一式。
///
/// 1つにまとめることで、[_PinGrid] は index ごとに閉包を作らず、同じ
/// インスタンスをすべての [_PinView] へそのまま渡せる。
class _PinCallbacks {
  const _PinCallbacks({
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
    required this.onCustomSemanticsAction,
  });

  final void Function(int index, Rect pinRect, LongPressStartDetails details)
  onLongPressStart;
  final void Function(int index, LongPressMoveUpdateDetails details)
  onLongPressMoveUpdate;
  final void Function(int index, LongPressEndDetails details) onLongPressEnd;
  final void Function(int index) onLongPressCancel;
  final void Function(int index, PinAction action) onCustomSemanticsAction;
}

/// ピンを2列に振り分けて並べる。偶数indexは左列、奇数indexは右列。
class _PinGrid extends StatelessWidget {
  const _PinGrid({required this.pins, required this.callbacks});

  final List<Pin> pins;
  final _PinCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < pins.length; i++) {
      final view = _PinView(index: i, pin: pins[i], callbacks: callbacks);
      (i.isEven ? left : right).add(view);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: left)),
          const SizedBox(width: 8),
          Expanded(child: Column(children: right)),
        ],
      ),
    );
  }
}

/// 1枚のピン。単色の角丸ボックスと、その下の題名。
///
/// 色付きボックスを [GestureDetector] で包み、長押しメニューのジェスチャーを
/// 拾う。長押し開始時には、ボックスの位置に置いた [Builder] の
/// [BuildContext] から自分の位置・大きさを測り、[_PinCallbacks.onLongPressStart]
/// にそのまま渡す (親が index ごとの鍵を管理する必要をなくす)。
///
/// この [GestureDetector] を含む全体をさらに [Semantics] で包み、題名と
/// 4操作のカスタムアクションを持つ1つの意味ノードにする。長押しの
/// ジェスチャーは [GestureDetector.excludeFromSemantics] で意味情報から
/// 除外する (除外しないと読み上げの長押し操作がピンの中心を押下点とした
/// 開始→終了の連続呼び出しに写り、暗転が一瞬出て触覚も鳴る)。
class _PinView extends StatelessWidget {
  const _PinView({
    required this.index,
    required this.pin,
    required this.callbacks,
  });

  final int index;
  final Pin pin;
  final _PinCallbacks callbacks;

  /// ボックスの位置に置いた [Builder] の [context] から、その位置・大きさを測る。
  ///
  /// このコールバックはジェスチャーが認識された後にしか呼ばれないので、
  /// [context] のレンダーツリーは必ず構築済み。
  static Rect _measureBox(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: pin.title,
        customSemanticsActions: {
          for (final action in PinAction.values)
            CustomSemanticsAction(label: action.semanticsLabel): () =>
                callbacks.onCustomSemanticsAction(index, action),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (boxContext) => GestureDetector(
                excludeFromSemantics: true,
                onLongPressStart: (details) => callbacks.onLongPressStart(
                  index,
                  _measureBox(boxContext),
                  details,
                ),
                onLongPressMoveUpdate: (details) =>
                    callbacks.onLongPressMoveUpdate(index, details),
                onLongPressEnd: (details) =>
                    callbacks.onLongPressEnd(index, details),
                onLongPressCancel: () => callbacks.onLongPressCancel(index),
                child: Container(
                  key: SampleKeys.pin(index),
                  height: pin.height,
                  decoration: pinDecoration(pin),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(pin.title, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// 見た目だけの下部ナビを構成する正方形1つ。
class _NavSquare extends StatelessWidget {
  const _NavSquare();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _navSquareSize,
      height: _navSquareSize,
      decoration: BoxDecoration(
        color: const Color(0xFF32332D),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
