import 'package:flutter/material.dart';

/// Preset swatches for the category color picker, also the fallback palette.
const categorySwatches = <String>[
  '#2E9E7A',
  '#7A6A9C',
  '#B99A3E',
  '#4A7A8C',
  '#D98A2B',
  '#8C6F52',
  '#5267A9',
  '#4D9078',
  '#D9827B',
  '#356B7A',
  '#8A5CC2',
  '#B5748B',
];

Color? colorFromHex(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

String hexFromColor(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

final _fallback = categorySwatches.map((h) => colorFromHex(h)!).toList();

/// The one place a category's color is decided. User's choice wins,
/// otherwise a stable fallback keyed by id.
Color categoryColor(int categoryId, {String? hex}) =>
    colorFromHex(hex) ?? _fallback[categoryId % _fallback.length];
