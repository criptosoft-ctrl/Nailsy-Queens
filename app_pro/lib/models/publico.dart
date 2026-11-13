/// Modelos del lado público (buscador de manicuristas y reservas de clientas).
library;

import 'catalogo.dart';

/// Estilos por los que la clienta puede filtrar (mismos códigos que las categorías de servicio).
const estilosBuscables = <String, String>{
  'rusa': 'Manicura rusa',
  'gel': 'Gel',
  'acrilico': 'Acrílico',
  'semipermanente': 'Semipermanente',
  'pedicura': 'Pedicura',
  'nail_art': 'Nail Art',
};

const zonasHorarias = <String, String>{
  'Atlantic/Canary': 'Canarias',
  'Europe/Madrid': 'Península y Baleares',
  'America/Bogota': 'Colombia',
};

List<String> _lista(Object? v) => v == null ? [] : (v as List).map((e) => e.toString()).toList();
double? _dbl(Object? v) => v == null ? null : (v as num).toDouble();

/// Tarjeta de resultado del buscador.
class ResumenManicurista {
  const ResumenManicurista({
    required this.id,
    required this.nombre,
    this.ciudad,
    this.foto,
    this.bio,
    this.especialidades = const [],
    this.distanciaKm,
    this.precioDesde,
    this.fotos = const [],
  });

  final String id;
  final String nombre;
  final String? ciudad;

  /// Ruta en Storage de la foto de perfil.
  final String? foto;
  final String? bio;
  final List<String> especialidades;
  final double? distanciaKm;
  final double? precioDesde;

  /// Rutas en Storage de las últimas fotos del portafolio.
  final List<String> fotos;

  factory ResumenManicurista.fromMap(Map<String, dynamic> m) => ResumenManicurista(
        id: m['id'] as String,
        nombre: (m['nombre'] as String?) ?? 'Manicurista',
        ciudad: m['ciudad'] as String?,
        foto: m['foto'] as String?,
        bio: m['bio'] as String?,
        especialidades: _lista(m['especialidades']),
        distanciaKm: _dbl(m['distancia_km']),
        precioDesde: _dbl(m['precio_desde']),
        fotos: _lista(m['fotos']),
      );
}

/// Perfil completo que ve la clienta antes de reservar.
class PerfilPublico {
  const PerfilPublico({
    required this.id,
    required this.nombre,
    this.ciudad,
    this.direccion,
    this.bio,
    this.foto,
    this.instagram,
    this.especialidades = const [],
    this.servicios = const [],
    this.anadidos = const [],
    this.fotos = const [],
    this.diasLaborables = const [],
    this.horasCancelacion = 24,
  });

  final String id;
  final String nombre;
  final String? ciudad;
  final String? direccion;
  final String? bio;
  final String? foto;
  final String? instagram;
  final List<String> especialidades;
  final List<Servicio> servicios;
  final List<Anadido> anadidos;
  final List<String> fotos;

  /// 1 = lunes … 7 = domingo
  final List<int> diasLaborables;
  final int horasCancelacion;

  factory PerfilPublico.fromMap(Map<String, dynamic> m) => PerfilPublico(
        id: m['id'] as String,
        nombre: (m['nombre'] as String?) ?? 'Manicurista',
        ciudad: m['ciudad'] as String?,
        direccion: m['direccion'] as String?,
        bio: m['bio'] as String?,
        foto: m['foto'] as String?,
        instagram: m['instagram'] as String?,
        especialidades: _lista(m['especialidades']),
        servicios: [for (final s in (m['servicios'] as List? ?? [])) Servicio.fromMap(Map<String, dynamic>.from(s as Map))],
        anadidos: [for (final a in (m['anadidos'] as List? ?? [])) Anadido.fromMap(Map<String, dynamic>.from(a as Map))],
        fotos: _lista(m['fotos']),
        diasLaborables: [for (final d in (m['dias_laborables'] as List? ?? [])) (d as num).toInt()],
        horasCancelacion: ((m['horas_cancelacion'] as num?) ?? 24).toInt(),
      );

  double? get precioDesde =>
      servicios.isEmpty ? null : servicios.map((s) => s.precio).reduce((a, b) => a < b ? a : b);
}

/// Una cita vista desde la cuenta de la clienta.
class MiCita {
  const MiCita({
    required this.id,
    required this.inicio,
    required this.fin,
    required this.precio,
    required this.estado,
    required this.servicio,
    required this.manicuristaId,
    required this.manicurista,
    this.direccion,
    this.ciudad,
    this.horasCancelacion = 24,
  });

  final String id;
  final DateTime inicio;
  final DateTime fin;
  final double precio;
  final String estado;
  final String servicio;
  final String manicuristaId;
  final String manicurista;
  final String? direccion;
  final String? ciudad;
  final int horasCancelacion;

  bool get activa => estado == 'confirmada' || estado == 'pendiente';
  bool get futura => inicio.isAfter(DateTime.now());

  /// Cancelación gratuita si falta más del plazo (cuando haya pagos, si no se pierde la fianza).
  bool get cancelacionGratis => inicio.difference(DateTime.now()).inHours >= horasCancelacion;

