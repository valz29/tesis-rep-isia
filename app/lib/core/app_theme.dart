import 'package:flutter/material.dart';

class AppTheme {
  static const Color primario = Color(0xFF0F6B6B);
  static const Color fondo = Color(0xFFF2F6F6);
  static const Color tinta = Color(0xFF17292B);
  static const Color borde = Color(0xFFC9D6D6);
  static const Color superficie = Color(0xFFE7F2EF);

  static ThemeData light() => ThemeData(
    colorScheme: const ColorScheme.light(
      primary: primario,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD5EEEA),
      onPrimaryContainer: tinta,
      secondary: primario,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD5EEEA),
      onSecondaryContainer: tinta,
      surface: Colors.white,
      onSurface: tinta,
      surfaceContainerHighest: Color(0xFFE4EFEC),
      outline: borde,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primario,
      linearTrackColor: Color(0xFFD5EEEA),
    ),
    scaffoldBackgroundColor: fondo,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: fondo,
      foregroundColor: tinta,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: tinta,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: primario,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: primario,
        side: const BorderSide(color: primario),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: primario),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primario),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primario,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
    ),
  );

  static InputDecoration campo(
    String etiqueta, {
    IconData? icono,
    String? ayuda,
  }) => InputDecoration(
    labelText: etiqueta,
    helperText: ayuda,
    prefixIcon: icono == null ? null : Icon(icono, size: 21),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: borde),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: borde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: primario, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  );
}
