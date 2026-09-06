import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinterest_long_press_menu/src/app.dart';
import 'package:pinterest_long_press_menu/src/feed_page.dart';
import 'package:pinterest_long_press_menu/src/keys.dart';
import 'package:pinterest_long_press_menu/src/long_press_menu.dart';
import 'package:pinterest_long_press_menu/src/pin.dart';
import 'package:pinterest_long_press_menu/src/sample_pins.dart';

/// 実機に近いスマートフォン縦向き。タップ対象が画面内に来る大きさ。
const Size _phoneSize = Size(390, 844);

/// ダミーピン10枚が一度に画面へ収まる高さ。全件の表示を主張するために使う。
const Size _tallSize = Size(390, 3000);

/// テストの画面サイズを固定し、終了時に元へ戻す。
void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// 長押しメニューもメッセージも出ておらず、フィード画面のままであることを主張する。
void _expectFeedUnchanged() {
  expect(find.byType(FeedPage), findsOneWidget, reason: '新しい画面が開いていない');
  expect(find.byKey(SampleKeys.dimming), findsNothing, reason: '暗転が出ていない');
  for (final action in PinAction.values) {
    expect(
      find.byKey(SampleKeys.actionButton(action)),
      findsNothing,
      reason: '${action.name} のアクションボタンが出ていない',
    );
  }
  expect(find.byType(ExecuteMessageView), findsNothing, reason: 'メッセージが出ていない');
  expect(find.textContaining('『'), findsNothing, reason: 'メッセージの文言が出ていない');
}

/// 実行時に出るメッセージ。
String _executeMessage(Pin pin, PinAction action) =>
    '『${pin.title}』を${action.label}';

/// 長押しメニューの見た目 (暗転・浮き上がったピン・アクションボタン) が
/// どれも出ていないことを主張する。[moment] は失敗時にどの時点かを示す。
void _expectMenuInvisible(String moment) {
  expect(
    find.byKey(SampleKeys.dimming),
    findsNothing,
    reason: '$moment: 暗転が出ていない',
  );
  expect(
    find.byKey(SampleKeys.liftedPin),
    findsNothing,
    reason: '$moment: 浮き上がったピンが出ていない',
  );
  for (final action in PinAction.values) {
    expect(
      find.byKey(SampleKeys.actionButton(action)),
      findsNothing,
      reason: '$moment: ${action.name} のアクションボタンが出ていない',
    );
  }
}

/// 意味ノードに付いているカスタムアクションの読み上げ名。
Iterable<String?> _customActionLabels(SemanticsData data) =>
    (data.customSemanticsActionIds ?? const <int>[]).map(
      (id) => CustomSemanticsAction.getAction(id)?.label,
    );

void main() {
  group('AC-1 初回起動', () {
    testWidgets('ピン一覧が表示され、暗転もアクションボタンも無い', (tester) async {
      _setScreenSize(tester, _tallSize);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(samplePins, isNotEmpty, reason: 'ダミーピンが用意されている');
      for (var i = 0; i < samplePins.length; i++) {
        expect(
          find.byKey(SampleKeys.pin(i)),
          findsOneWidget,
          reason: 'index $i のピン',
        );
        expect(
          find.text(samplePins[i].title),
          findsOneWidget,
          reason: 'index $i の題名 ${samplePins[i].title}',
        );
      }
      expect(
        find.byKey(SampleKeys.pin(samplePins.length)),
        findsNothing,
        reason: 'samplePins より多くのピンは出ていない',
      );

      expect(find.byKey(SampleKeys.bottomNav), findsOneWidget, reason: '下部ナビ');
      expect(find.byKey(SampleKeys.dimming), findsNothing, reason: '暗転');
      for (final action in PinAction.values) {
        expect(
          find.byKey(SampleKeys.actionButton(action)),
          findsNothing,
          reason: '${action.name} のアクションボタン',
        );
      }
    });
  });

  group('AC-11 ピン0件', () {
    testWidgets('空表示になり長押し対象のピンが無い', (tester) async {
      _setScreenSize(tester, _phoneSize);

      await tester.pumpWidget(const App(pins: <Pin>[]));
      await tester.pumpAndSettle();

      expect(find.text('アイデアはまだありません'), findsOneWidget);
      expect(find.byKey(SampleKeys.pin(0)), findsNothing, reason: '長押し対象のピン');
    });
  });

  group('AC-12 ピンを通常タップ', () {
    testWidgets('何も起きない', (tester) async {
      _setScreenSize(tester, _phoneSize);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(SampleKeys.pin(0)));
      await tester.pumpAndSettle();

      _expectFeedUnchanged();
      expect(find.byKey(SampleKeys.pin(0)), findsOneWidget, reason: '押したピン');
      expect(
        find.text(samplePins.first.title),
        findsOneWidget,
        reason: '押したピンの題名',
      );
    });
  });

  group('AC-15 下部ナビをタップ', () {
    testWidgets('何も起きない', (tester) async {
      _setScreenSize(tester, _phoneSize);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(SampleKeys.bottomNav), warnIfMissed: false);
      await tester.pumpAndSettle();

      _expectFeedUnchanged();
      expect(find.byKey(SampleKeys.bottomNav), findsOneWidget, reason: '下部ナビ');
      expect(find.byKey(SampleKeys.pin(0)), findsOneWidget, reason: '先頭のピン');
      expect(
        find.text(samplePins.first.title),
        findsOneWidget,
        reason: '先頭のピンの題名',
      );
    });
  });

  group('AC-13 読み上げ情報を確認し、カスタムアクションを実行', () {
    testWidgets('各ピンに題名と4操作のカスタムアクションがあり、長押しは意味情報に出ない', (tester) async {
      _setScreenSize(tester, _tallSize);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      for (var i = 0; i < samplePins.length; i++) {
        final pin = samplePins[i];
        final data = tester
            .getSemantics(find.byKey(SampleKeys.pin(i)))
            .getSemanticsData();

        expect(
          data.label,
          contains(pin.title),
          reason: 'index $i の意味ノードが題名 ${pin.title} を読み上げる',
        );
        expect(
          data.customSemanticsActionIds ?? const <int>[],
          hasLength(PinAction.values.length),
          reason: 'index $i のカスタムアクションが4件',
        );
        expect(
          _customActionLabels(data),
          unorderedEquals(<String>[
            for (final action in PinAction.values) action.semanticsLabel,
          ]),
          reason: 'index $i のカスタムアクションが4操作の読み上げ名でそろっている',
        );
        expect(
          data.hasAction(SemanticsAction.longPress),
          isFalse,
          reason: 'index $i の長押しが意味情報から除外されている',
        );
      }
    });

    testWidgets('カスタムアクションを実行すると同じメッセージが出て、暗転もアクションボタンも出ない', (tester) async {
      _setScreenSize(tester, _phoneSize);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final pin = samplePins.first;
      for (final action in PinAction.values) {
        final node = tester.getSemantics(find.byKey(SampleKeys.pin(0)));
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
            CustomSemanticsAction(label: action.semanticsLabel),
          ),
        );
        await tester.pump();

        expect(
          find.text(_executeMessage(pin, action)),
          findsOneWidget,
          reason: '${action.name} を実行したメッセージ',
        );
        _expectMenuInvisible('${action.name} の実行直後');

        await tester.pumpAndSettle();

        expect(
          find.textContaining('『'),
          findsNothing,
          reason: '${action.name} のメッセージが消えている',
        );
        _expectMenuInvisible('${action.name} のメッセージが消えたあと');
      }
    });
  });
}
