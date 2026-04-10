// theme_controller.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Central theme controller and prebuilt ThemeData objects.
///
/// Responsibilities moved here from `main.dart`:
/// - Holds the global [themeMode] ValueNotifier used by the app root.
/// - Exposes `lightTheme` and `darkTheme` ThemeData instances so the UI
///   can be kept minimal and theme logic concentrated in one place.
class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light);

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static void toggle(bool isDark) {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Light theme (uses a ColorScheme seeded from the semantic learning color)
  static ThemeData get lightTheme {
    final seed = AppSemanticColors.light().learning;
    final lightCs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    final darkCs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: lightCs,
      scaffoldBackgroundColor: lightCs.background,
      appBarTheme: AppBarTheme(
        backgroundColor: lightCs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightCs.onSurface),
        titleTextStyle: TextStyle(
          color: lightCs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightCs.surface,
        selectedItemColor: lightCs.primary,
        unselectedItemColor: lightCs.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      // Swap: use dark primary as FAB background in light theme (per app UX)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkCs.primary,
        foregroundColor: darkCs.onPrimary,
        elevation: 6,
      ),
      extensions: [AppSemanticColors.light()],
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    final seed = AppSemanticColors.dark().learning;
    final lightCs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    final darkCs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: darkCs,
      scaffoldBackgroundColor: darkCs.background,
      appBarTheme: AppBarTheme(
        backgroundColor: darkCs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkCs.onSurface),
        titleTextStyle: TextStyle(
          color: darkCs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkCs.surface,
        selectedItemColor: darkCs.primary,
        unselectedItemColor: darkCs.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      // Swap: use light primary as FAB background in dark theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: lightCs.primary,
        foregroundColor: lightCs.onPrimary,
        elevation: 6,
      ),
      extensions: [AppSemanticColors.dark()],
    );
  }
}
