import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n_textos.dart';

/// Idiomas de GlamGo: la app de clientes funciona en español, inglés y alemán
/// (en Canarias hay muchos turistas y residentes ingleses y alemanes).
enum Idioma {
  es('Español', 'ES'),
  en('English', 'EN'),
  de('Deutsch', 'DE');

  const Idioma(this.nombre, this.corto);

  /// Nombre del idioma en su propio idioma, para el selector.
  final String nombre;
  final String corto;

  Locale get locale => Locale(name);
}

/// Idioma en uso. Cambiarlo repinta toda la app.
final idiomaActual = ValueNotifier<Idioma>(Idioma.es);

/// Código del idioma para fechas y números ('es', 'en', 'de').
String get codigoIdioma => idiomaActual.value.name;

const _claveGuardada = 'idioma';

/// Al abrir la app: el idioma elegido antes o, si no hay, el del móvil.
Future<void> cargarIdioma() async {
  Idioma? guardado;
  try {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString(_claveGuardada);
    guardado = Idioma.values.where((i) => i.name == valor).firstOrNull;
  } catch (_) {
    // Sin almacenamiento (p. ej. en pruebas): se usa el del móvil.
  }
  idiomaActual.value = guardado ?? idiomaDelMovil();
}

Idioma idiomaDelMovil() {
  final codigo = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return Idioma.values.where((i) => i.name == codigo).firstOrNull ?? Idioma.es;
}

Future<void> elegirIdioma(Idioma idioma) async {
  idiomaActual.value = idioma;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveGuardada, idioma.name);
  } catch (_) {}
}

/// Traduce un texto escrito en español. Los huecos {x} se rellenan con [valores].
/// Si no hay traducción, se deja el texto en español.
String tr(String es, [Map<String, Object?> valores = const {}]) {
  var texto = es;
  final idioma = idiomaActual.value;
  if (idioma != Idioma.es) {
    final t = traducciones[es];
    if (t != null) texto = idioma == Idioma.en ? t.$1 : t.$2;
  }
  valores.forEach((clave, valor) => texto = texto.replaceAll('{$clave}', '${valor ?? ''}'));
  return texto;
}
