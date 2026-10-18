import 'package:flutter/material.dart';

/// Accent for the n-th chapter card. Chapters in data files carry no colour,
/// so cards cycle through a fixed palette in chapter order.
Color chapterAccent(int index) => _palette[index % _palette.length];

const _palette = <Color>[
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFF16A34A),
  Color(0xFFF97316),
  Color(0xFF8B5CF6),
  Color(0xFF0F766E),
];
