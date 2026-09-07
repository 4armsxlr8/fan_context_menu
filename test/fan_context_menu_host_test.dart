// 公開ホスト + ピン用 Widget で長押しメニューを操作するテスト (AC-3〜AC-10, AC-12, AC-13)。

import 'package:fan_context_menu/fan_context_menu.dart';
// パッケージ本体の test/ だけが使ってよい内部 Widget。
import 'package:fan_context_menu/src/long_press_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fan_context_menu_test_helpers.dart';

/// アクションボタン中心と押下点の距離が半径と一致しているとみなす許容誤差。
const double _radiusTolerance = 2;

/// 浮き上がった複製が元のピンに重なっているとみなす許容誤差。
///
/// 拡大も傾きも中心を軸にするので中心座標も大きさも動かない。押下点を基準に
/// 置いてしまう実装との差 (数十px) は見逃さない大きさにしてある。
const double _liftedChildTolerance = 1;

/// 暗転層の矩形がホストの矩形と一致しているとみなす許容誤差。
const double _rectTolerance = 0.5;

/// アクションボタンが番号順に並んでいることを主張する。
void _expectActionButtonOrder(WidgetTester tester, int actionCount) {
  expect(
    find.byType(ActionButtonView),
    findsNWidgets(actionCount),
    reason: 'アクションボタンが $actionCount 個ある',
  );
  for (var index = 0; index < actionCount; index++) {
    expect(
      find.descendant(
        of: find.byType(ActionButtonView).at(index),
        matching: find.bySemanticsLabel(actionLabel(index)),
      ),
      findsOneWidget,
      reason: '$index 番目のアクションボタンが ${actionLabel(index)}',
    );
  }
}

/// アクションボタン中心が押下点から半径のところにあることを主張する。
void _expectButtonsOnArc(
  OpenedMenu menu, {
  FanContextMenuStyle style = defaultStyle,
}) {
  for (var index = 0; index < menu.buttonCenters.length; index++) {
    expect(
      (menu.buttonCenters[index] - menu.pressPoint).distance,
      closeTo(style.arcRadius, _radiusTolerance),
      reason: '${actionLabel(index)} のボタン中心は押下点から半径 ${style.arcRadius} のところにある',
    );
  }
}

/// 押下点がどのアクションボタンからも強調の当たり判定より遠いことを主張する。
void _expectPressPointOutsideEveryButton(
  OpenedMenu menu, {
  FanContextMenuStyle style = defaultStyle,
}) {
  for (var index = 0; index < menu.buttonCenters.length; index++) {
    expect(
      (menu.buttonCenters[index] - menu.pressPoint).distance,
      greaterThan(style.highlightThreshold),
      reason: '押下点は ${actionLabel(index)} のボタンから十分離れている',
    );
  }
}

