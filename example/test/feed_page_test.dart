// 利用例アプリのフィード画面のテスト (前 spec AC-1 / AC-11 / AC-12 / AC-13 / AC-15。新 spec AC-18)。
//
// 利用例アプリ自身のファイルと公開入口 (package:fan_context_menu/fan_context_menu.dart)
// だけで書く。長押しメニューの内部 Widget は参照しない。

import 'package:fan_context_menu_example/src/app.dart';
import 'package:fan_context_menu_example/src/feed_page.dart';
import 'package:fan_context_menu_example/src/keys.dart';
import 'package:fan_context_menu_example/src/pin.dart';
import 'package:fan_context_menu_example/src/sample_pins.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// アクションボタンが1つも出ていないことを主張する。
///
/// アクションボタンは開いているあいだだけ、操作の読み上げ名を持つ意味ノードとして
/// 現れる (公開面からの観測方法)。[moment] は失敗時にどの時点かを示す。
void _expectNoActionButtons(String moment) {
  for (final action in PinAction.values) {
    expect(
      find.bySemanticsLabel(action.semanticsLabel),
      findsNothing,
      reason: '$moment: ${action.name} のアクションボタンが出ていない',
    );
  }
}

/// 長押しメニューもメッセージも出ておらず、フィード画面のままであることを主張する。
void _expectFeedUnchanged() {
  expect(find.byType(FeedPage), findsOneWidget, reason: '新しい画面が開いていない');
  _expectNoActionButtons('操作のあと');
  expect(find.textContaining('『'), findsNothing, reason: 'メッセージの文言が出ていない');
}

/// 実行時に出るメッセージ。
String _executeMessage(Pin pin, PinAction action) =>
    '『${pin.title}』を${action.label}';

/// 意味ノードに付いているカスタムアクションの読み上げ名。
Iterable<String?> _customActionLabels(SemanticsData data) =>
    (data.customSemanticsActionIds ?? const <int>[]).map(
      (id) => CustomSemanticsAction.getAction(id)?.label,
    );

void main() {
  group('前 spec AC-1 初回起動', () {
    testWidgets('ピン一覧が表示され、アクションボタンは無い', (tester) async {
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
      _expectNoActionButtons('初回起動');
    });
  });

  group('前 spec AC-11 ピン0件', () {
    testWidgets('空表示になり長押し対象のピンが無い', (tester) async {
      _setScreenSize(tester, _phoneSize);

      await tester.pumpWidget(const App(pins: <Pin>[]));
      await tester.pumpAndSettle();

      expect(find.text('アイデアはまだありません'), findsOneWidget);
      expect(find.byKey(SampleKeys.pin(0)), findsNothing, reason: '長押し対象のピン');
    });
  });

  group('前 spec AC-12 ピンを通常タップ', () {
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

  group('前 spec AC-15 下部ナビをタップ', () {
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

  group('前 spec AC-13 読み上げ情報を確認し、カスタムアクションを実行', () {
    testWidgets('各ピンの題名と4操作のカスタムアクションが1つの意味ノードにまとまり、長押しは意味情報に出ない', (
      tester,
    ) async {
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

    testWidgets('カスタムアクションを実行すると同じメッセージが出て、アクションボタンは出ない', (tester) async {
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
        _expectNoActionButtons('${action.name} の実行直後');

        await tester.pumpAndSettle();

        expect(
          find.textContaining('『'),
          findsNothing,
          reason: '${action.name} のメッセージが消えている',
        );
        _expectNoActionButtons('${action.name} のメッセージが消えたあと');
      }
    });
  });
}
