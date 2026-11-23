import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/agenda_repo.dart' show ErrorNailsy;
import '../models/catalogo.dart';
import '../models/publico.dart';

/// Dirección de la clienta para una cita a domicilio.
class DireccionCita {
  const DireccionCita({required this.texto, required this.lat, required this.lng});

  final String texto;
  final double lat;
  final double lng;
}

/// Lo que necesita la app de clientas. Todo pasa por funciones seguras de la base
/// de datos: la clienta nunca ve agendas ni datos de otras personas.
abstract class ClientaRepo {
  Future<List<ResumenManicurista>> buscar(
      {String? texto,
      String? estilo,
      double? lat,
      double? lng,
      bool soloHoy = false,
      String sector = 'nails',
      bool domicilio = false,
      double? zonaKm,
      bool mejorValoradas = false});
  Future<PerfilPublico?> perfil(String id);

  /// [viajeMin]: minutos de viaje que deben quedar libres antes y después (citas a domicilio).
  Future<List<DateTime>> huecosLibres(String manicuristaId, DateTime dia, int duracionMin, {int viajeMin = 0});

  /// Si esa dirección cae dentro de su zona a domicilio, a qué distancia y cuánto cuesta ir.
  Future<ZonaComprobada?> comprobarZona(String manicuristaId, double lat, double lng);

  /// Devuelve el id de la cita creada.
  Future<String> reservar({
    required String manicuristaId,
    required Servicio servicio,
    required DateTime inicio,
    Map<String, int> anadidos = const {},
    String? notas,
    DireccionCita? domicilio,
  });
  Future<List<MiCita>> misCitas();
  Future<void> cancelar(String citaId);

  // Reseñas
  Future<List<Resena>> resenas(String manicuristaId, {int limite = 20});

  /// Valora una cita finalizada (1–5 estrellas y comentario opcional).
  Future<void> valorar(String citaId, int estrellas, {String? comentario});

  // Cuenta
  bool get conSesion;
  String? get nombreUsuaria;
  Stream<void> get cambiosSesion;
  Future<void> entrar(String email, String password);

  /// Devuelve true si ya hay sesión (si no, hay que confirmar el email).
  Future<bool> registrarse({required String nombre, required String email, required String password, String? telefono});
  Future<void> salir();

  /// Envía el email con el enlace para elegir contraseña nueva.
  Future<void> recuperarContrasena(String email);
  Future<void> cambiarContrasena(String nueva);

  /// Emite cuando la clienta llega desde el enlace de recuperación.
  Stream<void> get pideNuevaContrasena;

  String? urlFoto(String? ruta);
}

String _fecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Convierte los errores de la base de datos en mensajes para la clienta.
Never _relanzar(Object e) {
  if (e is PostgrestException) {
    const conocidos = [
      'Ese horario ya no está disponible',
      'Ese servicio ya no está disponible',
      'Este perfil no acepta reservas ahora mismo',
      'Inicia sesión para reservar',
      'No se puede cancelar esta cita',
      'Este perfil no atiende a domicilio',
      'Este perfil solo atiende a domicilio',
      'Tu dirección está fuera de su zona',
      'Escribe tu dirección',
      'No se pudo comprobar la distancia. Usa tu ubicación',
      'Inicia sesión para valorar',
      'Elige de 1 a 5 estrellas',
      'No encontramos esa cita',
      'Podrás valorar cuando la cita esté finalizada',
      'Ya valoraste esta cita',
    ];
    for (final m in conocidos) {
      if (e.message.contains(m)) throw ErrorNailsy('$m.');
    }
    if (e.code == '23P01') throw const ErrorNailsy('Ese horario ya no está disponible.');
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) throw const ErrorNailsy('Email o contraseña incorrectos.');
    if (m.contains('already registered')) throw const ErrorNailsy('Ya existe una cuenta con ese email.');
    if (m.contains('email not confirmed')) throw const ErrorNailsy('Confirma tu email antes de entrar.');
    if (m.contains('rate limit') || m.contains('security purposes')) {
      throw const ErrorNailsy('Espera un minuto antes de pedir otro email.');
    }
    throw ErrorNailsy(e.message);
  }
  throw e;
}

class SupabaseClientaRepo implements ClientaRepo {
  SupabaseClientaRepo(this._db, {this.urlRetorno});

  final SupabaseClient _db;

  /// A dónde lleva el enlace del email de confirmación (en la web, la propia app).
  final String? urlRetorno;

