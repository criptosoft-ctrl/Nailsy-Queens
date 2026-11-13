import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogo.dart';
import '../models/cita.dart';
import '../models/clienta.dart';
import '../models/publico.dart';

/// Datos de una cita nueva.
class NuevaCita {
  const NuevaCita({
    required this.clientaId,
    required this.servicio,
    required this.inicio,
    required this.duracionMin,
    required this.precio,
    this.anadidos = const {},
    this.notas,
  });

  final String clientaId;
  final Servicio servicio;
  final DateTime inicio;
  final int duracionMin;
  final double precio;

  /// id del añadido → cantidad
  final Map<String, int> anadidos;
  final String? notas;

  DateTime get fin => inicio.add(Duration(minutes: duracionMin));
}

/// Error con un mensaje listo para enseñar a la manicurista.
class ErrorNailsy implements Exception {
  const ErrorNailsy(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Acceso a los datos. Hay dos implementaciones:
/// - [SupabaseAgendaRepo]: datos reales.
/// - [DemoAgendaRepo]: datos de ejemplo, para probar la app sin backend.
abstract class AgendaRepo {
  Future<String> nombreManicurista();
  Future<void> cerrarSesion();

  // Agenda
  Future<List<Cita>> citasDelDia(DateTime dia);
  Future<List<Bloqueo>> bloqueosDelDia(DateTime dia);
  Future<void> cambiarEstado(String citaId, EstadoCita estado);
  Future<void> crearCita(NuevaCita cita);
  Future<List<Cita>> historialClienta(String clientaId);

  // Tarifario
  Future<List<Servicio>> servicios();
  Future<void> guardarServicio(Servicio s);
  Future<void> borrarServicio(String id);
  Future<List<Anadido>> anadidos();
  Future<void> guardarAnadido(Anadido a);
  Future<void> borrarAnadido(String id);

  // Clientas
  Future<List<Clienta>> clientas();
  Future<Clienta> guardarClienta(Clienta c);
  Future<bool> tieneConsentimiento(String clientaId);
  Future<void> registrarConsentimiento(String clientaId, String metodo);
  Future<FichaUna?> ficha(String clientaId);
  Future<void> guardarFicha(FichaUna f);

  // Perfil público, horario y portafolio
  Future<MiPerfil> miPerfil();
  Future<void> guardarPerfil(MiPerfil p);
  Future<List<FranjaHorario>> horario();
  Future<void> guardarHorario(List<FranjaHorario> franjas);
  Future<List<FotoPortafolio>> fotos();

  /// Sube una foto y devuelve su ruta en Storage. Si [alPortafolio] la añade a la galería.
  Future<String> subirFoto(Uint8List bytes, {required String extension, bool alPortafolio = true});
  Future<void> cambiarVisibilidadFoto(String id, bool publica);
  Future<void> borrarFoto(FotoPortafolio f);

  /// URL pública de una foto guardada (null si no hay que cargar nada, p. ej. en modo demo).
  String? urlFoto(String? ruta);
}

DateTime _inicioDia(DateTime d) => DateTime(d.year, d.month, d.day);

const _selectCita = 'id, clienta_id, inicio, fin, precio_total, estado, estado_pago, '
    'clientas(nombre, fichas_una(alergias)), servicios(nombre)';

class SupabaseAgendaRepo implements AgendaRepo {
  SupabaseAgendaRepo(this._db);

  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  @override
  Future<String> nombreManicurista() async {
    final fila = await _db.from('manicuristas').select('nombre').eq('id', _uid).maybeSingle();
    return (fila?['nombre'] as String?) ?? '';
  }

  @override
  Future<void> cerrarSesion() => _db.auth.signOut();

  // ---------- Agenda ----------
  @override
  Future<List<Cita>> citasDelDia(DateTime dia) async {
    final desde = _inicioDia(dia);
    final hasta = desde.add(const Duration(days: 1));
    final filas = await _db
        .from('citas')
        .select(_selectCita)
        .gte('inicio', desde.toUtc().toIso8601String())
        .lt('inicio', hasta.toUtc().toIso8601String())
        .order('inicio');
    return filas.map(Cita.fromMap).toList();
  }

  @override
  Future<List<Bloqueo>> bloqueosDelDia(DateTime dia) async {
    final desde = _inicioDia(dia);
    final hasta = desde.add(const Duration(days: 1));
    final filas = await _db
        .from('bloqueos')
        .select('inicio, fin, motivo')
        .lt('inicio', hasta.toUtc().toIso8601String())
        .gt('fin', desde.toUtc().toIso8601String())
        .order('inicio');
    return filas.map(Bloqueo.fromMap).toList();
  }

  @override
  Future<void> cambiarEstado(String citaId, EstadoCita estado) async {
    await _db.from('citas').update({
      'estado': estadoCitaADb(estado),
      if (estado == EstadoCita.cancelada) 'cancelado_en': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', citaId);
  }

  @override
  Future<void> crearCita(NuevaCita c) async {
    try {
      final fila = await _db
          .from('citas')
          .insert({
            'manicurista_id': _uid,
            'clienta_id': c.clientaId,
            'servicio_id': c.servicio.id,
            'inicio': c.inicio.toUtc().toIso8601String(),
            'fin': c.fin.toUtc().toIso8601String(),
            'precio_total': c.precio,
            'estado': 'confirmada',
            if (c.notas != null && c.notas!.trim().isNotEmpty) 'notas': c.notas!.trim(),
          })
          .select('id')
          .single();
      final extras = c.anadidos.entries.where((e) => e.value > 0).toList();
      if (extras.isNotEmpty) {
        await _db.from('cita_anadidos').insert([
          for (final e in extras) {'cita_id': fila['id'], 'anadido_id': e.key, 'cantidad': e.value},
        ]);
      }
    } on PostgrestException catch (e) {
      if (e.code == '23P01') {
        throw const ErrorNailsy('Ya tienes otra cita en ese horario.');
      }
      rethrow;
    }
  }

  @override
  Future<List<Cita>> historialClienta(String clientaId) async {
    final filas =
        await _db.from('citas').select(_selectCita).eq('clienta_id', clientaId).order('inicio', ascending: false).limit(30);
    return filas.map(Cita.fromMap).toList();
  }

  // ---------- Tarifario ----------
  @override
  Future<List<Servicio>> servicios() async {
    final filas = await _db.from('servicios').select().eq('activo', true).order('orden').order('nombre');
    return filas.map(Servicio.fromMap).toList();
  }

  @override
  Future<void> guardarServicio(Servicio s) async {
    if (s.id == null) {
      await _db.from('servicios').insert({...s.toMap(), 'manicurista_id': _uid});
    } else {
      await _db.from('servicios').update(s.toMap()).eq('id', s.id!);
    }
  }

  @override
  Future<void> borrarServicio(String id) async {
    // Se desactiva en lugar de borrar, para no romper el historial de citas.
    await _db.from('servicios').update({'activo': false}).eq('id', id);
  }

  @override
  Future<List<Anadido>> anadidos() async {
    final filas = await _db.from('anadidos').select().eq('activo', true).order('nombre');
    return filas.map(Anadido.fromMap).toList();
  }

  @override
  Future<void> guardarAnadido(Anadido a) async {
    if (a.id == null) {
      await _db.from('anadidos').insert({...a.toMap(), 'manicurista_id': _uid});
    } else {
      await _db.from('anadidos').update(a.toMap()).eq('id', a.id!);
    }
  }

  @override
  Future<void> borrarAnadido(String id) async {
    await _db.from('anadidos').update({'activo': false}).eq('id', id);
  }

  // ---------- Clientas ----------
  @override
  Future<List<Clienta>> clientas() async {
    final filas = await _db.from('clientas').select('id, nombre, telefono, email, notas, fichas_una(alergias)').order('nombre');
    return filas.map(Clienta.fromMap).toList();
  }

  @override
  Future<Clienta> guardarClienta(Clienta c) async {
    if (c.id == null) {
      final fila = await _db.from('clientas').insert({...c.toMap(), 'manicurista_id': _uid}).select('id').single();
      return c.copyWith(id: fila['id'] as String);
    }
    await _db.from('clientas').update(c.toMap()).eq('id', c.id!);
    return c;
  }

  @override
  Future<bool> tieneConsentimiento(String clientaId) async {
    final filas = await _db
        .from('consentimientos')
        .select('id')
        .eq('clienta_id', clientaId)
        .eq('tipo', 'datos_salud')
        .isFilter('revocado_en', null)
        .limit(1);
    return filas.isNotEmpty;
  }

  @override
  Future<void> registrarConsentimiento(String clientaId, String metodo) async {
    await _db.from('consentimientos').insert({
      'clienta_id': clientaId,
      'tipo': 'datos_salud',
      'version_texto': versionConsentimiento,
      'metodo': metodo,
    });
  }

  @override
  Future<FichaUna?> ficha(String clientaId) async {
    final fila = await _db.from('fichas_una').select().eq('clienta_id', clientaId).maybeSingle();
    return fila == null ? null : FichaUna.fromMap(fila);
  }

  @override
  Future<void> guardarFicha(FichaUna f) async {
    try {
      await _db.from('fichas_una').upsert(f.toMap());
    } on PostgrestException catch (e) {
      if (e.message.contains('consentimiento')) {
        throw const ErrorNailsy('Falta el consentimiento de la clienta para guardar datos de salud.');
      }
      rethrow;
    }
  }

  // ---------- Perfil público, horario y portafolio ----------
  @override
  Future<MiPerfil> miPerfil() async {
    final fila = await _db.from('manicuristas').select().eq('id', _uid).single();
    return MiPerfil.fromMap(fila);
  }

  @override
  Future<void> guardarPerfil(MiPerfil p) async {
    await _db.from('manicuristas').update(p.toMap()).eq('id', _uid);
  }

  @override
  Future<List<FranjaHorario>> horario() async {
    final filas = await _db.from('horario_semanal').select('dia_semana, hora_inicio, hora_fin').order('dia_semana');
    return filas.map(FranjaHorario.fromMap).toList();
  }

  @override
  Future<void> guardarHorario(List<FranjaHorario> franjas) async {
    await _db.from('horario_semanal').delete().eq('manicurista_id', _uid);
    if (franjas.isEmpty) return;
    await _db.from('horario_semanal').insert([
      for (final f in franjas) {...f.toMap(), 'manicurista_id': _uid},
    ]);
  }

  @override
  Future<List<FotoPortafolio>> fotos() async {
    final filas = await _db
        .from('fotos')
        .select('id, storage_path, publica')
        .order('creado_en', ascending: false);
    return filas.map(FotoPortafolio.fromMap).toList();
  }

  @override
  Future<String> subirFoto(Uint8List bytes, {required String extension, bool alPortafolio = true}) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final ruta = '$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('portafolio').uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg', upsert: false),
        );
    if (alPortafolio) {
      await _db.from('fotos').insert({'manicurista_id': _uid, 'storage_path': ruta, 'publica': true});
    }
    return ruta;
  }

  @override
  Future<void> cambiarVisibilidadFoto(String id, bool publica) async {
    await _db.from('fotos').update({'publica': publica}).eq('id', id);
  }

  @override
  Future<void> borrarFoto(FotoPortafolio f) async {
    await _db.from('fotos').delete().eq('id', f.id);
    await _db.storage.from('portafolio').remove([f.ruta]);
  }

  @override
  String? urlFoto(String? ruta) =>
      (ruta == null || ruta.isEmpty) ? null : _db.storage.from('portafolio').getPublicUrl(ruta);
}

/// Datos de ejemplo (los de la maqueta) para enseñar la app sin Supabase.
class DemoAgendaRepo implements AgendaRepo {
  DemoAgendaRepo({DateTime? hoy}) : _hoy = _inicioDia(hoy ?? DateTime.now()) {
    _cargarEjemplo();
  }

