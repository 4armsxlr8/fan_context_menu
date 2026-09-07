// 公開ホスト + ピン用 Widget を操作するテストの共通ヘルパ。
//
// 公開入口だけで書ける操作 (ジェスチャー・通知の記録) と、パッケージ本体の
// test/ だけが使ってよい内部 Widget (暗転層・浮き上がった複製の枠・
// アクションボタン) の読み取りをまとめる。

import 'package:fan_context_menu/fan_context_menu.dart';
// パッケージ本体の test/ だけが使ってよい内部 Widget。
import 'package:fan_context_menu/src/long_press_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実機に近いスマートフォン縦向き。
const Size phoneSize = Size(390, 844);

/// 省略時の基準値。
const FanContextMenuStyle defaultStyle = FanContextMenuStyle();

/// 認識を待つときに長押し時間へ足す余裕。
const Duration afterRecognition = Duration(milliseconds: 50);

/// 縦ドラッグを開始させる最初の移動量。タッチスロップ (18) を確実に超える。
///
/// 縦ドラッグは複数回に分けて動かす。SDK 既定の [DragStartBehavior.start] では、
/// ジェスチャー競合を解決した分の移動がスクロールに反映されないため、1回の大きな
/// 移動だとスクロール量が 0 のままになる。
const double dragStartStep = 30;

/// ピン1枚の高さ。[pinCount] 枚で画面 (844) より高くなり、スクロールできる。
const double pinHeight = 240;

/// ホストに並べるピンの枚数。
const int pinCount = 6;

/// 長押しに使うピン。
///
/// 上下左右に余裕があり、既定の半径 (66) でも大きめの半径 (90) でも
/// アクションボタンがホストの内側に収まる (平行移動が起きない) 位置にある。
const int pressedPinIndex = 1;

/// 押下点をピンの中心から外す量。配置の基準がピンではなく押下点であることを見る。
const double pressPointOffsetFromPinCenter = 40;

/// ピンの背景色。
const Color pinColor = Color(0xFFDDDDDD);

/// 浮き上がった複製の見た目を差し替えたときに描かれる文言。
const String liftedChildMarker = '差し替えた複製';

/// 外側 (ホストの外) に置くボタンの Key。
const Key outsideButtonKey = ValueKey<String>('outside-button');

/// 外側のボタンが押されたときに記録する通知。
const String outsideButtonNotification = 'outside';

/// [index] のピンの Key。
Key pinKey(int index) => ValueKey<String>('pin-$index');

/// [index] のピンに描く文言。
String pinTitle(int index) => 'ピン ${index + 1}';

/// [index] のアクションの読み上げ名。
String actionLabel(int index) => 'アクション ${index + 1}';

/// 読み上げ名だけが違う [count] 個のアクション。
List<FanContextMenuAction> actionsOf(int count) {
  return List<FanContextMenuAction>.generate(
    count,
    (index) => FanContextMenuAction(
      icon: const Icon(Icons.circle),
      semanticLabel: actionLabel(index),
    ),
  );
}

/// テストの画面サイズを固定し、終了時に元へ戻す。
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// 読み上げ名も他の操作も持たないピンの child (意味情報の検証用)。
Widget plainPinChild(int index) {
  return Container(key: pinKey(index), height: pinHeight, color: pinColor);
}

