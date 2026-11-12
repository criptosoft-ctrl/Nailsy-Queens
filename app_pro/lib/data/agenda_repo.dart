import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cita.dart';

/// Acceso a los datos de la agenda. Hay dos implementaciones:
/// - [SupabaseAgendaRepo]: datos reales.
/// - [DemoAgendaRepo]: datos de ejemplo, para probar la app sin backend.
abstract class AgendaRepo {
  Future<String> nombreManicurista();
  Future<List<Cita>> citasDelDia(DateTime dia);
  Future<List<Bloqueo>> bloqueosDelDia(DateTime dia);
  Future<void> cambiarEstado(String citaId, EstadoCita estado);
  Future<void> cerrarSesion();
}

DateTime _inicioDia(DateTime d) => DateTime(d.year, d.month, d.day);

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
  Future<List<Cita>> citasDelDia(DateTime dia) async {
    final desde = _inicioDia(dia);
    final hasta = desde.add(const Duration(days: 1));
    final filas = await _db
        .from('citas')
        .select('id, inicio, fin, precio_total, estado, estado_pago, clientas(nombre), servicios(nombre)')
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
  Future<void> cerrarSesion() => _db.auth.signOut();
}

/// Datos de ejemplo (los de la maqueta) para enseñar la app sin Supabase.
class DemoAgendaRepo implements AgendaRepo {
  DemoAgendaRepo({DateTime? hoy}) : _hoy = _inicioDia(hoy ?? DateTime.now());

  final DateTime _hoy;
  final Map<String, EstadoCita> _cambios = {};

  DateTime _h(int hora, [int min = 0]) => _hoy.add(Duration(hours: hora, minutes: min));

  List<Cita> get _base => [
        Cita(
          id: 'demo-1',
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
          clientaNombre: 'Lucía Pérez',
          servicioNombre: 'Nuevas acrílicas',
          inicio: _h(11),
          fin: _h(13),
          precio: 50,
          estado: EstadoCita.confirmada,
        ),
        Cita(
          id: 'demo-3',
          clientaNombre: 'Carla Sanz',
          servicioNombre: 'Semipermanente + Nail Art',
          inicio: _h(15),
          fin: _h(16, 30),
          precio: 28,
          estado: EstadoCita.confirmada,
          estadoPago: EstadoPago.pagado,
        ),
      ];

  @override
  Future<String> nombreManicurista() async => 'Eudy';

  @override
  Future<List<Cita>> citasDelDia(DateTime dia) async {
    if (_inicioDia(dia) != _hoy) return [];
    return _base.map((c) => _cambios.containsKey(c.id) ? c.copyWith(estado: _cambios[c.id]) : c).toList();
  }

  @override
  Future<List<Bloqueo>> bloqueosDelDia(DateTime dia) async {
    if (_inicioDia(dia) != _hoy) return [];
    return [Bloqueo(inicio: _h(13), fin: _h(14), motivo: 'Almuerzo')];
  }

  @override
  Future<void> cambiarEstado(String citaId, EstadoCita estado) async => _cambios[citaId] = estado;

  @override
  Future<void> cerrarSesion() async {}
}
