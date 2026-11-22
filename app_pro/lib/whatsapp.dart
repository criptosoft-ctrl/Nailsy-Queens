/// Enlaces para escribir por WhatsApp a una profesional.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Verde de WhatsApp.
const verdeWhatsapp = Color(0xFF25D366);

/// Número solo con cifras y prefijo de país (por defecto España, 34).
String? numeroWhatsapp(String? telefono, {String prefijo = '34'}) {
  if (telefono == null) return null;
  var t = telefono.trim();
  final internacional = t.startsWith('+') || t.startsWith('00');
  t = t.replaceAll(RegExp(r'[^0-9]'), '');
  if (t.startsWith('00')) t = t.substring(2);
  if (t.length < 9) return null;
  // Número nacional español de 9 cifras: se le pone el prefijo.
  if (!internacional && t.length == 9) t = '$prefijo$t';
  return t;
}

/// https://wa.me/34600111222?text=…
Uri? enlaceWhatsapp(String? telefono, String mensaje) {
  final n = numeroWhatsapp(telefono);
  if (n == null) return null;
  return Uri.https('wa.me', '/$n', {'text': mensaje});
}

Future<void> abrirWhatsapp(String? telefono, String mensaje) async {
  final u = enlaceWhatsapp(telefono, mensaje);
  if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
}