  final DateTime _hoy;
  int _contador = 100;
  String _nuevoId(String p) => '$p-${_contador++}';

  final List<Servicio> _servicios = [];
  final List<Anadido> _anadidos = [];
  final List<Clienta> _clientas = [];
  final Map<String, FichaUna> _fichas = {};
  final Set<String> _consentimientos = {};
  final List<Cita> _citas = [];

  DateTime _h(int hora, [int min = 0]) => _hoy.add(Duration(hours: hora, minutes: min));

  void _cargarEjemplo() {
    _servicios.addAll(const [
      Servicio(id: 's1', nombre: 'Manicura rusa + gel', categoria: 'rusa', duracionMin: 90, precio: 35),
      Servicio(id: 's2', nombre: 'Uñas acrílicas nuevas', categoria: 'acrilico', duracionMin: 120, precio: 50),
      Servicio(id: 's3', nombre: 'Semipermanente', categoria: 'semipermanente', duracionMin: 45, precio: 20),
    ]);
    _anadidos.addAll(const [
      Anadido(id: 'a1', nombre: 'Diseño a mano alzada', duracionMin: 5, precio: 2, porUna: true),
      Anadido(id: 'a2', nombre: 'Cristales', duracionMin: 3, precio: 1, porUna: true),
      Anadido(id: 'a3', nombre: 'Retirada de material', duracionMin: 15, precio: 5),
    ]);
    _clientas.addAll(const [
      Clienta(id: 'c1', nombre: 'Marta Gómez', telefono: '600 111 222'),
      Clienta(id: 'c2', nombre: 'Lucía Pérez', telefono: '600 333 444', alergias: ['acrilatos']),
      Clienta(id: 'c3', nombre: 'Carla Sanz'),
    ]);
    _consentimientos.add('c2');
    _fichas['c2'] = const FichaUna(
      clientaId: 'c2',
      diagnosticos: ['quebradiza'],
      alergias: ['acrilatos'],
      formaDeseada: 'Almendrada',
      largoDeseado: 'Medio',
      tonosFavoritos: ['Nude rosado', 'Rojo cereza'],
    );
    _citas.addAll([
      Cita(
        id: 'demo-1',
        clientaId: 'c1',
        clientaNombre: 'Marta Gómez',
        servicioNombre: 'Manicura rusa + gel',
        inicio: _h(9),
        fin: _h(10, 30),
        precio: 35,
        estado: EstadoCita.completada,
        estadoPago: EstadoPago.pagado,
      ),
      Cita(
        id: 'demo-2',
        clientaId: 'c2',
        clientaNombre: 'Lucía Pérez',
        servicioNombre: 'Nuevas acrílicas',
        inicio: _h(11),
        fin: _h(13),
        precio: 50,
        estado: EstadoCita.confirmada,
        alergias: const ['acrilatos'],
      ),
      Cita(
        id: 'demo-3',
        clientaId: 'c3',
        clientaNombre: 'Carla Sanz',
        servicioNombre: 'Semipermanente + Nail Art',
        inicio: _h(15),
        fin: _h(16, 30),
        precio: 28,
        estado: EstadoCita.confirmada,
        estadoPago: EstadoPago.pagado,
      ),
    ]);
  }