void main() {
  group('AC-3 ピンを 500ms 静止で長押し', () {
    testWidgets(
      'ホスト内が暗転し、child の複製が元のピンと同じ位置・大きさで浮き、押下点の周りに 4 ボタンが指定順で出て、開いた時が 1 回通知される',
      (tester) async {
        setScreenSize(tester, phoneSize);
        final log = <String>[];

        await tester.pumpWidget(hostApp(log: log));
        await tester.pumpAndSettle();

        final pinRect = tester.getRect(find.byKey(pinKey(pressedPinIndex)));
        final pressPoint = pressPointOn(tester, pressedPinIndex);
        expect(pinRect.contains(pressPoint), isTrue, reason: '押下点はピンの上にある');

        final menu = await openMenu(tester, pressPoint: pressPoint);

        expect(find.byType(DimmingLayer), findsOneWidget, reason: 'ホスト内が暗転する');
        expect(
          find.byType(LiftedChildView),
          findsOneWidget,
          reason: 'child の複製が浮き上がる',
        );
        expect(
          find.text(pinTitle(pressedPinIndex)),
          findsNWidgets(2),
          reason: 'child がもう一度描かれる',
        );

        final liftedRect = tester.getRect(find.byType(LiftedChildView));
        expect(
          liftedRect.center.dx,
          closeTo(pinRect.center.dx, _liftedChildTolerance),
          reason: '複製の中心 dx が元のピンと同じ',
        );
        expect(
          liftedRect.center.dy,
          closeTo(pinRect.center.dy, _liftedChildTolerance),
          reason: '複製の中心 dy が元のピンと同じ',
        );
        expect(
          liftedRect.width,
          closeTo(pinRect.width, _liftedChildTolerance),
          reason: '複製の幅が元のピンと同じ',
        );
        expect(
          liftedRect.height,
          closeTo(pinRect.height, _liftedChildTolerance),
          reason: '複製の高さが元のピンと同じ',
        );

        _expectActionButtonOrder(tester, 4);
        _expectButtonsOnArc(menu);
        expect(log, <String>['opened'], reason: '開いた時が 1 回通知される');

        await menu.gesture.up();
        await pumpUntilClosed(tester);
      },
    );
  });

  group('AC-4 認識前 (500ms 未満) に縦に動かす', () {
    testWidgets('長押しメニューは出ず、ホスト内がスクロールし、通知は無い', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(hostApp(log: log));
      await tester.pumpAndSettle();

      expect(hostScrollPosition(tester).pixels, 0, reason: '開始時はスクロールしていない');

      final gesture = await tester.startGesture(
        pressPointOn(tester, pressedPinIndex),
        pointer: 1,
      );
      await tester.pump(const Duration(milliseconds: 100));
      // 合計 120 を [dragStartStep] の分と残りに分けて動かす。
      await gesture.moveBy(const Offset(0, -dragStartStep));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -90));
      await tester.pump();

      expect(
        find.byType(DimmingLayer),
        findsNothing,
        reason: '認識前に動かしたので長押しメニューは開かない',
      );
      expect(
        hostScrollPosition(tester).pixels,
        greaterThan(0),
        reason: 'ホスト内がスクロールする',
      );

      await tester.pump(defaultStyle.longPressDuration + afterRecognition);
      expect(
        find.byType(DimmingLayer),
        findsNothing,
        reason: '認識時間を過ぎても長押しメニューは開かない',
      );
      expect(log, isEmpty, reason: '通知は無い');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('AC-5 開いた状態で指を各ボタンへ動かし、離れる', () {
    testWidgets('乗ったボタンだけが強調され、離れると戻り、強調が変わった時が番号 / null で通知される', (
      tester,
    ) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(hostApp(log: log));
      await tester.pumpAndSettle();

      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
      );
      _expectPressPointOutsideEveryButton(menu);
      expectRenderedHighlight(tester, highlighted: null);

      for (var index = 0; index < menu.buttonCenters.length; index++) {
        await menu.gesture.moveTo(menu.buttonCenters[index]);
        await tester.pumpAndSettle();
        expectRenderedHighlight(tester, highlighted: index);
      }

      await menu.gesture.moveTo(menu.pressPoint);
      await tester.pumpAndSettle();
      expectRenderedHighlight(tester, highlighted: null);

      expect(log, <String>[
        'opened',
        'highlight:0',
        'highlight:1',
        'highlight:2',
        'highlight:3',
        'highlight:null',
      ], reason: '強調が変わるたびに番号 / null が通知される');

      await menu.gesture.up();
      await pumpUntilClosed(tester);
    });
  });

  group('AC-6 各アクションを強調して離す', () {
    for (var actionIndex = 0; actionIndex < 4; actionIndex++) {
      testWidgets(
        '${actionLabel(actionIndex)} を強調して離すと実行が番号 $actionIndex で 1 回通知され、閉じた時は通知されない',
        (tester) async {
          setScreenSize(tester, phoneSize);
          final log = <String>[];

          await tester.pumpWidget(hostApp(log: log));
          await tester.pumpAndSettle();

          final menu = await openMenu(
            tester,
            pressPoint: pressPointOn(tester, pressedPinIndex),
          );

          await menu.gesture.moveTo(menu.buttonCenters[actionIndex]);
          await tester.pumpAndSettle();
          expectRenderedHighlight(tester, highlighted: actionIndex);

          await menu.gesture.up();
          await pumpUntilClosed(tester);

          expect(log, <String>[
            'opened',
            'highlight:$actionIndex',
            'action:$actionIndex',
          ], reason: '実行が番号 $actionIndex で 1 回通知され、閉じた時は通知されない');
          expectMenuClosed();
        },
      );
    }
  });

  group('AC-7 ボタンの外で離す / ジェスチャーのキャンセル', () {
    testWidgets('ボタンの外で離すと閉じた時が 1 回通知され、実行は通知されない', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(hostApp(log: log));
      await tester.pumpAndSettle();

      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
      );
      _expectPressPointOutsideEveryButton(menu);
      expectRenderedHighlight(tester, highlighted: null);

      await menu.gesture.up();
      await pumpUntilClosed(tester);

      expect(log, <String>[
        'opened',
        'closed',
      ], reason: '閉じた時が 1 回通知され、実行は通知されない');
      expectMenuClosed();
    });

    testWidgets('強調中にジェスチャーが中断されると閉じた時が 1 回通知され、実行は通知されない', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(hostApp(log: log));
      await tester.pumpAndSettle();

      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
      );

      await menu.gesture.moveTo(menu.buttonCenters[3]);
      await tester.pumpAndSettle();
      expectRenderedHighlight(tester, highlighted: 3);

      await menu.gesture.cancel();
      await pumpUntilClosed(tester);

      expect(
        log.where((notification) => notification == 'closed'),
        hasLength(1),
        reason: '閉じた時が 1 回通知される',
      );
      expect(
        log.where((notification) => notification.startsWith('action:')),
        isEmpty,
        reason: '実行は通知されない',
      );
      expectMenuClosed();
    });
  });

  group('AC-8 表示中にスクロール操作・他のピンのタップ・2 本目の指', () {
    testWidgets('ホスト内は動かず、他の操作は起きず、長押しメニューは開いたまま', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(hostApp(log: log));
      await tester.pumpAndSettle();

      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
      );
      final pixelsWhenOpened = hostScrollPosition(tester).pixels;

      final scrollFinger = await tester.startGesture(
        const Offset(195, 700),
        pointer: 2,
      );
      await tester.pump();
      // 合計 200 を [dragStartStep] の分と残りに分けて動かす。1回にまとめると、
      // 暗転層がポインタを吸収していなくてもスクロールしない空振りの主張になる。
      await scrollFinger.moveBy(const Offset(0, -dragStartStep));
      await tester.pump();
      await scrollFinger.moveBy(const Offset(0, -170));
      await tester.pump();
      await scrollFinger.up();
      await tester.pumpAndSettle();

      expect(
        hostScrollPosition(tester).pixels,
        moreOrLessEquals(pixelsWhenOpened, epsilon: 0.01),
        reason: '2 本目の指ではホスト内がスクロールしない',
      );

      final tapFinger = await tester.startGesture(
        tester.getCenter(find.byKey(pinKey(pressedPinIndex + 1))),
        pointer: 3,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tapFinger.up();
      await tester.pumpAndSettle();

      expect(log, <String>['opened'], reason: '他のピンのタップも 2 本目の指も何も起こさない');
      expect(
        find.byType(DimmingLayer),
        findsOneWidget,
        reason: '長押しメニューは開いたまま',
      );
      expect(
        find.byType(LiftedChildView),
        findsOneWidget,
        reason: '浮き上がった複製は 1 つのまま',
      );
      _expectActionButtonOrder(tester, 4);
      expect(
        hostScrollPosition(tester).pixels,
        moreOrLessEquals(pixelsWhenOpened, epsilon: 0.01),
        reason: '他のピンを押してもホスト内は動かない',
      );

      // 1 本目の指はまだ押したまま。離すと通常どおり閉じる。
      await menu.gesture.up();
      await pumpUntilClosed(tester);
      expectMenuClosed();
    });
  });

  group('AC-9 2 アクション / 5 アクションで開く', () {
    for (final actionCount in <int>[2, 5]) {
      testWidgets('$actionCount 個のアクションボタンが指定順に押下点から半径のところへ出る', (tester) async {
        setScreenSize(tester, phoneSize);
        final log = <String>[];

        await tester.pumpWidget(hostApp(log: log, actionCount: actionCount));
        await tester.pumpAndSettle();

        final menu = await openMenu(
          tester,
          pressPoint: pressPointOn(tester, pressedPinIndex),
          actionCount: actionCount,
        );

        _expectActionButtonOrder(tester, actionCount);
        _expectButtonsOnArc(menu);
        expect(log, <String>['opened'], reason: '開いた時が 1 回通知される');

        await menu.gesture.up();
        await pumpUntilClosed(tester);
      });
    }
  });

  group('AC-10 ホストを body だけに巻き、外側に別の Widget を置いて開く', () {
    testWidgets('暗転はホストの矩形と一致して外側と重ならず、外側のボタンは押すと動く', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(
        hostApp(
          log: log,
          appBar: AppBar(
            title: const Text('見出し'),
            actions: <Widget>[
              IconButton(
                key: outsideButtonKey,
                icon: const Icon(Icons.add),
                onPressed: () => log.add(outsideButtonNotification),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final outsideRect = tester.getRect(find.byKey(outsideButtonKey));
      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
      );

      final hostRect = tester.getRect(find.byType(FanContextMenuHost));
      final dimmingRect = tester.getRect(find.byType(DimmingLayer));
      expect(
        dimmingRect.left,
        closeTo(hostRect.left, _rectTolerance),
        reason: '暗転の左端がホストと一致する',
      );
      expect(
        dimmingRect.top,
        closeTo(hostRect.top, _rectTolerance),
        reason: '暗転の上端がホストと一致する',
      );
      expect(
        dimmingRect.right,
        closeTo(hostRect.right, _rectTolerance),
        reason: '暗転の右端がホストと一致する',
      );
      expect(
        dimmingRect.bottom,
        closeTo(hostRect.bottom, _rectTolerance),
        reason: '暗転の下端がホストと一致する',
      );
      expect(
        dimmingRect.overlaps(outsideRect),
        isFalse,
        reason: 'ホストの外側の Widget は暗転しない',
      );

      await tester.tap(find.byKey(outsideButtonKey), pointer: 2);
      await tester.pump();

      expect(
        log,
        contains(outsideButtonNotification),
        reason: '外側のボタンを押すとその処理が動く',
      );
      expect(
        log.where((notification) => notification.startsWith('action:')),
        isEmpty,
        reason: '外側のボタンを押しても実行は通知されない',
      );

      await menu.gesture.up();
      await pumpUntilClosed(tester);
    });
  });

  group('AC-12 複製用 builder を渡して開く', () {
    testWidgets('浮き上がった複製が builder の結果で描かれる', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(
        hostApp(
          log: log,
          liftedChildBuilder: (context, child) => Container(
            alignment: Alignment.center,
            color: pinColor,
            child: const Text(liftedChildMarker),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
      );

      expect(
        find.descendant(
          of: find.byType(LiftedChildView),
          matching: find.text(liftedChildMarker),
        ),
        findsOneWidget,
        reason: '複製が builder の結果で描かれる',
      );
      expect(
        find.text(pinTitle(pressedPinIndex)),
        findsOneWidget,
        reason: '複製は child のままではない (元のピンだけが child を描く)',
      );

      await menu.gesture.up();
      await pumpUntilClosed(tester);
    });
  });

  group('AC-13 開く → 乗る → 離れる → 別に乗る → 実行', () {
    testWidgets('触覚の要求は 0 回で、通知は 開いた時 1 回・強調変化 3 回・実行 1 回', (tester) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];
      final hapticRequests = recordHapticRequests();

      await tester.pumpWidget(hostApp(log: log));
      await tester.pumpAndSettle();

      final menu = await openMenu(
        tester,
        pressPoint: pressPointOn(tester, pressedPinIndex),
      );
      _expectPressPointOutsideEveryButton(menu);

      await menu.gesture.moveTo(menu.buttonCenters[0]);
      await tester.pumpAndSettle();
      await menu.gesture.moveTo(menu.pressPoint);
      await tester.pumpAndSettle();
      await menu.gesture.moveTo(menu.buttonCenters[2]);
      await tester.pumpAndSettle();
      await menu.gesture.up();
      await pumpUntilClosed(tester);

      expect(log, <String>[
        'opened',
        'highlight:0',
        'highlight:null',
        'highlight:2',
        'action:2',
      ], reason: '開いた時 1 回・強調変化 3 回・実行 1 回');
      expect(hapticRequests, isEmpty, reason: 'パッケージからの触覚要求は 0 回');
      expectMenuClosed();
    });
  });
}