  @override
  Future<List<ResumenManicurista>> buscar({
    String? texto,
    String? estilo,
    double? lat,
    double? lng,
    bool soloHoy = false,
    String sector = 'nails',
    bool domicilio = false,
    double? zonaKm,
    bool mejorValoradas = false,
  }) async {
    final filas = await _db.rpc('buscar_manicuristas', params: {
      'p_texto': (texto ?? '').trim(),
      'p_estilo': estilo ?? '',
      'p_lat': lat,
      'p_lng': lng,
      'p_solo_hoy': soloHoy,
      'p_sector': sector,
      'p_domicilio': domicilio,
      'p_zona_km': zonaKm,
      'p_mejor_valoradas': mejorValoradas,
    });
    return [for (final f in filas as List) ResumenManicurista.fromMap(Map<String, dynamic>.from(f as Map))];
  }

  @override
  Future<PerfilPublico?> perfil(String id) async {
    final res = await _db.rpc('perfil_publico', params: {'p_id': id});
    if (res == null) return null;
    return PerfilPublico.fromMap(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<DateTime>> huecosLibres(String manicuristaId, DateTime dia, int duracionMin, {int viajeMin = 0}) async {
    final res = await _db.rpc('huecos_libres', params: {
      'p_manicurista': manicuristaId,
      'p_dia': _fecha(dia),
      'p_duracion': duracionMin,
      'p_viaje': viajeMin,
    });
    return [for (final h in res as List) DateTime.parse(h.toString()).toLocal()];
  }

  @override
  Future<ZonaComprobada?> comprobarZona(String manicuristaId, double lat, double lng) async {
    final res = await _db.rpc('comprobar_zona', params: {'p_id': manicuristaId, 'p_lat': lat, 'p_lng': lng});
    if (res == null) return null;
    return ZonaComprobada.fromMap(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<String> reservar({
    required String manicuristaId,
    required Servicio servicio,
    required DateTime inicio,
    Map<String, int> anadidos = const {},
    String? notas,
    DireccionCita? domicilio,
  }) async {
    try {
      final id = await _db.rpc('reservar', params: {
        'p_manicurista': manicuristaId,
        'p_servicio': servicio.id,
        'p_inicio': inicio.toUtc().toIso8601String(),
        'p_anadidos': [
          for (final e in anadidos.entries)
            if (e.value > 0) {'id': e.key, 'cantidad': e.value},
        ],
        'p_notas': notas,
        'p_domicilio': domicilio != null,
        'p_direccion': domicilio?.texto,
        'p_lat': domicilio?.lat,
        'p_lng': domicilio?.lng,
      });
      return id as String;
    } catch (e) {
      _relanzar(e);
    }
  }

  @override
  Future<List<MiCita>> misCitas() async {
    final filas = await _db.rpc('mis_citas');
    return [for (final f in filas as List) MiCita.fromMap(Map<String, dynamic>.from(f as Map))];
  }

  @override
  Future<void> cancelar(String citaId) async {
    try {
      await _db.rpc('cancelar_mi_cita', params: {'p_cita': citaId});
    } catch (e) {
      _relanzar(e);
    }
  }

  @override
  Future<List<Resena>> resenas(String manicuristaId, {int limite = 20}) async {
    final filas = await _db.rpc('resenas_publicas', params: {'p_id': manicuristaId, 'p_limite': limite});
    return [for (final f in filas as List) Resena.fromMap(Map<String, dynamic>.from(f as Map))];
  }

  @override
  Future<void> valorar(String citaId, int estrellas, {String? comentario}) async {
    try {
      await _db.rpc('valorar_cita', params: {'p_cita': citaId, 'p_estrellas': estrellas, 'p_comentario': comentario});
    } catch (e) {
      _relanzar(e);
    }
  }

  @override
  bool get conSesion => _db.auth.currentSession != null;

  @override
  String? get nombreUsuaria {
    final u = _db.auth.currentUser;
    if (u == null) return null;
    return (u.userMetadata?['nombre'] as String?) ?? u.email;
  }

  @override
  Stream<void> get cambiosSesion => _db.auth.onAuthStateChange.map((_) {});

  @override
  Future<void> entrar(String email, String password) async {
    try {
      await _db.auth.signInWithPassword(email: email.trim(), password: password);
    } catch (e) {
      _relanzar(e);
    }
  }

  @override
  Future<bool> registrarse({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    try {
      final res = await _db.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: urlRetorno,
        data: {'nombre': nombre.trim(), 'rol': 'clienta', 'telefono': (telefono ?? '').trim()},
      );
      // Si el email ya estaba registrado, Supabase no envía correo y devuelve un usuario sin identidades.
      if (res.session == null && (res.user?.identities?.isEmpty ?? false)) {
        throw const ErrorNailsy('Ya existe una cuenta con ese email. Pulsa "¿Ya tienes cuenta? Entra".');
      }
      return res.session != null;
    } on ErrorNailsy {
      rethrow;
    } catch (e) {
      _relanzar(e);
    }
  }

  @override
  Future<void> salir() => _db.auth.signOut();

  @override
  Future<void> recuperarContrasena(String email) async {
    try {
      await _db.auth.resetPasswordForEmail(email.trim(), redirectTo: urlRetorno);
    } catch (e) {
      _relanzar(e);
    }
  }

  @override
  Future<void> cambiarContrasena(String nueva) async {
    await _db.auth.updateUser(UserAttributes(password: nueva));
  }

  @override
  Stream<void> get pideNuevaContrasena =>
      _db.auth.onAuthStateChange.where((s) => s.event == AuthChangeEvent.passwordRecovery).map((_) {});

  @override
  String? urlFoto(String? ruta) =>
      (ruta == null || ruta.isEmpty) ? null : _db.storage.from('portafolio').getPublicUrl(ruta);
}

/// Datos de ejemplo para probar la app de clientas sin backend.
class DemoClientaRepo implements ClientaRepo {
  /// [conCitaPasada]: empieza con una cita ya finalizada, lista para valorar.
  DemoClientaRepo({this.conSesion = true, bool conCitaPasada = false}) {
    if (conCitaPasada) {
      final ayer = DateTime.now().subtract(const Duration(days: 1));
      final ini = DateTime(ayer.year, ayer.month, ayer.day, 10);
      _citas.add(MiCita(
        id: 'pasada',
        inicio: ini,
        fin: ini.add(const Duration(minutes: 90)),
        precio: 35,
        estado: 'completada',
        servicio: 'Manicura rusa + gel',
        manicuristaId: 'm1',
        manicurista: 'Eudy Nails',
        direccion: 'Calle Mayor de Triana 10',
        ciudad: 'Las Palmas de Gran Canaria',
      ));
    }
  }

  @override
  bool conSesion;

  final List<MiCita> _citas = [];

  final Map<String, List<Resena>> _resenas = {
    'm1': [
      Resena(
          id: 'r1',
          autor: 'Laura M.',
          estrellas: 5,
          fecha: DateTime(2026, 11, 12),
          comentario: 'Me hizo una manicura rusa preciosa y duró más de tres semanas. Súper puntual.',
          respuesta: '¡Gracias, Laura! Te espero el mes que viene.'),
      Resena(
          id: 'r2',
          autor: 'Sara P.',
          estrellas: 5,
          fecha: DateTime(2026, 11, 5),
          comentario: 'Muy cuidadosa con mis uñas quebradizas. Repetiré.'),
      Resena(
          id: 'r3',
          autor: 'Ana G.',
          estrellas: 4,
          fecha: DateTime(2026, 10, 28),
          comentario: 'Muy bonito el diseño, tardó un poco más de lo previsto.'),
    ],
  };
  int _n = 1;

  static const _perfiles = [
    PerfilPublico(
      id: 'm1',
      nombre: 'Eudy Nails',
      ciudad: 'Las Palmas de Gran Canaria',
      direccion: 'Calle Mayor de Triana 10',
      bio: 'Especialista en manicura rusa y Nail Art a mano alzada. Más de 8 años de experiencia.',
      especialidades: ['rusa', 'gel', 'nail_art'],
      servicios: [
        Servicio(id: 's1', nombre: 'Manicura rusa + gel', categoria: 'rusa', duracionMin: 90, precio: 35),
        Servicio(id: 's2', nombre: 'Semipermanente', categoria: 'semipermanente', duracionMin: 45, precio: 20),
      ],
      anadidos: [
        Anadido(id: 'a1', nombre: 'Diseño a mano alzada', duracionMin: 5, precio: 2, porUna: true),
        Anadido(id: 'a2', nombre: 'Retirada de material', duracionMin: 15, precio: 5),
      ],
      diasLaborables: [1, 2, 3, 4, 5, 6],
      domicilio: Domicilio(activo: true, radioKm: 10, importe: 5, viajeMin: 30),
      whatsapp: '600 111 222',
      valoracion: Valoracion(nota: 4.9, total: 23, reparto: {5: 20, 4: 2, 3: 1}),
    ),
    PerfilPublico(
      id: 'm2',
      nombre: 'Acrylic Studio',
      ciudad: 'Telde',
      bio: 'Uñas acrílicas y esculpidas.',
      especialidades: ['acrilico'],
      servicios: [
        Servicio(id: 's3', nombre: 'Acrílicas nuevas', categoria: 'acrilico', duracionMin: 120, precio: 45),
      ],
      diasLaborables: [2, 3, 4, 5],
    ),
    PerfilPublico(
      id: 'b1',
      nombre: 'Leo Barber',
      ciudad: 'Las Palmas de Gran Canaria',
      direccion: 'Calle Triana 45',
      bio: 'Degradados, barba con toalla caliente y diseños. Sin prisas.',
      especialidades: ['degradado', 'barba', 'disenos'],
      servicios: [
        Servicio(id: 'sb1', nombre: 'Corte degradado', categoria: 'degradado', duracionMin: 30, precio: 15),
        Servicio(id: 'sb2', nombre: 'Corte + barba', categoria: 'barba', duracionMin: 45, precio: 22),
      ],
      anadidos: [
        Anadido(id: 'ab1', nombre: 'Diseño / líneas', duracionMin: 10, precio: 4),
        Anadido(id: 'ab2', nombre: 'Cejas', duracionMin: 5, precio: 3),
      ],
      diasLaborables: [1, 2, 3, 4, 5, 6],
    ),
  ];

  /// Sector de cada perfil de ejemplo.
  static const _sectorDe = {'m1': 'nails', 'm2': 'nails', 'b1': 'barberia'};

  @override
  Future<List<ResumenManicurista>> buscar({
    String? texto,
    String? estilo,
    double? lat,
    double? lng,
    bool soloHoy = false,
    String sector = 'nails',
    bool domicilio = false,
    double? zonaKm,
    bool mejorValoradas = false,
  }) async {
    final q = (texto ?? '').trim().toLowerCase();
    final ahora = DateTime.now();
    final hoy14 = DateTime(ahora.year, ahora.month, ahora.day, 14);
    final manana10 = DateTime(ahora.year, ahora.month, ahora.day + 1, 10);
    final lista = [
      for (final p in _perfiles)
        if (_sectorDe[p.id] == sector &&
            (!domicilio || p.domicilio.activo) &&
            (q.isEmpty ||
                zonaKm != null || // demo: todas están "cerca" de la zona escrita
                p.nombre.toLowerCase().contains(q) ||
                (p.ciudad ?? '').toLowerCase().contains(q) ||
                p.especialidades.any((e) => etiquetaEstilo(e).toLowerCase().contains(q))) &&
            (estilo == null ||
                estilo.isEmpty ||
                p.especialidades.contains(estilo) ||
                p.servicios.any((s) => s.categoria == estilo)))
          ResumenManicurista(
            id: p.id,
            nombre: p.nombre,
            ciudad: p.ciudad,
            bio: p.bio,
            especialidades: p.especialidades,
            precioDesde: p.precioDesde,
            distanciaKm: lat == null ? null : (p.id == 'm2' ? 9.8 : 1.2),
            proximoHueco: p.id == 'm2' ? manana10 : hoy14,
            duracionDesde: p.servicios.isEmpty
                ? null
                : (p.servicios.toList()..sort((a, b) => a.precio.compareTo(b.precio))).first.duracionMin,
            domicilio: p.domicilio,
            valoracion: p.valoracion,
          ),
    ];
    if (mejorValoradas) {
      lista.sort((a, b) => (b.valoracion.nota ?? 0).compareTo(a.valoracion.nota ?? 0));
    }
    return soloHoy ? lista.where((m) => m.proximoHueco!.day == ahora.day).toList() : lista;
  }

  @override
  Future<PerfilPublico?> perfil(String id) async => _perfiles.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<DateTime>> huecosLibres(String manicuristaId, DateTime dia, int duracionMin, {int viajeMin = 0}) async {
    final p = await perfil(manicuristaId);
    if (p == null || !p.diasLaborables.contains(dia.weekday) || duracionMin <= 0) return [];
    final ocupadas = _citas.where((c) => c.manicuristaId == manicuristaId && c.activa).toList();
    final res = <DateTime>[];
    final apertura = DateTime(dia.year, dia.month, dia.day, 9);
    final cierre = DateTime(dia.year, dia.month, dia.day, 18);
    for (var t = apertura; !t.add(Duration(minutes: duracionMin)).isAfter(cierre); t = t.add(const Duration(minutes: 30))) {
      final ini = t.subtract(Duration(minutes: viajeMin));
      final fin = t.add(Duration(minutes: duracionMin + viajeMin));
      final libre = ocupadas.every((c) => !(c.inicio.isBefore(fin) && ini.isBefore(c.fin)));
      if (libre && t.isAfter(DateTime.now().add(const Duration(hours: 1)))) res.add(t);
    }
    return res;
  }

  @override
  Future<ZonaComprobada?> comprobarZona(String manicuristaId, double lat, double lng) async {
    final p = await perfil(manicuristaId);
    if (p == null || !p.domicilio.activo) return null;
    const km = 4.2;
    return ZonaComprobada(
      dentro: km <= p.domicilio.radioKm,
      distanciaKm: km,
      suplemento: p.domicilio.porKm ? double.parse((p.domicilio.importe * km).toStringAsFixed(2)) : p.domicilio.importe,
      radioKm: p.domicilio.radioKm,
    );
  }

  @override
  Future<String> reservar({
    required String manicuristaId,
    required Servicio servicio,
    required DateTime inicio,
    Map<String, int> anadidos = const {},
    String? notas,
    DireccionCita? domicilio,
  }) async {
    if (!conSesion) throw const ErrorNailsy('Inicia sesión para reservar.');
    final p = (await perfil(manicuristaId))!;
    final pres = Presupuesto.calcular(servicio, p.anadidos, anadidos);
    var suplemento = 0.0;
    if (domicilio != null) {
      final z = await comprobarZona(manicuristaId, domicilio.lat, domicilio.lng);
      if (z == null) throw const ErrorNailsy('Este perfil no atiende a domicilio.');
      if (!z.dentro) throw const ErrorNailsy('Tu dirección está fuera de su zona.');
      suplemento = z.suplemento;
    }
    final viaje = domicilio == null ? 0 : p.domicilio.viajeMin;
    final libres = await huecosLibres(manicuristaId, inicio, pres.duracionMin, viajeMin: viaje);
    if (!libres.contains(inicio)) throw const ErrorNailsy('Ese horario ya no está disponible.');
    final id = 'cita-${_n++}';
    _citas.add(MiCita(
      id: id,
      inicio: inicio,
      fin: inicio.add(Duration(minutes: pres.duracionMin)),
      precio: pres.precio + suplemento,
      estado: 'confirmada',
      servicio: servicio.nombre,
      manicuristaId: p.id,
      manicurista: p.nombre,
      direccion: domicilio?.texto ?? p.direccion,
      ciudad: domicilio == null ? p.ciudad : null,
      aDomicilio: domicilio != null,
      suplemento: suplemento,
    ));
    return id;
  }

  @override
  Future<List<MiCita>> misCitas() async => List.of(_citas)..sort((a, b) => b.inicio.compareTo(a.inicio));

  @override
  Future<void> cancelar(String citaId) async {
    final i = _citas.indexWhere((c) => c.id == citaId);
    if (i >= 0) _citas[i] = _citas[i].conEstado('cancelada');
  }

  @override
  Future<List<Resena>> resenas(String manicuristaId, {int limite = 20}) async =>
      (_resenas[manicuristaId] ?? const <Resena>[]).take(limite).toList();

  @override
  Future<void> valorar(String citaId, int estrellas, {String? comentario}) async {
    final i = _citas.indexWhere((c) => c.id == citaId);
    if (i < 0) throw const ErrorNailsy('No encontramos esa cita.');
    final c = _citas[i];
    if (c.estado != 'completada') throw const ErrorNailsy('Podrás valorar cuando la cita esté finalizada.');
    if (c.misEstrellas != null) throw const ErrorNailsy('Ya valoraste esta cita.');
    _citas[i] = c.conEstado(c.estado, estrellas: estrellas);
    (_resenas[c.manicuristaId] ??= []).insert(
        0,
        Resena(
            id: 'r${DateTime.now().microsecondsSinceEpoch}',
            autor: 'Clienta D.',
            estrellas: estrellas,
            fecha: DateTime.now(),
            comentario: (comentario ?? '').trim().isEmpty ? null : comentario!.trim()));
  }

  @override
  String? get nombreUsuaria => conSesion ? 'Clienta demo' : null;

  @override
  Stream<void> get cambiosSesion => const Stream.empty();

  @override
  Future<void> entrar(String email, String password) async => conSesion = true;

  @override
  Future<bool> registrarse({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    conSesion = true;
    return true;
  }

  @override
  Future<void> salir() async => conSesion = false;

  @override
  Future<void> recuperarContrasena(String email) async {}

  @override
  Future<void> cambiarContrasena(String nueva) async {}

  @override
  Stream<void> get pideNuevaContrasena => const Stream.empty();

  @override
  String? urlFoto(String? ruta) => null;
}
