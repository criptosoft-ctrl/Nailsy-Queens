import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/agenda_repo.dart' show ErrorNailsy;
import '../models/catalogo.dart';
import '../models/publico.dart';

/// Lo que necesita la app de clientas. Todo pasa por funciones seguras de la base
/// de datos: la clienta nunca ve agendas ni datos de otras personas.
abstract class ClientaRepo {
  Future<List<ResumenManicurista>> buscar({String? texto, String? estilo, double? lat, double? lng});
  Future<PerfilPublico?> perfil(String id);
  Future<List<DateTime>> huecosLibres(String manicuristaId, DateTime dia, int duracionMin);

  /// Devuelve el id de la cita creada.
  Future<String> reservar({
    required String manicuristaId,
    required Servicio servicio,
    required DateTime inicio,
    Map<String, int> anadidos = const {},
    String? notas,
  });
  Future<List<MiCita>> misCitas();
  Future<void> cancelar(String citaId);

  // Cuenta
  bool get conSesion;
  String? get nombreUsuaria;
  Stream<void> get cambiosSesion;
  Future<void> entrar(String email, String password);

  /// Devuelve true si ya hay sesión (si no, hay que confirmar el email).
  Future<bool> registrarse({required String nombre, required String email, required String password, String? telefono});
  Future<void> salir();

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
      'Esta manicurista no acepta reservas ahora mismo',
      'Inicia sesión para reservar',
      'No se puede cancelar esta cita',
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
  Future<List<ResumenManicurista>> buscar({String? texto, String? estilo, double? lat, double? lng}) async {
    final filas = await _db.rpc('buscar_manicuristas', params: {
      'p_texto': (texto ?? '').trim(),
      'p_estilo': estilo ?? '',
      'p_lat': lat,
      'p_lng': lng,
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
  Future<List<DateTime>> huecosLibres(String manicuristaId, DateTime dia, int duracionMin) async {
    final res = await _db.rpc('huecos_libres', params: {
      'p_manicurista': manicuristaId,
      'p_dia': _fecha(dia),
      'p_duracion': duracionMin,
    });
    return [for (final h in res as List) DateTime.parse(h.toString()).toLocal()];
  }

  @override
  Future<String> reservar({
    required String manicuristaId,
    required Servicio servicio,
    required DateTime inicio,
    Map<String, int> anadidos = const {},
    String? notas,
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
      return res.session != null;
    } catch (e) {
      _relanzar(e);
    }
  }

  @override
  Future<void> salir() => _db.auth.signOut();

  @override
  String? urlFoto(String? ruta) =>
      (ruta == null || ruta.isEmpty) ? null : _db.storage.from('portafolio').getPublicUrl(ruta);
}

/// Datos de ejemplo para probar la app de clientas sin backend.
class DemoClientaRepo implements ClientaRepo {
  DemoClientaRepo({this.conSesion = true});

  @override
  bool conSesion;

  final List<MiCita> _citas = [];
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
  ];

  @override
  Future<List<ResumenManicurista>> buscar({String? texto, String? estilo, double? lat, double? lng}) async {
    final q = (texto ?? '').trim().toLowerCase();
    return [
      for (final p in _perfiles)
        if ((q.isEmpty || p.nombre.toLowerCase().contains(q) || (p.ciudad ?? '').toLowerCase().contains(q)) &&
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
            distanciaKm: lat == null ? null : (p.id == 'm1' ? 1.2 : 9.8),
          ),
    ];
  }

  @override
  Future<PerfilPublico?> perfil(String id) async => _perfiles.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<DateTime>> huecosLibres(String manicuristaId, DateTime dia, int duracionMin) async {
    final p = await perfil(manicuristaId);
    if (p == null || !p.diasLaborables.contains(dia.weekday) || duracionMin <= 0) return [];
    final ocupadas = _citas.where((c) => c.manicuristaId == manicuristaId && c.activa).toList();
    final res = <DateTime>[];
    final apertura = DateTime(dia.year, dia.month, dia.day, 9);
    final cierre = DateTime(dia.year, dia.month, dia.day, 18);
    for (var t = apertura; !t.add(Duration(minutes: duracionMin)).isAfter(cierre); t = t.add(const Duration(minutes: 30))) {
      final fin = t.add(Duration(minutes: duracionMin));
      final libre = ocupadas.every((c) => !(c.inicio.isBefore(fin) && t.isBefore(c.fin)));
      if (libre && t.isAfter(DateTime.now().add(const Duration(hours: 1)))) res.add(t);
    }
    return res;
  }

  @override
  Future<String> reservar({
    required String manicuristaId,
    required Servicio servicio,
    required DateTime inicio,
    Map<String, int> anadidos = const {},
    String? notas,
  }) async {
    if (!conSesion) throw const ErrorNailsy('Inicia sesión para reservar.');
    final p = (await perfil(manicuristaId))!;
    final pres = Presupuesto.calcular(servicio, p.anadidos, anadidos);
    final libres = await huecosLibres(manicuristaId, inicio, pres.duracionMin);
    if (!libres.contains(inicio)) throw const ErrorNailsy('Ese horario ya no está disponible.');
    final id = 'cita-${_n++}';
    _citas.add(MiCita(
      id: id,
      inicio: inicio,
      fin: inicio.add(Duration(minutes: pres.duracionMin)),
      precio: pres.precio,
      estado: 'confirmada',
      servicio: servicio.nombre,
      manicuristaId: p.id,
      manicurista: p.nombre,
      direccion: p.direccion,
      ciudad: p.ciudad,
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
  String? urlFoto(String? ruta) => null;
}
