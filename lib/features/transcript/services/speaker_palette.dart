/// Purpose: Give each speaker a colour that stays theirs.
/// Inputs: A speaker's colour index and the current theme.
/// Returns: Colours.
/// Side effects: None.
/// Notes: Fixed hues rather than colours pulled from the theme: a speaker's
/// colour has to survive a theme change and a light/dark switch, because it is
/// how the reader tells one voice from another across a long transcript. The
/// hues are chosen to stay apart for the common forms of colour blindness, and
/// the name is always shown as well, so colour is never the only signal.
library;

import 'package:flutter/material.dart';

/// The hues speakers are given, in the order they are handed out.
const _hues = <Color>[
  Color(0xFF1E88E5),
  Color(0xFFD81B60),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFFEF6C00),
  Color(0xFF00897B),
  Color(0xFF5E35B1),
  Color(0xFFC0CA33),
];

/// How many distinct colours there are before they repeat.
int get speakerPaletteLength => _hues.length;

/// Purpose: Pick a speaker's colour.
/// Inputs: The [index] the speaker was given, and the [brightness] in force.
/// Returns: A [Color].
/// Side effects: None.
/// Notes: Lightened on a dark background, because the mid-tone hues that read
/// well on white are muddy on near-black. The index wraps, so a recording with
/// more speakers than colours still works — the names carry the difference.
Color speakerColor(int index, Brightness brightness) {
  final base = _hues[index.abs() % _hues.length];
  if (brightness == Brightness.light) return base;
  return Color.lerp(base, Colors.white, 0.35)!;
}
