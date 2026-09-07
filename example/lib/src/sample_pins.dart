import 'dart:ui';

import 'pin.dart';

/// 10 dummy pins shown in the feed. Titles don't repeat, and heights are
/// varied.
const List<Pin> samplePins = <Pin>[
  Pin(title: '夜の街並み', color: Color(0xFF3B4252), height: 220),
  Pin(title: '青い海', color: Color(0xFF2F6690), height: 180),
  Pin(title: '緑の山道', color: Color(0xFF3F6244), height: 260),
  Pin(title: '朝焼けの空', color: Color(0xFFB5654A), height: 200),
  Pin(title: '雪山の稜線', color: Color(0xFF5C6B73), height: 300),
  Pin(title: '砂漠の夕暮れ', color: Color(0xFFA9744F), height: 170),
  Pin(title: '森の小道', color: Color(0xFF2E4034), height: 240),
  Pin(title: '古い街並み', color: Color(0xFF6B4A3A), height: 190),
  Pin(title: '花畑の丘', color: Color(0xFF7A5C6E), height: 280),
  Pin(title: '星空の湖畔', color: Color(0xFF1F2A44), height: 160),
];
