import 'package:flutter/material.dart';

/// Design tokens — single source for every color, size and duration (design/S0.png).
abstract final class C {
  static const forest = Color(0xFF1F4D3A);
  static const softGreen = Color(0xFFDCEBDF);
  static const midGreen = Color(0xFFB9D6BF);
  static const lime = Color(0xFFC8E66E);
  static const cream = Color(0xFFF6F4EE);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14201A);
  static const muted = Color(0xFF6B7570);
  static const border = Color(0xFFD9D6CC);
  static const divider = Color(0xFFE4E1D8);
  static const dividerSoft = Color(0xFFEEEBE3);
  static const skeleton = Color(0xFFECE9E1);
  static const error = Color(0xFFC4472D);
  static const errorTint = Color(0xFFFBEAE6);
  static const warning = Color(0xFFD99A2B);
  static const warningText = Color(0xFFB0741A);
  static const warningTint = Color(0xFFFBF1DD);
}

abstract final class S {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
  static const side = 20.0; // phone side margin
}

abstract final class R {
  static const field = 14.0, row = 16.0, card = 20.0, cardWide = 24.0, header = 28.0, pill = 999.0;
}

abstract final class D {
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 600);
  static const wide = 900.0; // breakpoint for the two-column (browser) layout
}

const cardShadow = [BoxShadow(color: Color(0x1A14201A), blurRadius: 32, offset: Offset(0, 12))];

/// Text styles (Plus Jakarta Sans, tabular figures so numbers don't jump).
abstract final class T {
  static const _f = 'PlusJakartaSans';
  static const _tab = [FontFeature.tabularFigures()];
  static const result = TextStyle(fontFamily: _f, fontSize: 44, fontWeight: FontWeight.w700, color: C.ink, height: 1.1, fontFeatures: _tab, letterSpacing: -1);
  static const hero = TextStyle(fontFamily: _f, fontSize: 26, fontWeight: FontWeight.w700, color: C.white, height: 1.2, letterSpacing: -0.5);
  static const title = TextStyle(fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w700, color: C.ink, height: 1.25);
  static const section = TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w600, color: C.ink, height: 1.3);
  static const label = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w500, color: C.ink, height: 1.3);
  static const value = TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500, color: C.ink, fontFeatures: _tab);
  static const body = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w400, color: C.ink, height: 1.45);
  static const small = TextStyle(fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w400, color: C.muted, height: 1.35, fontFeatures: _tab);
  static const overline = TextStyle(fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w600, color: C.muted, letterSpacing: 1.6);
  static const button = TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w600, color: C.white);
}
