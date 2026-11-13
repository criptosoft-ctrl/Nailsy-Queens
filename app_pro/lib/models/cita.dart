enum EstadoCita { pendiente, confirmada, enCurso, completada, cancelada, noShow }

enum EstadoPago { sinPago, pagado, reembolsado, reembolsoParcial }

EstadoCita estadoCitaDesdeDb(String valor) => switch (valor) {
      'pendiente' => EstadoCita.pendiente,
      'en_curso' => EstadoCita.enCurso,
      'completada' => EstadoCita.completada,
      'cancelada' => EstadoCita.cancelada,
      'no_show' => EstadoCita.noShow,
      _ => EstadoCita.confirmada,
    };

String estadoCitaADb(EstadoCita e) => switch (e) {
      EstadoCita.pendiente => 'pendiente',
      EstadoCita.confirmada => 'confirmada',
      EstadoCita.enCurso => 'en_curso',
      EstadoCita.completada => 'completada',
      EstadoCita.cancelada => 'cancelada',
      EstadoCita.noShow => 'no_show',
    };

EstadoPago estadoPagoDesdeDb(String? valor) => switch (valor) {
      'pagado' => EstadoPago.pagado,
      'reembolsado' => EstadoPago.reembolsado,
      'reembolso_parcial' => EstadoPago.reembolsoParcial,
      _ => EstadoPago.sinPago,
    };

String etiquetaEstado(EstadoCita e) => switch (e) {
      EstadoCita.pendiente => 'Pendiente',
      EstadoCita.confirmada => 'Confirmada',
      EstadoCita.enCurso => 'En curso',
      EstadoCita.completada => 'Completada',
      EstadoCita.cancelada => 'Cancelada',
      EstadoCita.noShow => 'No vino',
    };

class Cita {
  const Cita({
    required this.id,
    this.clientaId,
    required this.clientaNombre,
    required this.servicioNombre,
    required this.inicio,
    required this.fin,
    required this.precio,
    required this.estado,
    this.estadoPago = EstadoPago.sinPago,
    this.alergias = const [],
  });

  final String id;
  final String? clientaId;
  final String clientaNombre;
  final String servicioNombre;
  final DateTime inicio;
  final DateTime fin;
  final double precio;
  final EstadoCita estado;
  final EstadoPago estadoPago;

  /// Alergias de la clienta (de su ficha), para avisar en la agenda.
  final List<String> alergias;

  bool get activa => estado != EstadoCita.cancelada && estado != EstadoCita.noShow;

  Cita copyWith({EstadoCita? estado}) => Cita(
        id: id,
        clientaId: clientaId,
        clientaNombre: clientaNombre,
        servicioNombre: servicioNombre,
        inicio: inicio,
        fin: fin,
        precio: precio,
        estado: estado ?? this.estado,
        estadoPago: estadoPago,
        alergias: alergias,
      );

  /// Construye una cita a partir de una fila de Supabase:
  /// `select('id, clienta_id, inicio, fin, precio_total, estado, estado_pago,
  ///          clientas(nombre, fichas_una(alergias)), servicios(nombre)')`
  factory Cita.fromMap(Map<String, dynamic> m) {
    final clienta = m['clientas'] as Map<String, dynamic>?;
    final servicio = m['servicios'] as Map<String, dynamic>?;
    final ficha = clienta?['fichas_una'];
    Object? alergias;
    if (ficha is Map) alergias = ficha['alergias'];
    if (ficha is List && ficha.isNotEmpty) alergias = (ficha.first as Map)['alergias'];
    return Cita(
      id: m['id'] as String,
      clientaId: m['clienta_id'] as String?,
      alergias: alergias == null ? const [] : (alergias as List).map((e) => e.toString()).toList(),
      clientaNombre: (clienta?['nombre'] as String?) ?? 'Clienta',
      servicioNombre: (servicio?['nombre'] as String?) ?? 'Servicio',
      inicio: DateTime.parse(m['inicio'] as String).toLocal(),
      fin: DateTime.parse(m['fin'] as String).toLocal(),
      precio: (m['precio_total'] as num).toDouble(),
      estado: estadoCitaDesdeDb(m['estado'] as String),
      estadoPago: estadoPagoDesdeDb(m['estado_pago'] as String?),
    );
  }
}

class Bloqueo {
  const Bloqueo({required this.inicio, required this.fin, this.motivo});

  final DateTime inicio;
  final DateTime fin;
  final String? motivo;

  factory Bloqueo.fromMap(Map<String, dynamic> m) => Bloqueo(
        inicio: DateTime.parse(m['inicio'] as String).toLocal(),
        fin: DateTime.parse(m['fin'] as String).toLocal(),
        motivo: m['motivo'] as String?,
      );
}

/// Resumen que se muestra en la cabecera de la agenda.
class ResumenDia {
  const ResumenDia({required this.ingresos, required this.hechas, required this.total});

  final double ingresos;
  final int hechas;
  final int total;

  factory ResumenDia.de(List<Cita> citas) {
    final activas = citas.where((c) => c.activa).toList();
    return ResumenDia(
      ingresos: activas.fold(0, (s, c) => s + c.precio),
      hechas: activas.where((c) => c.estado == EstadoCita.completada).length,
      total: activas.length,
    );
  }
}
