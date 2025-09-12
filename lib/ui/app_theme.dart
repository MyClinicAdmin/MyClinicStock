import 'package:flutter/material.dart';

/// Azul-bebê do site
const kBabyBlue = Color(0xFF6EC1E4);   // primário
const kBabyBlueDark = Color(0xFF3498C9);
const kHeaderBlue = Color(0xFFE9F6FC); // faixas/headers clarinhas

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kBabyBlue,
        primary: kBabyBlue,
        onPrimary: Colors.white,
        secondary: kBabyBlueDark,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: const Color(0xFF0C1B2A),
        surfaceContainerHighest: const Color(0xFFF5FAFD),
        outline: const Color(0xFFDFE8EE),
        outlineVariant: const Color(0xFFE7EEF3),
      ),
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: base.colorScheme.onSurface,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: .2,
        ),
      ),

      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: base.colorScheme.outline),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FCFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.colorScheme.primary, width: 1.6),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: base.colorScheme.primary),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      iconTheme: IconThemeData(color: base.colorScheme.primary),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: kBabyBlue.withOpacity(.12),
        // ✅ Aqui é IconThemeData direto (nada de MaterialStateProperty)
        selectedIconTheme: IconThemeData(color: base.colorScheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: base.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme:
            IconThemeData(color: base.colorScheme.onSurface.withOpacity(.6)),
        unselectedLabelTextStyle:
            TextStyle(color: base.colorScheme.onSurface.withOpacity(.6)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: kBabyBlue.withOpacity(.12),
        surfaceTintColor: Colors.transparent,
        // Algumas builds aceitam MaterialStateProperty, outras preferem fixo.
        // Se der erro aí também, troca por TextStyle(...) simples.
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(
            color: base.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: MaterialStateProperty.all(
          IconThemeData(color: base.colorScheme.onSurface),
        ),
      ),

      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: base.colorScheme.outline),
        backgroundColor: const Color(0xFFF4FAFE),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),

      dividerTheme: DividerThemeData(
        color: base.colorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
