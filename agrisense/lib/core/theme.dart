import 'package:flutter/material.dart';

const background = Color(0xFF101714);
const panel = Color(0xFF19231E);
const accent = Color(0xFFA6E6A0);
const muted = Color(0xFFADBDB2);
const warning = Color(0xFFFFCA7A);

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    surface: panel,
    primary: accent,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: background,
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: panel,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xFF2C3B31)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    errorMaxLines: 4,
    filled: true,
    fillColor: background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: panel,
    indicatorColor: Color(0xFF365139),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF304035)),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
    ),
    titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(height: 1.5),
  ),
);
