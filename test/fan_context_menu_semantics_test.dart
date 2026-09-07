// 読み上げのカスタムアクションのテスト (AC-14)。

// パッケージ本体の test/ だけが使ってよい内部 Widget。
import 'package:fan_context_menu/src/long_press_menu.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fan_context_menu_test_helpers.dart';

/// 意味情報を見るときに並べるピンの枚数。
const int _pins = 3;

/// 各ピンに渡すアクションの個数。
const int _actionCount = 4;

/// 意味ノードに付いているカスタムアクションの読み上げ名。
Iterable<String?> _customActionLabels(SemanticsData data) =>
    (data.customSemanticsActionIds ?? const <int>[]).map(
      (id) => CustomSemanticsAction.getAction(id)?.label,
    );

/// [index] のピンの意味ノードで、[actionIndex] のカスタムアクションを実行する。
void _performCustomAction(WidgetTester tester, int index, int actionIndex) {
  final node = tester.getSemantics(find.byKey(pinKey(index)));
  node.owner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(
      CustomSemanticsAction(label: actionLabel(actionIndex)),
    ),
  );
}

void main() {
  group('AC-14 読み上げ情報を確認し、カスタムアクションを実行', () {
    testWidgets('各ピンにアクション数ぶんの読み上げ名があり、ピンの読み上げ名は付かず、長押しは意味情報に出ない', (
      tester,
    ) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];

      await tester.pumpWidget(
        hostApp(
          log: log,
          actionCount: _actionCount,
          pins: _pins,
          pinChildBuilder: plainPinChild,
        ),
      );
      await tester.pumpAndSettle();

      for (var index = 0; index < _pins; index++) {
        final data = tester
            .getSemantics(find.byKey(pinKey(index)))
            .getSemanticsData();

        expect(
          data.customSemanticsActionIds ?? const <int>[],
          hasLength(_actionCount),
          reason: 'index $index のピンにカスタムアクションが $_actionCount 件',
        );
        expect(
          _customActionLabels(data),
          unorderedEquals(<String>[
            for (var action = 0; action < _actionCount; action++)
              actionLabel(action),
          ]),
          reason: 'index $index のピンのカスタムアクションがアクションの読み上げ名でそろっている',
        );
        expect(
          data.label,
          isEmpty,
          reason: 'index $index のピンの読み上げ名はパッケージが付けない',
        );
        expect(
          data.hasAction(SemanticsAction.longPress),
          isFalse,
          reason: 'index $index のピンの長押しが意味情報に出ない',
        );
      }
    });

    testWidgets('カスタムアクションの実行は実行された時だけを同じ番号で通知し、暗転・複製・アクションボタン・触覚は出ない', (
      tester,
    ) async {
      setScreenSize(tester, phoneSize);
      final log = <String>[];
      final hapticRequests = recordHapticRequests();

      await tester.pumpWidget(
        hostApp(
          log: log,
          actionCount: _actionCount,
          pins: _pins,
          pinChildBuilder: plainPinChild,
        ),
      );
      await tester.pumpAndSettle();

      for (var actionIndex = 0; actionIndex < _actionCount; actionIndex++) {
        log.clear();
        _performCustomAction(tester, 0, actionIndex);
        await tester.pump();

        expect(log, <String>[
          'action:$actionIndex',
        ], reason: '${actionLabel(actionIndex)} の実行だけが同じ番号で通知される');
        expect(find.byType(DimmingLayer), findsNothing, reason: '暗転は出ない');
        expect(
          find.byType(LiftedChildView),
          findsNothing,
          reason: '浮き上がった複製は出ない',
        );
        expect(
          find.byType(ActionButtonView),
          findsNothing,
          reason: 'アクションボタンは出ない',
        );
        expect(hapticRequests, isEmpty, reason: '触覚は鳴らさない');

        await tester.pumpAndSettle();
      }
    });
  });
}
