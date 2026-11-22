/// Sitúa en el mapa una zona escrita (barrio, pueblo, ciudad) con OpenStreetMap (Nominatim).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Países donde se buscan las zonas (códigos ISO separados por comas).
const paisesBusqueda = 'es';

final _cache = <String, ({double lat, double lng})?>{};

/// Coordenadas de una zona escrita, o null si no se encuentra o no hay conexión.
Future<({double lat, double lng})?> buscarLugar(String texto, {String idioma = 'es'}) async {
  final t = texto.trim();
  if (t.length < 3) return null;
  final clave = t.toLowerCase();
  if (_cache.containsKey(clave)) return _cache[clave];
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': t,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': paisesBusqueda,
      'accept-language': idioma,
    });
    final r = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final lista = jsonDecode(r.body) as List;
    if (lista.isEmpty) return _cache[clave] = null;
    final m = lista.first as Map<String, dynamic>;
    final lat = double.tryParse('${m['lat']}');
    final lng = double.tryParse('${m['lon']}');
    if (lat == null || lng == null) return null;
    return _cache[clave] = (lat: lat, lng: lng);
  } catch (_) {
    return null;
  }
}
