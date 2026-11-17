import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const emerald = Color(0xFF10B981);
  static const sky = Color(0xFF38BDF8);
  static const gold = Color(0xFFFBBF24);
  static const charcoal = Color(0xFF1E293B);
  static const slate = Color(0xFF64748B);
}

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    colorSchemeSeed: C.emerald,
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9),
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}
