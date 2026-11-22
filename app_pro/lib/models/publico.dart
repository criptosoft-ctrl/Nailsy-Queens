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

/// Estilos de barbería para filtrar y para las especialidades del perfil.
const estilosBarberia = <String, String>{
  'degradado': 'Degradado',
  'clasico': 'Clásico',
  'barba': 'Barba',
  'disenos': 'Diseños',
  'ninos': 'Niños',
};

/// Nombre legible de un estilo de cualquier sector.
String etiquetaEstilo(String e) => estilosBuscables[e] ?? estilosBarberia[e] ?? e;

const zonasHorarias = <String, String>{
  'Atlantic/Canary': 'Canarias',
  'Europe/Madrid': 'Península y Baleares',
  'America/Bogota': 'Colombia',
};

List<String> _lista(Object? v) => v == null ? [] : (v as List).map((e) => e.toString()).toList();
double? _dbl(Object? v) => v == null ? null : (v as num).toDouble();

/// Cómo cobra el desplazamiento a domicilio la profesional (lo pone ella).
class Domicilio {
  const Domicilio({this.activo = false, this.radioKm = 10, this.porKm = false, this.importe = 0, this.viajeMin = 30});

  final bool activo;
  final int radioKm;

  /// true: [importe] € por km; false: [importe] € fijos por cita.
  final bool porKm;
  final double importe;
  final int viajeMin;

  bool get gratis => importe <= 0;

  factory Domicilio.fromMap(Map<String, dynamic> m, {String clave = 'atiende_domicilio'}) => Domicilio(
        activo: (m[clave] as bool?) ?? false,
        radioKm: ((m['radio_km'] as num?) ?? 10).toInt(),
        porKm: m['suplemento_tipo'] == 'km',
        importe: _dbl(m['suplemento_importe']) ?? 0,
        viajeMin: ((m['viaje_min'] as num?) ?? 30).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'atiende_domicilio': activo,
        'radio_km': radioKm,
        'suplemento_tipo': porKm ? 'km' : 'fijo',
        'suplemento_importe': importe,
        'viaje_min': viajeMin,
      };

  Domicilio copyWith({bool? activo, int? radioKm, bool? porKm, double? importe, int? viajeMin}) => Domicilio(
        activo: activo ?? this.activo,
        radioKm: radioKm ?? this.radioKm,
        porKm: porKm ?? this.porKm,
        importe: importe ?? this.importe,
        viajeMin: viajeMin ?? this.viajeMin,
      );
}

/// Resultado de comprobar si una dirección cae dentro de la zona a domicilio.
class ZonaComprobada {
  const ZonaComprobada({required this.dentro, this.distanciaKm, this.suplemento = 0, this.radioKm = 10});

  final bool dentro;
  final double? distanciaKm;
  final double suplemento;
  final int radioKm;

  factory ZonaComprobada.fromMap(Map<String, dynamic> m) => ZonaComprobada(
        dentro: (m['dentro'] as bool?) ?? false,
        distanciaKm: _dbl(m['distancia_km']),
        suplemento: _dbl(m['suplemento']) ?? 0,
        radioKm: ((m['radio_km'] as num?) ?? 10).toInt(),
      );
}

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
    this.proximoHueco,
    this.duracionDesde,
    this.domicilio = const Domicilio(),
  });

  final String id;
  final String nombre;
  final String? ciudad;

  /// Si atiende a domicilio y cuánto cobra por ir.
  final Domicilio domicilio;

  /// Primer hueco libre en los próximos 14 días (para el servicio más corto).
  final DateTime? proximoHueco;

  /// Duración (min) del servicio más barato, para "Desde 35 € · 1 h".
  final int? duracionDesde;

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
        duracionDesde: (m['duracion_desde'] as num?)?.toInt(),
        domicilio: Domicilio.fromMap(m, clave: 'a_domicilio'),
        proximoHueco: m['proximo_hueco'] == null ? null : DateTime.parse(m['proximo_hueco'] as String).toLocal(),
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
    this.atiendeLocal = true,
    this.domicilio = const Domicilio(),
    this.whatsapp,
  });

  /// Teléfono para el botón de WhatsApp (solo si ella lo quiere mostrar).
  final String? whatsapp;

  final String id;
  final String nombre;
  final String? ciudad;
  final String? direccion;
  final String? bio;
  final String? foto;
  final String? instagram;
  final List<String> especialidades;
  final bool atiendeLocal;
  final Domicilio domicilio;
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
        atiendeLocal: (m['atiende_local'] as bool?) ?? true,
        domicilio: Domicilio.fromMap(m),
        whatsapp: m['whatsapp'] as String?,
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
    this.aDomicilio = false,
    this.suplemento = 0,
  });

  final String id;
  final DateTime inicio;
  final DateTime fin;
  final double precio;
  final bool aDomicilio;
  final double suplemento;
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
        aDomicilio: aDomicilio,
        suplemento: suplemento,
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
        aDomicilio: (m['a_domicilio'] as bool?) ?? false,
        suplemento: _dbl(m['suplemento']) ?? 0,
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
    this.atiendeLocal = true,
    this.domicilio = const Domicilio(),
    this.whatsappVisible = false,
  });

  /// Si muestra el botón de WhatsApp con su teléfono.
  final bool whatsappVisible;
  final bool atiendeLocal;
  final Domicilio domicilio;
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
        atiendeLocal: (m['atiende_local'] as bool?) ?? true,
        domicilio: Domicilio.fromMap(m),
        whatsappVisible: (m['whatsapp_visible'] as bool?) ?? false,
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
        'atiende_local': atiendeLocal,
        'whatsapp_visible': whatsappVisible,
        ...domicilio.toMap(),
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
        atiendeLocal: atiendeLocal,
        domicilio: domicilio,
        whatsappVisible: whatsappVisible,
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
  const FotoPortafolio({required this.id, required this.ruta, required this.publica, this.fecha, this.citaId});

  final String id;
  final String ruta;
  final bool publica;
  final DateTime? fecha;
  final String? citaId;

  FotoPortafolio conPublica(bool v) => FotoPortafolio(id: id, ruta: ruta, publica: v, fecha: fecha, citaId: citaId);

  factory FotoPortafolio.fromMap(Map<String, dynamic> m) => FotoPortafolio(
        id: m['id'] as String,
        ruta: m['storage_path'] as String,
        publica: (m['publica'] as bool?) ?? false,
        fecha: m['creado_en'] == null ? null : DateTime.parse(m['creado_en'] as String).toLocal(),
        citaId: m['cita_id'] as String?,
      );
}

const diasSemana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
