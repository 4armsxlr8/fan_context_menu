import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 公開入口。利用側と example はこれだけを import する。
import 'package:fan_context_menu/fan_context_menu.dart';
// パッケージ本体の test/ だけが使ってよい内部 Widget (暗転層・浮き上がった複製の枠)。
import 'package:fan_context_menu/src/long_press_menu.dart';

/// 実機に近いスマートフォン縦向き。
const Size _phoneSize = Size(390, 844);

/// テストの画面サイズを固定し、終了時に元へ戻す。
void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// 読み上げ名だけが違う [count] 個のアクション。
List<FanContextMenuAction> _actions(int count) {
  return List<FanContextMenuAction>.generate(
    count,
    (index) => FanContextMenuAction(
      icon: const Icon(Icons.circle),
      semanticLabel: _actionLabel(index),
    ),
  );
}

/// [_actions] が index 番目に付ける読み上げ名。
String _actionLabel(int index) => 'アクション ${index + 1}';

/// 読み上げ名を [semanticLabels] にしたアクション一覧。
List<FanContextMenuAction> _actionsNamed(List<String> semanticLabels) {
  return semanticLabels
      .map(
        (semanticLabel) => FanContextMenuAction(
          icon: const Icon(Icons.circle),
          semanticLabel: semanticLabel,
        ),
      )
      .toList();
}

/// ホストに包まれた 1 個のピンだけの画面。
Widget _hostWithTarget({
  required List<FanContextMenuAction> actions,
  FanContextMenuStyle style = const FanContextMenuStyle(),
}) {
  return MaterialApp(
    home: FanContextMenuHost(
      style: style,
      child: Scaffold(
        body: Center(
          child: FanContextMenuTarget(
            actions: actions,
            onAction: (_) {},
            child: const Text('ピン'),
          ),
        ),
      ),
    ),
  );
}

/// 個数が不正なアクション一覧 (2〜5 個の外側)。
const Map<String, int> _rejectedActionCounts = <String, int>{
  'アクションが 0 個': 0,
  'アクションが 1 個': 1,
  'アクションが 6 個': 6,
};

/// 空白だけの読み上げ名。
const Map<String, String> _blankSemanticLabels = <String, String>{
  '読み上げ名が空文字': '',
  '読み上げ名が半角スペースだけ': ' ',
  '読み上げ名が全角スペースだけ': '　',
  '読み上げ名が改行だけ': '\n',
  '読み上げ名がタブだけ': '\t',
};

/// ホストの構築で拒否される Style。
const Map<String, FanContextMenuStyle>
_rejectedStyles = <String, FanContextMenuStyle>{
  // 時間: 非正 (Duration.zero が境界、負はその外側)。
  'longPressDuration が Duration.zero': FanContextMenuStyle(
    longPressDuration: Duration.zero,
  ),
  'openDuration が Duration.zero': FanContextMenuStyle(
    openDuration: Duration.zero,
  ),
  'highlightDuration が Duration.zero': FanContextMenuStyle(
    highlightDuration: Duration.zero,
  ),
  'longPressDuration が負': FanContextMenuStyle(
    longPressDuration: Duration(milliseconds: -1),
  ),
  // 暗転の濃さ: 0〜1 の外側。
  'dimmingOpacity が -0.1': FanContextMenuStyle(dimmingOpacity: -0.1),
  'dimmingOpacity が 1.1': FanContextMenuStyle(dimmingOpacity: 1.1),
  // 寸法・倍率: 非正 (0・負) と非有限 (NaN・Infinity)。
  'buttonDiameter が 0': FanContextMenuStyle(buttonDiameter: 0),
  'buttonDiameter が負': FanContextMenuStyle(buttonDiameter: -1),
  'buttonDiameter が NaN': FanContextMenuStyle(buttonDiameter: double.nan),
  'buttonDiameter が Infinity': FanContextMenuStyle(
    buttonDiameter: double.infinity,
  ),
  'arcRadius が 0': FanContextMenuStyle(arcRadius: 0),
  'arcRadius が NaN': FanContextMenuStyle(arcRadius: double.nan),
  'liftScale が 0': FanContextMenuStyle(liftScale: 0),
  'liftScale が Infinity': FanContextMenuStyle(liftScale: double.infinity),
  'highlightScale が負': FanContextMenuStyle(highlightScale: -1),
  'highlightScale が NaN': FanContextMenuStyle(highlightScale: double.nan),
  'actionButtonEnterScale が 0': FanContextMenuStyle(actionButtonEnterScale: 0),
  'actionButtonEnterScale が Infinity': FanContextMenuStyle(
    actionButtonEnterScale: double.infinity,
  ),
  // 広がり角: 0 以下・360 超・NaN。
  'sweepDegrees が 0': FanContextMenuStyle(sweepDegrees: 0),
  'sweepDegrees が 361': FanContextMenuStyle(sweepDegrees: 361),
  'sweepDegrees が NaN': FanContextMenuStyle(sweepDegrees: double.nan),
};

