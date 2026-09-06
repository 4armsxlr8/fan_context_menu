import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinterest_long_press_menu/src/pin.dart';

void main() {
  group('Pin', () {
    test('題名・色・高さを保持する', () {
      const pin = Pin(title: '夜の街並み', color: Color(0xFF3C3C3C), height: 240);

      expect(pin.title, '夜の街並み');
      expect(pin.color, const Color(0xFF3C3C3C));
      expect(pin.height, 240.0);
    });
  });

  group('PinAction', () {
    test('宣言順が画面の上側からの並び 非表示・リアクション・共有・保存 と一致する', () {
      expect(PinAction.values, <PinAction>[
        PinAction.hide,
        PinAction.reaction,
        PinAction.share,
        PinAction.save,
      ]);
    });

    test('表示名が4操作の語と一致する', () {
      expect(PinAction.hide.label, '非表示');
      expect(PinAction.reaction.label, 'リアクション');
      expect(PinAction.share.label, '共有');
      expect(PinAction.save.label, '保存');
    });

    test('読み上げ名がすべての操作で空でない', () {
      for (final action in PinAction.values) {
        expect(
          action.semanticsLabel,
          isNotEmpty,
          reason: '${action.name} の読み上げ名',
        );
      }
    });
  });
}
