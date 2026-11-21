import 'package:flutter/material.dart';

/// Paleta de GlamGo (tomada del rediseño de Nailsy Queens).
class NailsyColors {
  static const rosa = Color(0xFFFE4F94);
  static const rosaSuave = Color(0xFFFF9CC4);
  static const rosaOscuro = Color(0xFF3A1E2F); // fondo de la cita en curso / chips rosas
  static const sobreRosa = Color(0xFF2A0A1A); // texto encima del rosa (botones)
  static const fondo = Color(0xFF171219);
  static const superficie = Color(0xFF211926);
  static const superficieAlta = Color(0xFF2B2231);
  static const borde = Color(0xFF3A2F3F);
  static const texto = Color(0xFFF6F0F7);
  static const textoSecundario = Color(0xFFB4A7B9);
  static const verde = Color(0xFF5BE08E);
  static const ambar = Color(0xFFF5BD70);
  static const rojo = Color(0xFFFF6B6B);
  static const rojoFondo = Color(0xFF3B1D24);
  static const gris = Color(0xFF6E6472);
}

const fuenteNailsy = 'PlusJakartaSans';

/// Radio de esquinas común (tarjetas, botones, campos).
const radioNailsy = 18.0;

ThemeData nailsyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NailsyColors.rosa,
    brightness: Brightness.dark,
  ).copyWith(
    primary: NailsyColors.rosa,
    onPrimary: NailsyColors.sobreRosa,
    secondary: NailsyColors.rosaSuave,
    surface: NailsyColors.fondo,
    onSurface: NailsyColors.texto,
    surfaceContainerHighest: NailsyColors.superficieAlta,
    error: NailsyColors.rojo,
  );

  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: fuenteNailsy);
  final texto = base.textTheme.apply(bodyColor: NailsyColors.texto, displayColor: NailsyColors.texto);
  final etiquetaBoton = (texto.labelLarge ?? const TextStyle())
      .copyWith(fontFamily: fuenteNailsy, fontSize: 16, fontWeight: FontWeight.w700);

  return ThemeData(
    useMaterial3: true,
    fontFamily: fuenteNailsy,
    colorScheme: scheme,
    textTheme: texto,
    scaffoldBackgroundColor: NailsyColors.fondo,
    dividerColor: NailsyColors.borde,
    appBarTheme: const AppBarTheme(
      backgroundColor: NailsyColors.fondo,
      surfaceTintColor: Colors.transparent,
      foregroundColor: NailsyColors.texto,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: fuenteNailsy, fontSize: 20, fontWeight: FontWeight.w700, color: NailsyColors.texto),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NailsyColors.superficie,
      hintStyle: const TextStyle(color: NailsyColors.textoSecundario),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radioNailsy),
        borderSide: const BorderSide(color: NailsyColors.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radioNailsy),
        borderSide: const BorderSide(color: NailsyColors.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radioNailsy),
        borderSide: const BorderSide(color: NailsyColors.rosa, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NailsyColors.rosa,
        foregroundColor: NailsyColors.sobreRosa,
        disabledBackgroundColor: NailsyColors.superficieAlta,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioNailsy)),
        textStyle: etiquetaBoton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NailsyColors.texto,
        side: const BorderSide(color: NailsyColors.borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioNailsy)),
        textStyle: etiquetaBoton.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NailsyColors.rosa,
        textStyle: etiquetaBoton.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NailsyColors.superficie,
      selectedColor: NailsyColors.rosa,
      side: const BorderSide(color: NailsyColors.borde),
      shape: const StadiumBorder(),
      // Texto claro sobre el chip oscuro y oscuro sobre el rosa al seleccionarlo.
      labelStyle: TextStyle(
        fontFamily: fuenteNailsy,
        fontWeight: FontWeight.w600,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? NailsyColors.sobreRosa : NailsyColors.texto,
        ),
      ),
      secondaryLabelStyle:
          const TextStyle(fontFamily: fuenteNailsy, fontWeight: FontWeight.w700, color: NailsyColors.sobreRosa),
      checkmarkColor: NailsyColors.sobreRosa,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1C141F),
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? NailsyColors.rosa : NailsyColors.textoSecundario),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fuenteNailsy,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? NailsyColors.rosa : NailsyColors.textoSecundario,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NailsyColors.rosa,
      foregroundColor: NailsyColors.sobreRosa,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? NailsyColors.rosa : NailsyColors.superficieAlta),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: NailsyColors.superficieAlta,
      contentTextStyle: TextStyle(fontFamily: fuenteNailsy, color: NailsyColors.texto),
    ),
  );
}
