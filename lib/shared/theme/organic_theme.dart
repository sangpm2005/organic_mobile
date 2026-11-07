import 'package:flutter/material.dart';

const paper = Color(0xFFFAF8F1);
const surface = Color(0xFFFFFEFA);
const moss = Color(0xFF436447);
const ink = Color(0xFF294735);
const muted = Color(0xFF697167);
const sage = Color(0xFFEEF2E5);
const line = Color(0xFFE9E9DF);

ThemeData organicTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'BeVietnamPro',
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: moss,
    primary: moss,
    surface: surface,
    onSurface: ink,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontFamily: 'Lora',
      fontSize: 34,
      height: 1.3,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Lora',
      fontSize: 27,
      height: 1.35,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Lora',
      fontSize: 22,
      height: 1.4,
      color: ink,
    ),
    bodyMedium: TextStyle(fontSize: 13, height: 1.55, color: ink),
    bodySmall: TextStyle(fontSize: 11, height: 1.5, color: muted),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 50),
      textStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
  ),
  dividerColor: line,
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: surface,
    indicatorColor: sage,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontFamily: 'BeVietnamPro', fontSize: 10, color: ink),
    ),
  ),
);