/// ホストの構築で拒否される角度の Style (負は可、非有限だけ拒否)。
const Map<String, FanContextMenuStyle> _rejectedAngleStyles =
    <String, FanContextMenuStyle>{
      'tiltDegrees が NaN': FanContextMenuStyle(tiltDegrees: double.nan),
      'tiltDegrees が Infinity': FanContextMenuStyle(
        tiltDegrees: double.infinity,
      ),
      'arcLiftDegrees が NaN': FanContextMenuStyle(arcLiftDegrees: double.nan),
      'arcLiftDegrees が Infinity': FanContextMenuStyle(
        arcLiftDegrees: double.infinity,
      ),
    };

/// 受け入れられる境界値の Style。
const Map<String, FanContextMenuStyle> _acceptedBoundaryStyles =
    <String, FanContextMenuStyle>{
      'dimmingOpacity が 0': FanContextMenuStyle(dimmingOpacity: 0),
      'dimmingOpacity が 1': FanContextMenuStyle(dimmingOpacity: 1),
      'sweepDegrees が 360': FanContextMenuStyle(sweepDegrees: 360),
    };

void main() {
  group('AC-2 公開ホスト + ピン用 Widget で 4 アクションを初期表示', () {
    testWidgets('暗転もアクションボタンも無く、child がそのまま見える', (tester) async {
      _setScreenSize(tester, _phoneSize);

      await tester.pumpWidget(_hostWithTarget(actions: _actions(4)));
      await tester.pumpAndSettle();

      expect(find.byType(DimmingLayer), findsNothing, reason: '暗転していない');
      expect(find.byType(LiftedChildView), findsNothing, reason: '浮き上がった複製が無い');
      for (var index = 0; index < 4; index++) {
        expect(
          find.bySemanticsLabel(_actionLabel(index)),
          findsNothing,
          reason: '${_actionLabel(index)} のアクションボタンが無い',
        );
      }
      expect(find.text('ピン'), findsOneWidget, reason: 'child が 1 つだけ見える');
    });
  });

  group('AC-9 アクション個数の境界値は受理される', () {
    for (final count in <int>[2, 5]) {
      testWidgets('$count 個のアクションで ArgumentError にならず構築・表示できる', (tester) async {
        _setScreenSize(tester, _phoneSize);

        await tester.pumpWidget(_hostWithTarget(actions: _actions(count)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: '構築で例外が出ない');
        expect(find.text('ピン'), findsOneWidget, reason: 'child が見える');
      });
    }
  });

  group('AC-11 ホスト無しでピン用 Widget を置く', () {
    testWidgets('デバッグ時に FlutterError で知らせる', (tester) async {
      _setScreenSize(tester, _phoneSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FanContextMenuTarget(
                actions: _actions(4),
                onAction: (_) {},
                child: const Text('ピン'),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isFlutterError);
    });
  });

  group('AC-16 不正なアクション一覧は ArgumentError で拒否される', () {
    _rejectedActionCounts.forEach((description, count) {
      test('$description は ArgumentError', () {
        expect(
          () => FanContextMenuTarget(
            actions: _actions(count),
            onAction: (_) {},
            child: const Text('ピン'),
          ),
          throwsArgumentError,
        );
      });
    });

    _blankSemanticLabels.forEach((description, label) {
      test('$description は ArgumentError', () {
        // 先頭ではなく 2 個目に置き、先頭だけ見る実装を落とす。
        final actions = <FanContextMenuAction>[
          FanContextMenuAction(
            icon: const Icon(Icons.circle),
            semanticLabel: _actionLabel(0),
          ),
          FanContextMenuAction(
            icon: const Icon(Icons.circle),
            semanticLabel: label,
          ),
        ];
        expect(
          () => FanContextMenuTarget(
            actions: actions,
            onAction: (_) {},
            child: const Text('ピン'),
          ),
          throwsArgumentError,
        );
      });
    });
  });

  group('AC-21 読み上げ名が重複するアクション一覧は ArgumentError で拒否される', () {
    test('読み上げ名が重複するアクションは ArgumentError', () {
      expect(
        () => FanContextMenuTarget(
          actions: _actionsNamed(<String>['共有', '共有', '保存']),
          onAction: (_) {},
          child: const Text('ピン'),
        ),
        throwsArgumentError,
      );
    });

    test('読み上げ名がすべて異なるアクションは ArgumentError にならない', () {
      expect(
        () => FanContextMenuTarget(
          actions: _actionsNamed(<String>['リアクション', '共有', '保存']),
          onAction: (_) {},
          child: const Text('ピン'),
        ),
        returnsNormally,
      );
    });
  });

  group('AC-16 不正な Style は ArgumentError で拒否される', () {
    _rejectedStyles.forEach((description, style) {
      test('$description は ArgumentError', () {
        expect(
          () => FanContextMenuHost(style: style, child: const Text('ピン')),
          throwsArgumentError,
        );
      });
    });

    group('非有限の角度', () {
      _rejectedAngleStyles.forEach((description, style) {
        test('$description は ArgumentError', () {
          expect(
            () => FanContextMenuHost(style: style, child: const Text('ピン')),
            throwsArgumentError,
          );
        });
      });
    });
  });

  group('AC-16 Style の境界値は受け入れる', () {
    _acceptedBoundaryStyles.forEach((description, style) {
      test('$description は ArgumentError にならない', () {
        expect(
          () => FanContextMenuHost(style: style, child: const Text('ピン')),
          returnsNormally,
        );
      });
    });
  });

  group('AC-15 省略時の Style は現サンプルの値', () {
    test('16 個の基準値すべてが現サンプルの値になる', () {
      const style = FanContextMenuStyle();

      expect(style.longPressDuration, const Duration(milliseconds: 500));
      expect(style.openDuration, const Duration(milliseconds: 180));
      expect(style.highlightDuration, const Duration(milliseconds: 120));
      expect(style.dimmingOpacity, 0.6);
      expect(style.liftScale, 1.08);
      expect(style.tiltDegrees, -3.0);
      expect(style.buttonDiameter, 48.0);
      expect(style.highlightScale, 1.35);
      expect(style.actionButtonEnterScale, 0.6);
      expect(style.arcRadius, 66.0);
      expect(style.sweepDegrees, 180.0);
      expect(style.arcLiftDegrees, 40.0);
      expect(style.actionButtonColor, const Color(0xFF3C3C3C));
      expect(style.highlightedActionButtonColor, const Color(0xFFFFFFFF));
      expect(style.iconColor, const Color(0xFFFFFFFF));
      expect(style.highlightedIconColor, const Color(0xFF000000));
    });
  });

  group('アクション一覧の防御的コピー', () {
    test('渡した一覧を後から変更してもピン用 Widget のアクションは変わらない', () {
      final actions = _actions(2);
      final target = FanContextMenuTarget(
        actions: actions,
        onAction: (_) {},
        child: const Text('ピン'),
      );

      actions.add(
        FanContextMenuAction(
          icon: const Icon(Icons.circle),
          semanticLabel: _actionLabel(2),
        ),
      );
      expect(target.actions.length, 2, reason: '追加は伝わらない');

      actions.clear();
      expect(
        target.actions.map((action) => action.semanticLabel).toList(),
        <String>[_actionLabel(0), _actionLabel(1)],
        reason: '削除も伝わらない',
      );
    });
  });
}