  @override
  Future<String> nombreManicurista() async => 'Eudy';

  @override
  Future<void> cerrarSesion() async {}

  @override
  Future<List<Cita>> citasDelDia(DateTime dia) async {
    final d = _inicioDia(dia);
    return _citas.where((c) => _inicioDia(c.inicio) == d).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  @override
  Future<List<Bloqueo>> bloqueosDelDia(DateTime dia) async {
    if (_inicioDia(dia) != _hoy) return [];
    return [Bloqueo(inicio: _h(13), fin: _h(14), motivo: 'Almuerzo')];
  }

  @override
  Future<void> cambiarEstado(String citaId, EstadoCita estado) async {
    final i = _citas.indexWhere((c) => c.id == citaId);
    if (i >= 0) _citas[i] = _citas[i].copyWith(estado: estado);
  }

  @override
  Future<void> crearCita(NuevaCita n) async {
    final solapa = _citas.any((c) => c.activa && c.inicio.isBefore(n.fin) && n.inicio.isBefore(c.fin));
    if (solapa) throw const ErrorNailsy('Ya tienes otra cita en ese horario.');
    final clienta = _clientas.firstWhere((c) => c.id == n.clientaId);
    _citas.add(Cita(
      id: _nuevoId('cita'),
      clientaId: clienta.id,
      clientaNombre: clienta.nombre,
      servicioNombre: n.servicio.nombre,
      inicio: n.inicio,
      fin: n.fin,
      precio: n.precio,
      estado: EstadoCita.confirmada,
      alergias: clienta.alergias,
    ));
  }

  @override
  Future<List<Cita>> historialClienta(String clientaId) async =>
      _citas.where((c) => c.clientaId == clientaId).toList()..sort((a, b) => b.inicio.compareTo(a.inicio));

  @override
  Future<List<Servicio>> servicios() async => List.of(_servicios);

  @override
  Future<void> guardarServicio(Servicio s) async {
    final i = _servicios.indexWhere((x) => x.id == s.id);
    final nuevo = Servicio(
      id: s.id ?? _nuevoId('s'),
      nombre: s.nombre,
      categoria: s.categoria,
      duracionMin: s.duracionMin,
      precio: s.precio,
    );
    if (i >= 0) {
      _servicios[i] = nuevo;
    } else {
      _servicios.add(nuevo);
    }
  }

  @override
  Future<void> borrarServicio(String id) async => _servicios.removeWhere((s) => s.id == id);

  @override
  Future<List<Anadido>> anadidos() async => List.of(_anadidos);

  @override
  Future<void> guardarAnadido(Anadido a) async {
    final i = _anadidos.indexWhere((x) => x.id == a.id);
    final nuevo = Anadido(
      id: a.id ?? _nuevoId('a'),
      nombre: a.nombre,
      duracionMin: a.duracionMin,
      precio: a.precio,
      porUna: a.porUna,
    );
    if (i >= 0) {
      _anadidos[i] = nuevo;
    } else {
      _anadidos.add(nuevo);
    }
  }

  @override
  Future<void> borrarAnadido(String id) async => _anadidos.removeWhere((a) => a.id == id);

  @override
  Future<List<Clienta>> clientas() async =>
      List.of(_clientas)..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

  @override
  Future<Clienta> guardarClienta(Clienta c) async {
    final guardada = c.id == null ? c.copyWith(id: _nuevoId('c')) : c;
    final i = _clientas.indexWhere((x) => x.id == guardada.id);
    if (i >= 0) {
      _clientas[i] = guardada.copyWith(alergias: _clientas[i].alergias);
    } else {
      _clientas.add(guardada);
    }
    return guardada;
  }

  @override
  Future<bool> tieneConsentimiento(String clientaId) async => _consentimientos.contains(clientaId);

  @override
  Future<void> registrarConsentimiento(String clientaId, String metodo) async => _consentimientos.add(clientaId);

  @override
  Future<FichaUna?> ficha(String clientaId) async => _fichas[clientaId];

  @override
  Future<void> guardarFicha(FichaUna f) async {
    if (!_consentimientos.contains(f.clientaId)) {
      throw const ErrorNailsy('Falta el consentimiento de la clienta para guardar datos de salud.');
    }
    _fichas[f.clientaId] = f;
    final i = _clientas.indexWhere((c) => c.id == f.clientaId);
    if (i >= 0) _clientas[i] = _clientas[i].copyWith(alergias: f.alergias);
  }

  MiPerfil _perfil = const MiPerfil(
    nombre: 'Eudy',
    nombreNegocio: 'Eudy Nails',
    ciudad: 'Las Palmas de Gran Canaria',
    bio: 'Especialista en manicura rusa y Nail Art a mano alzada.',
    especialidades: ['rusa', 'gel', 'nail_art'],
  );
  List<FranjaHorario> _horario = [
    for (var d = 1; d <= 5; d++) FranjaHorario(dia: d, inicioMin: 9 * 60, finMin: 18 * 60),
  ];
  final List<FotoPortafolio> _fotos = [];

  @override
  Future<MiPerfil> miPerfil() async => _perfil;

  @override
  Future<void> guardarPerfil(MiPerfil p) async => _perfil = p;

  @override
  Future<List<FranjaHorario>> horario() async => List.of(_horario);

  @override
  Future<void> guardarHorario(List<FranjaHorario> franjas) async => _horario = List.of(franjas);

  @override
  Future<List<FotoPortafolio>> fotos() async => List.of(_fotos);

  @override
  Future<String> subirFoto(Uint8List bytes, {required String extension, bool alPortafolio = true}) async {
    final ruta = 'demo/${_contador++}.$extension';
    if (alPortafolio) _fotos.insert(0, FotoPortafolio(id: _nuevoId('f'), ruta: ruta, publica: true));
    return ruta;
  }

  @override
  Future<void> cambiarVisibilidadFoto(String id, bool publica) async {
    final i = _fotos.indexWhere((f) => f.id == id);
    if (i >= 0) _fotos[i] = FotoPortafolio(id: id, ruta: _fotos[i].ruta, publica: publica);
  }

  @override
  Future<void> borrarFoto(FotoPortafolio f) async => _fotos.removeWhere((x) => x.id == f.id);

  @override
  String? urlFoto(String? ruta) => null;
}