/// ホストが包む縦に並んだピンと、任意の外側の Widget を持つ画面。
///
/// 通知はすべて [log] に文字列で積む
/// ('opened' / 'highlight:0' / 'highlight:null' / 'action:0' / 'closed')。
/// 既定のピンの child はタップを記録する ('tapped:0') ので、表示中に他のピンへの
/// タップが遮られているかを同じ [log] で見られる。
Widget hostApp({
  required List<String> log,
  int actionCount = 4,
  int pins = pinCount,
  FanContextMenuStyle style = defaultStyle,
  Widget Function(BuildContext context, Widget child)? liftedChildBuilder,
  Widget Function(int index)? pinChildBuilder,
  PreferredSizeWidget? appBar,
}) {
  return MaterialApp(
    home: Scaffold(
      appBar: appBar,
      body: FanContextMenuHost(
        style: style,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var index = 0; index < pins; index++)
                FanContextMenuTarget(
                  actions: actionsOf(actionCount),
                  onAction: (actionIndex) => log.add('action:$actionIndex'),
                  onOpened: () => log.add('opened'),
                  onHighlightChanged: (actionIndex) =>
                      log.add('highlight:$actionIndex'),
                  onClosed: () => log.add('closed'),
                  liftedChildBuilder: liftedChildBuilder,
                  child:
                      pinChildBuilder?.call(index) ??
                      _defaultPinChild(index, log),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 既定のピンの child。タップされたら [log] に記録する。
Widget _defaultPinChild(int index, List<String> log) {
  return GestureDetector(
    onTap: () => log.add('tapped:$index'),
    child: Container(
      key: pinKey(index),
      height: pinHeight,
      color: pinColor,
      alignment: Alignment.center,
      child: Text(pinTitle(index)),
    ),
  );
}

/// [index] のピンの上の押下点。ピンの中心から少し外した点。
///
/// 開く前に呼ぶこと (開いた後は浮き上がった複製にも同じ Key が付く)。
Offset pressPointOn(WidgetTester tester, int index) {
  return tester
      .getRect(find.byKey(pinKey(index)))
      .center
      .translate(0, -pressPointOffsetFromPinCenter);
}

/// 開いている長押しメニューと、押したままのジェスチャー。
class OpenedMenu {
  OpenedMenu({
    required this.gesture,
    required this.pressPoint,
    required this.buttonCenters,
  });

  /// まだ指を離していないジェスチャー。
  final TestGesture gesture;

  /// 長押しが認識された位置。
  final Offset pressPoint;

  /// 開いた直後のアクションボタン中心。アクションの番号順。
  final List<Offset> buttonCenters;
}

/// [pressPoint] で長押しメニューを開き、開いたことを確かめてから返す。
Future<OpenedMenu> openMenu(
  WidgetTester tester, {
  required Offset pressPoint,
  int actionCount = 4,
  FanContextMenuStyle style = defaultStyle,
  int pointer = 1,
}) async {
  final gesture = await tester.startGesture(pressPoint, pointer: pointer);
  await tester.pump(style.longPressDuration + afterRecognition);
  await tester.pumpAndSettle();

  expect(find.byType(DimmingLayer), findsOneWidget, reason: '長押しメニューが開いている');
  expect(
    find.byType(ActionButtonView),
    findsNWidgets(actionCount),
    reason: 'アクションボタンが $actionCount 個出ている',
  );

  return OpenedMenu(
    gesture: gesture,
    pressPoint: pressPoint,
    buttonCenters: <Offset>[
      for (var index = 0; index < actionCount; index++)
        tester.getCenter(find.bySemanticsLabel(actionLabel(index))),
    ],
  );
}

/// [duration] のあいだフレームを刻んで進める。
///
/// 一度に進めると、閉じるアニメーションの完了フレームを飛ばすことがある。
Future<void> pumpFrames(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

/// 閉じるアニメーションが終わるまで待つ。
Future<void> pumpUntilClosed(
  WidgetTester tester, {
  FanContextMenuStyle style = defaultStyle,
}) async {
  await pumpFrames(
    tester,
    style.openDuration + const Duration(milliseconds: 100),
  );
}

/// 長押しメニューが閉じていることを主張する。
void expectMenuClosed() {
  expect(find.byType(DimmingLayer), findsNothing, reason: '暗転が消えている');
  expect(find.byType(LiftedChildView), findsNothing, reason: '浮き上がった複製が消えている');
  expect(find.byType(ActionButtonView), findsNothing, reason: 'アクションボタンが消えている');
}

/// 描画されている暗転の濃さ (alpha)。
///
/// 暗転層は [Container] に色を渡して塗る = 内側に [ColoredBox] ができる。
double dimmingAlpha(WidgetTester tester) {
  final coloredBox = tester.widget<ColoredBox>(
    find
        .descendant(
          of: find.byType(DimmingLayer),
          matching: find.byType(ColoredBox),
        )
        .first,
  );
  return coloredBox.color.a;
}

/// [index] のアクションボタンの描画された背景色。
Color actionButtonColorOf(WidgetTester tester, int index) {
  final decoration =
      tester
              .widget<AnimatedContainer>(
                find
                    .descendant(
                      of: find.bySemanticsLabel(actionLabel(index)),
                      matching: find.byType(AnimatedContainer),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration?;
  return decoration!.color!;
}

/// [index] のアクションボタンの描画された拡大率。
double actionButtonScaleOf(WidgetTester tester, int index) {
  return tester
      .widget<AnimatedScale>(
        find
            .descendant(
              of: find.bySemanticsLabel(actionLabel(index)),
              matching: find.byType(AnimatedScale),
            )
            .first,
      )
      .scale;
}

/// [index] のアクションボタンの描画されたアイコン色。
Color actionIconColorOf(WidgetTester tester, int index) {
  return tester
      .widget<IconTheme>(
        find
            .descendant(
              of: find.bySemanticsLabel(actionLabel(index)),
              matching: find.byType(IconTheme),
            )
            .first,
      )
      .data
      .color!;
}

/// 描画されたアクションボタンの強調を主張する。
///
/// [highlighted] のボタンだけが [FanContextMenuStyle.highlightedActionButtonColor]
/// 背景・[FanContextMenuStyle.highlightedIconColor] のアイコン・
/// [FanContextMenuStyle.highlightScale] 倍で、他は非強調の値になる
/// (= 同時に2つ強調されることはない)。
void expectRenderedHighlight(
  WidgetTester tester, {
  required int? highlighted,
  int actionCount = 4,
  FanContextMenuStyle style = defaultStyle,
}) {
  for (var index = 0; index < actionCount; index++) {
    final isHighlighted = index == highlighted;
    expect(
      actionButtonColorOf(tester, index),
      isHighlighted
          ? style.highlightedActionButtonColor
          : style.actionButtonColor,
      reason: '${actionLabel(index)} の背景色 (強調: $isHighlighted)',
    );
    expect(
      actionButtonScaleOf(tester, index),
      isHighlighted ? style.highlightScale : 1.0,
      reason: '${actionLabel(index)} の拡大率 (強調: $isHighlighted)',
    );
    expect(
      actionIconColorOf(tester, index),
      isHighlighted ? style.highlightedIconColor : style.iconColor,
      reason: '${actionLabel(index)} のアイコン色 (強調: $isHighlighted)',
    );
  }
}

/// ホスト内の縦スクロール位置。
ScrollPosition hostScrollPosition(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(FanContextMenuHost),
          matching: find.byType(Scrollable),
        ),
      )
      .position;
}

/// 触覚の要求が届くプラットフォームチャネルのメソッド名。
const String _hapticMethod = 'HapticFeedback.vibrate';

/// 触覚の要求を出た順に記録し始め、終了時に記録をやめる。
///
/// 返すのは記録そのもの。引数を型変換せずそのまま入れるので、引数なしの
/// `HapticFeedback.vibrate()` が呼ばれた場合も null として現れる。
List<Object?> recordHapticRequests() {
  final requests = <Object?>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == _hapticMethod) {
      requests.add(call.arguments);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return requests;
}
