import 'package:flutter/material.dart';

/// Paleta de GlamGo (tomada del rediseño de Nailsy Queens).
class NailsyColors {
  // ---- Marca GlamGo ----
  static const oro = Color(0xFFE8B86D); // oro champán: portada, GlamGo Pro, botones generales
  static const oroSuave = Color(0xFFF3D6A4);
  static const sobreOro = Color(0xFF2A1D08); // texto encima del oro

  // ---- Acentos por sección ----
  static const rosa = Color(0xFFFE4F94); // Uñas · Nailsy Queens
  static const rosaSuave = Color(0xFFFF9CC4);
  static const rosaOscuro = Color(0xFF3A1E2F); // fondo de la cita en curso / chips rosas
  static const sobreRosa = Color(0xFF2A0A1A); // texto encima del rosa (botones)
  static const azulBarberia = Color(0xFF5B8DEF);
  static const sobreAzulBarberia = Color(0xFF0B1A33);
  static const violetaPeluqueria = Color(0xFFA47CF3);
  static const sobreVioletaPeluqueria = Color(0xFF1E1236);
  static const salviaEstetica = Color(0xFF5CC8A4);
  static const sobreSalviaEstetica = Color(0xFF0A2A20);

  // ---- Base neutra (gris carbón) ----
  static const fondo = Color(0xFF121014);
  static const superficie = Color(0xFF1E1B22);
  static const superficieAlta = Color(0xFF28242D);
  static const borde = Color(0xFF34303A);
  static const barraNavegacion = Color(0xFF17151A);
  static const texto = Color(0xFFF6F2EC);
  static const textoSecundario = Color(0xFFA7A1AB);

  // ---- Estados (iguales en toda la app) ----
  static const verde = Color(0xFF4ADE80);
  static const ambar = Color(0xFFF5B544);
  static const rojo = Color(0xFFF2545B);
  static const rojoFondo = Color(0xFF3A1A1D);
  static const gris = Color(0xFF6E6872);
}

const fuenteNailsy = 'PlusJakartaSans';

/// Radio de esquinas común (tarjetas, botones, campos).
const radioNailsy = 18.0;

/// Tema de la app. [acento] es el color de la sección (oro para GlamGo, rosa para uñas…).
ThemeData nailsyTheme({
  Color acento = NailsyColors.rosa,
  Color sobreAcento = NailsyColors.sobreRosa,
  Color acentoSuave = NailsyColors.rosaSuave,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: acento,
    brightness: Brightness.dark,
  ).copyWith(
    primary: acento,
    onPrimary: sobreAcento,
    secondary: acentoSuave,
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
        borderSide: BorderSide(color: acento, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: acento,
        foregroundColor: sobreAcento,
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
        foregroundColor: acento,
        textStyle: etiquetaBoton.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NailsyColors.superficie,
      selectedColor: acento,
      side: const BorderSide(color: NailsyColors.borde),
      shape: const StadiumBorder(),
      // Texto claro sobre el chip oscuro y oscuro sobre el acento al seleccionarlo.
      labelStyle: TextStyle(
        fontFamily: fuenteNailsy,
        fontWeight: FontWeight.w600,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? sobreAcento : NailsyColors.texto,
        ),
      ),
      secondaryLabelStyle:
          TextStyle(fontFamily: fuenteNailsy, fontWeight: FontWeight.w700, color: sobreAcento),
      checkmarkColor: sobreAcento,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NailsyColors.barraNavegacion,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? acento : NailsyColors.textoSecundario),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fuenteNailsy,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? acento : NailsyColors.textoSecundario,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: acento,
      foregroundColor: sobreAcento,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? acento : NailsyColors.superficieAlta),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: NailsyColors.superficieAlta,
      contentTextStyle: TextStyle(fontFamily: fuenteNailsy, color: NailsyColors.texto),
    ),
  );
}

/// Tema general de GlamGo (portada, cuenta, acceso de profesionales).
ThemeData temaGlamGo() =>
    nailsyTheme(acento: NailsyColors.oro, sobreAcento: NailsyColors.sobreOro, acentoSuave: NailsyColors.oroSuave);

/// Colores del acento de la sección actual (rosa en uñas, azul en barbería…), leídos del tema.
extension AcentoDeSeccion on BuildContext {
  Color get acento => Theme.of(this).colorScheme.primary;
  Color get sobreAcento => Theme.of(this).colorScheme.onPrimary;
  Color get acentoSuave => Theme.of(this).colorScheme.secondary;

  /// Fondo oscuro teñido del acento (p. ej. la cita en curso).
  Color get acentoOscuro => Color.alphaBlend(acento.withValues(alpha: 0.16), NailsyColors.superficie);
}