  MiCita conEstado(String e) => MiCita(
        id: id,
        inicio: inicio,
        fin: fin,
        precio: precio,
        estado: e,
        servicio: servicio,
        manicuristaId: manicuristaId,
        manicurista: manicurista,
        direccion: direccion,
        ciudad: ciudad,
        horasCancelacion: horasCancelacion,
      );

  factory MiCita.fromMap(Map<String, dynamic> m) => MiCita(
        id: m['id'] as String,
        inicio: DateTime.parse(m['inicio'] as String).toLocal(),
        fin: DateTime.parse(m['fin'] as String).toLocal(),
        precio: (m['precio_total'] as num).toDouble(),
        estado: m['estado'] as String,
        servicio: (m['servicio'] as String?) ?? 'Servicio',
        manicuristaId: m['manicurista_id'] as String,
        manicurista: (m['manicurista'] as String?) ?? 'Manicurista',
        direccion: m['direccion'] as String?,
        ciudad: m['ciudad'] as String?,
        horasCancelacion: ((m['horas_cancelacion'] as num?) ?? 24).toInt(),
      );
}

/// Perfil público editable desde la App Pro.
class MiPerfil {
  const MiPerfil({
    required this.nombre,
    this.nombreNegocio,
    this.telefono,
    this.ciudad,
    this.direccion,
    this.bio,
    this.foto,
    this.instagram,
    this.especialidades = const [],
    this.publico = false,
    this.lat,
    this.lng,
    this.zonaHoraria = 'Atlantic/Canary',
  });

  final String nombre;
  final String? nombreNegocio;
  final String? telefono;
  final String? ciudad;
  final String? direccion;
  final String? bio;
  final String? foto;
  final String? instagram;
  final List<String> especialidades;
  final bool publico;
  final double? lat;
  final double? lng;
  final String zonaHoraria;

  factory MiPerfil.fromMap(Map<String, dynamic> m) => MiPerfil(
        nombre: (m['nombre'] as String?) ?? '',
        nombreNegocio: m['nombre_negocio'] as String?,
        telefono: m['telefono'] as String?,
        ciudad: m['ciudad'] as String?,
        direccion: m['direccion'] as String?,
        bio: m['bio'] as String?,
        foto: m['foto_url'] as String?,
        instagram: m['instagram'] as String?,
        especialidades: _lista(m['especialidades']),
        publico: (m['publico'] as bool?) ?? false,
        lat: _dbl(m['lat']),
        lng: _dbl(m['lng']),
        zonaHoraria: (m['zona_horaria'] as String?) ?? 'Atlantic/Canary',
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'nombre_negocio': nombreNegocio,
        'telefono': telefono,
        'ciudad': ciudad,
        'direccion': direccion,
        'bio': bio,
        'foto_url': foto,
        'instagram': instagram,
        'especialidades': especialidades,
        'publico': publico,
        'lat': lat,
        'lng': lng,
        'zona_horaria': zonaHoraria,
      };

  MiPerfil copyWith({String? foto, double? lat, double? lng}) => MiPerfil(
        nombre: nombre,
        nombreNegocio: nombreNegocio,
        telefono: telefono,
        ciudad: ciudad,
        direccion: direccion,
        bio: bio,
        foto: foto ?? this.foto,
        instagram: instagram,
        especialidades: especialidades,
        publico: publico,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        zonaHoraria: zonaHoraria,
      );

  /// Qué falta para que tenga sentido aparecer en el buscador.
  List<String> pendientes({required bool tieneServicios, required bool tieneHorario, required bool tieneFotos}) => [
        if ((ciudad ?? '').trim().isEmpty) 'la ciudad',
        if (!tieneServicios) 'al menos un servicio en el Tarifario',
        if (!tieneHorario) 'tu horario de trabajo',
        if (!tieneFotos) 'alguna foto en el Portafolio',
      ];
}

/// Franja de trabajo de un día de la semana (1 = lunes).
class FranjaHorario {
  const FranjaHorario({required this.dia, required this.inicioMin, required this.finMin});

  final int dia;

  /// Minutos desde las 00:00.
  final int inicioMin;
  final int finMin;

  static int _aMin(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String aTexto(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  factory FranjaHorario.fromMap(Map<String, dynamic> m) => FranjaHorario(
        dia: (m['dia_semana'] as num).toInt(),
        inicioMin: _aMin(m['hora_inicio'] as String),
        finMin: _aMin(m['hora_fin'] as String),
      );

  Map<String, dynamic> toMap() => {'dia_semana': dia, 'hora_inicio': aTexto(inicioMin), 'hora_fin': aTexto(finMin)};
}

/// Foto del portafolio.
class FotoPortafolio {
  const FotoPortafolio({required this.id, required this.ruta, required this.publica});

  final String id;
  final String ruta;
  final bool publica;

  factory FotoPortafolio.fromMap(Map<String, dynamic> m) => FotoPortafolio(
        id: m['id'] as String,
        ruta: m['storage_path'] as String,
        publica: (m['publica'] as bool?) ?? false,
      );
}

const diasSemana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
