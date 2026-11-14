import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paleta de Nailsy Queens (basada en las maquetas).
class NailsyColors {
  static const rosa = Color(0xFFFF2E8A);
  static const rosaSuave = Color(0xFFF7A8CB);
  static const fondo = Color(0xFF17121A);
  static const superficie = Color(0xFF241C27);
  static const borde = Color(0xFF3A2E3E);
  static const texto = Color(0xFFF4EEF6);
  static const textoSecundario = Color(0xFFB7A9BC);
  static const verde = Color(0xFF4CD98A);
  static const ambar = Color(0xFFF5B547);
  static const rojo = Color(0xFFE5484D);
  static const gris = Color(0xFF6E6472);
}

ThemeData nailsyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NailsyColors.rosa,
    brightness: Brightness.dark,
  ).copyWith(
    primary: NailsyColors.rosa,
    onPrimary: Colors.white,
    surface: NailsyColors.fondo,
    onSurface: NailsyColors.texto,
    error: NailsyColors.rojo,
  );

  // Tipografía base de la plataforma (Roboto en Android/web, SF en iPhone) para que
  // los estilos propios hereden la familia de letra en vez de quedarse sin ella.
  final base = Typography.material2021(platform: defaultTargetPlatform).white;
  final etiquetaBoton = (base.labelLarge ?? const TextStyle()).copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NailsyColors.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: NailsyColors.fondo,
      foregroundColor: NailsyColors.texto,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NailsyColors.superficie,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NailsyColors.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NailsyColors.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NailsyColors.rosa, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NailsyColors.rosa,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: etiquetaBoton,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NailsyColors.superficie,
      indicatorColor: NailsyColors.rosa.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, color: NailsyColors.textoSecundario),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NailsyColors.rosa,
      foregroundColor: Colors.white,
    ),
  );
}
