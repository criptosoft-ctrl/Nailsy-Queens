import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/agenda_repo.dart';
import '../models/cita.dart';
import '../models/clienta.dart';
import '../models/huecos.dart';
import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'ajustes_screen.dart';
import 'ficha_cita_screen.dart';
import 'nueva_cita_screen.dart';

final _hora = DateFormat('HH:mm');

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.repo, this.diaInicial, this.modoDemo = false, this.ahora});

  final AgendaRepo repo;
  final DateTime? diaInicial;
  final bool modoDemo;

  /// Hora "actual" (para pruebas); por defecto, la del reloj.
  final DateTime Function()? ahora;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late DateTime _dia;
  String _nombre = '';
  List<Cita> _citas = [];
  List<Bloqueo> _bloqueos = [];
  List<FranjaHorario> _horario = [];
  bool _cargando = true;
  String? _error;

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final d = widget.diaInicial ?? _ahora;
    _dia = DateTime(d.year, d.month, d.day);
    _cargarNombre();
    _cargar(inicial: true);
  }

  Future<void> _cargarNombre() async {
    try {
      final n = await widget.repo.nombreManicurista();
      if (mounted) setState(() => _nombre = n);
    } catch (_) {}
  }

  Future<void> _cargar({bool inicial = false}) async {
    if (!inicial) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final citas = await widget.repo.citasDelDia(_dia);
      final bloqueos = await widget.repo.bloqueosDelDia(_dia);
      final horario = await widget.repo.horario();
      if (!mounted) return;
      setState(() {
        _citas = citas;
        _bloqueos = bloqueos;
        _horario = horario;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la agenda.';
        _cargando = false;
      });
    }
  }

  void _irA(DateTime d) {
    setState(() => _dia = DateTime(d.year, d.month, d.day));
    _cargar();
  }

  Future<void> _elegirDia() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'ES'),
    );
    if (elegido != null) _irA(elegido);
  }

  Future<void> _nuevaCita({TimeOfDay? hora}) async {
    final creada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NuevaCitaScreen(repo: widget.repo, dia: _dia, horaInicial: hora)),
    );
    if (creada == true) {
      await _cargar();
      if (mounted) aviso(context, 'Cita guardada');
    }
  }

  Future<void> _abrirCita(Cita cita) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FichaCitaScreen(repo: widget.repo, cita: cita, ahora: widget.ahora)),
    );
    await _cargar();
  }

  void _abrirAjustes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AjustesScreen(repo: widget.repo, modoDemo: widget.modoDemo)),
    ).then((_) {
      _cargarNombre();
      _cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ahora = _ahora;
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final esHoy = _dia == hoy;
    final activas = _citas.where((c) => c.activa).toList();
    final previsto = activas.fold<double>(0, (s, c) => s + c.precio);
    var huecos = huecosDelDia(_dia, _horario, _citas, _bloqueos);
    if (esHoy) huecos = huecos.where((h) => h.fin.isAfter(ahora)).toList();
    final libre = huecos.fold<Duration>(Duration.zero, (s, h) => s + h.duracion);
    final fecha = DateFormat("EEEE, d 'de' MMMM", 'es').format(_dia);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              // ---- Cabecera ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${fecha[0].toUpperCase()}${fecha.substring(1)}',
                            style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(_nombre.isEmpty ? 'Hola' : 'Hola, $_nombre',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15)),
                      ],
                    ),
                  ),
                  BotonCuadrado(icono: Icons.person_outline, tooltip: 'Mi cuenta', onTap: _abrirAjustes),
                  const SizedBox(width: 8),
                  BotonCuadrado(icono: Icons.calendar_today_outlined, tooltip: 'Elegir día', onTap: _elegirDia),
                  const SizedBox(width: 8),
                  BotonCuadrado(icono: Icons.add, tooltip: 'Nueva cita', relleno: true, onTap: _nuevaCita),
                ],
              ),
              const SizedBox(height: 20),
              _TiraSemana(dia: _dia, hoy: hoy, onElegir: _irA),
              const SizedBox(height: 18),

              // ---- Resumen ----
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: NailsyColors.superficie,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: NailsyColors.borde),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _Dato(etiqueta: esHoy ? 'Previsto hoy' : 'Previsto', valor: precio(previsto))),
                      const VerticalDivider(color: NailsyColors.borde, width: 1),
                      Expanded(child: _Dato(etiqueta: 'Citas', valor: '${activas.length}')),
                      const VerticalDivider(color: NailsyColors.borde, width: 1),
                      Expanded(
                          child: _Dato(
                              etiqueta: 'Hueco libre',
                              valor: _horario.isEmpty ? '—' : (libre == Duration.zero ? '0' : duracionCorta(libre)))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const Text('Agenda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),

              if (_cargando)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                EstadoVacio(icono: Icons.wifi_off, texto: _error!)
              else if (_citas.isEmpty && _bloqueos.isEmpty && huecos.isEmpty)
                EstadoVacio(
                  icono: Icons.event_available,
                  texto: _horario.isEmpty
                      ? 'No hay citas este día.\nConfigura tu horario en Mi cuenta → Horario de trabajo.'
                      : 'No hay citas este día.',
                )
              else
                ..._lineaTiempo(huecos, ahora),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _lineaTiempo(List<Hueco> huecos, DateTime ahora) {
    final items = <({DateTime inicio, Widget w})>[
      for (final c in _citas)
        (inicio: c.inicio, w: _FilaCita(cita: c, enCurso: c.enCursoAhora(ahora), ahora: ahora, onTap: () => _abrirCita(c))),
      for (final b in _bloqueos) (inicio: b.inicio, w: _FilaBloqueo(bloqueo: b)),
      for (final h in huecos)
        (
          inicio: h.inicio,
          w: _FilaHueco(
            hueco: h,
            onCrear: () => _nuevaCita(hora: TimeOfDay(hour: h.inicio.hour, minute: h.inicio.minute)),
          )
        ),
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
    return [for (final i in items) Padding(padding: const EdgeInsets.only(bottom: 14), child: i.w)];
  }
}

// ---------------------------------------------------------------------------

class _TiraSemana extends StatelessWidget {
  const _TiraSemana({required this.dia, required this.hoy, required this.onElegir});

  final DateTime dia;
  final DateTime hoy;
  final ValueChanged<DateTime> onElegir;

  static const _letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final lunes = dia.subtract(Duration(days: dia.weekday - 1));
    return GestureDetector(
      // Deslizar para cambiar de semana
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        onElegir(dia.add(Duration(days: v < 0 ? 7 : -7)));
      },
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(builder: (context) {
                final d = DateTime(lunes.year, lunes.month, lunes.day + i);
                final sel = d == dia;
                final esHoy = d == hoy;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onElegir(d),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? context.acento : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(_letras[i],
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel ? context.sobreAcento : NailsyColors.textoSecundario)),
                        const SizedBox(height: 4),
                        Text('${d.day}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: sel ? context.sobreAcento : (esHoy ? context.acento : NailsyColors.texto))),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ColumnaHora extends StatelessWidget {
  const _ColumnaHora({required this.inicio, this.fin});

  final DateTime inicio;
  final DateTime? fin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_hora.format(inicio), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (fin != null)
              Text(_hora.format(fin!), style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de estado de una cita, con los colores del diseño.
Pildora? pildoraEstado(Cita c) {
  switch (c.estado) {
    case EstadoCita.completada:
      return c.estadoPago == EstadoPago.pagado
          ? const Pildora(texto: 'Cobrada', color: NailsyColors.verde)
          : const Pildora(texto: 'Pago pendiente', color: NailsyColors.ambar);
    case EstadoCita.confirmada:
      return c.estadoPago == EstadoPago.pagado
          ? const Pildora(texto: 'Pagada', color: NailsyColors.verde)
          : const Pildora(texto: 'Confirmada', color: NailsyColors.verde);
    case EstadoCita.pendiente:
      return const Pildora(texto: 'Pendiente', color: NailsyColors.ambar);
    case EstadoCita.noShow:
      return const Pildora(texto: 'No vino', color: NailsyColors.rojo);
    case EstadoCita.cancelada:
      return const Pildora(texto: 'Cancelada', color: NailsyColors.gris);
    case EstadoCita.enCurso:
      return null;
  }
}

String textoEnCurso(Cita c, DateTime ahora) {
  final quedan = c.fin.difference(ahora);
  if (quedan.isNegative || !ahora.isAfter(c.inicio)) return 'En curso';
  return 'En curso · quedan ${duracionCorta(Duration(minutes: quedan.inMinutes.clamp(1, 1440)))}';
}

class _FilaCita extends StatelessWidget {
  const _FilaCita({required this.cita, required this.enCurso, required this.ahora, required this.onTap});

  final Cita cita;
  final bool enCurso;
  final DateTime ahora;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final apagada = !cita.activa;
    final estado = enCurso ? null : pildoraEstado(cita);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColumnaHora(inicio: cita.inicio, fin: cita.fin),
        Expanded(
          child: Opacity(
            opacity: apagada ? 0.55 : 1,
            child: Material(
              color: enCurso ? context.acentoOscuro : NailsyColors.superficie,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: enCurso ? context.acento : NailsyColors.borde, width: enCurso ? 1.5 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cita.clientaNombre,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                decoration: apagada ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          Text(precio(cita.precio), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(cita.servicioNombre, style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 14.5)),
                      if (enCurso || estado != null || cita.alergias.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (enCurso)
                              Pildora(
                                  texto: textoEnCurso(cita, ahora),
                                  color: context.acentoSuave,
                                  fondo: context.acento.withValues(alpha: 0.16)),
                            if (estado != null) estado,
                            if (cita.alergias.isNotEmpty)
                              Pildora(
                                texto: 'Alergia ${cita.alergias.map(etiquetaAlergia).join(', ').toLowerCase()}',
                                color: NailsyColors.rojo,
                                fondo: NailsyColors.rojoFondo,
                                icono: Icons.warning_amber_rounded,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaBloqueo extends StatelessWidget {
  const _FilaBloqueo({required this.bloqueo});

  final Bloqueo bloqueo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(_hora.format(bloqueo.inicio), style: const TextStyle(color: NailsyColors.textoSecundario)),
        ),
        const Expanded(child: LineaDiscontinua()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(bloqueo.motivo ?? 'Bloqueado', style: const TextStyle(color: NailsyColors.textoSecundario)),
        ),
        const Expanded(child: LineaDiscontinua()),
      ],
    );
  }
}

class _FilaHueco extends StatelessWidget {
  const _FilaHueco({required this.hueco, required this.onCrear});

  final Hueco hueco;
  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColumnaHora(inicio: hueco.inicio, fin: hueco.fin),
        Expanded(
          child: BordeDiscontinuo(
            radio: 20,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Hueco libre · ${duracionCorta(hueco.duracion)}',
                        style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 15)),
                  ),
                  TextButton(
                    onPressed: onCrear,
                    style: TextButton.styleFrom(
                      backgroundColor: NailsyColors.superficieAlta,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Crear cita'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
