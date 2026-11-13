import 'package:geolocator/geolocator.dart';

import 'data/agenda_repo.dart' show ErrorNailsy;

/// Pide la ubicación actual del móvil o del navegador.
Future<({double lat, double lng})> ubicacionActual() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const ErrorNailsy('Activa la ubicación del móvil para buscar cerca de ti.');
  }
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
    throw const ErrorNailsy('Sin permiso de ubicación. Puedes buscar escribiendo tu ciudad o zona.');
  }
  final p = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
  );
  return (lat: p.latitude, lng: p.longitude);
}
