import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildTheme() {
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(R.field), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: C.cream,
    colorScheme: ColorScheme.fromSeed(seedColor: C.forest, primary: C.forest, surface: C.cream, error: C.error),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.forest),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: 16),
      hintStyle: T.value.copyWith(color: C.muted.withValues(alpha: .7), fontWeight: FontWeight.w400, fontFeatures: const []),
      enabledBorder: border(C.border),
      focusedBorder: border(C.forest, 2),
      errorBorder: border(C.error, 1.5),
      focusedErrorBorder: border(C.error, 2),
      disabledBorder: border(C.divider),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: C.border,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.header))),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.forest),
  );
}
