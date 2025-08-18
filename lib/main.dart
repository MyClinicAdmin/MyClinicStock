import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Azul de acento
  static const _seed = Color(0xFF5B9DFF);

  // Paleta de superfícies (estáveis — nada translúcido)
  static const _bg0 = Color(0xFF0B1020); // fundo base (quase preto-azulado)
  static const _bg1 = Color(0xFF0F1629); // appbar/nav/rail
  static const _bg2 = Color(0xFF111A2E); // cards/inputs
  static const _bd  = Color(0xFF1F2A44); // bordas
  static const _txt = Colors.white;      // texto principal

  ThemeData _buildTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      background: _bg0,
      surface: _bg1,
      surfaceVariant: _bg2,
      outline: _bd,
      outlineVariant: _bd,
      onSurface: _txt.withOpacity(0.92),
      onBackground: _txt.withOpacity(0.92),
      primary: _seed,
      onPrimary: Colors.white,
      secondary: const Color(0xFF9D8CFF),
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Fundo do app: gradiente escuro limpo (SEM blobs)
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,

      appBarTheme: const AppBarTheme(
        backgroundColor: _bg1,
        foregroundColor: _txt,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: _bg1,
        indicatorColor: Color(0xFF1E3A8A), // azul mais denso
        elevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: _bg1,
        indicatorColor: Color(0xFF1E3A8A),
        selectedIconTheme: IconThemeData(color: Colors.white),
        selectedLabelTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: Colors.white70),
        unselectedIconTheme: IconThemeData(color: Colors.white70),
      ),
      cardTheme: CardTheme(
        color: _bg2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _bd),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: _bg2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _bg2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _bd),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _bd),
          foregroundColor: _txt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: _bg2,
        side: BorderSide(color: _bd),
        labelStyle: TextStyle(color: Colors.white),
        shape: StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF111827),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _seed,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kwalps_st',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _buildTheme(),
      darkTheme: _buildTheme(),
      // fundo principal (gradiente escuro constante)
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_bg0, Color(0xFF0C1326), Color(0xFF131A3A)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: child,
        );
      },
      scrollBehavior: const _AppScrollBehavior(),
      home: const HomePage(),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
