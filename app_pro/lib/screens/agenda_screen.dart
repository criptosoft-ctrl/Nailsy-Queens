import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/agenda_repo.dart';
import '../models/cita.dart';
import '../models/clienta.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'clienta_detalle_screen.dart';
import 'nueva_cita_screen.dart';

final _hora = DateFormat('HH:mm');
final _euros = NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0);

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.repo, this.diaInicial});

  final AgendaRepo repo;
  final DateTime? diaInicial;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late DateTime _dia;
  String _nombre = '';
  List<Cita> _citas = [];
  List<Bloqueo> _bloqueos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.diaInicial ?? DateTime.now();
    _dia = DateTime(d.year, d.month, d.day);
    _cargarNombre();
    _cargar(inicial: true);
  }

  Future<void> _cargarNombre() async {
    try {
      final n = await widget.repo.nombreManicurista();
      if (mounted) setState(() => _nombre = n);
    } catch (_) {
      // El saludo es opcional: si falla, se muestra "Hola".
    }
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
      if (!mounted) return;
      setState(() {
        _citas = citas;
        _bloqueos = bloqueos;
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

  Future<void> _nuevaCita() async {
    final creada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NuevaCitaScreen(repo: widget.repo, dia: _dia)),
    );
    if (creada == true) {
      await _cargar();
      if (mounted) aviso(context, 'Cita guardada');
    }
  }

  void _moverDia(int dias) {
    setState(() => _dia = _dia.add(Duration(days: dias)));
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
    if (elegido != null) {
      setState(() => _dia = elegido);
      _cargar();
    }
  }

  Future<void> _accionesCita(Cita cita) async {
    final nuevo = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(cita.clientaNombre, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${cita.servicioNombre} · ${_euros.format(cita.precio)}'),
            ),
            if (cita.alergias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AvisoAlergia(alergias: cita.alergias.map(etiquetaAlergia).toList()),
              ),
            const Divider(height: 1),
            if (cita.clientaId != null)
              ListTile(
                leading: const Icon(Icons.badge_outlined, color: NailsyColors.rosaSuave),
                title: const Text('Ver ficha de la clienta'),
                onTap: () => Navigator.pop(ctx, 'ficha'),
              ),
            for (final e in [EstadoCita.enCurso, EstadoCita.completada, EstadoCita.noShow, EstadoCita.cancelada])
              if (e != cita.estado)
                ListTile(
                  leading: Icon(_iconoEstado(e), color: _colorEstado(e)),
                  title: Text(_textoAccion(e)),
                  onTap: () => Navigator.pop(ctx, e),
                ),
          ],
        ),
      ),
    );
    if (nuevo == null || !mounted) return;
    if (nuevo == 'ficha') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientaDetalleScreen(
            repo: widget.repo,
            clienta: Clienta(id: cita.clientaId, nombre: cita.clientaNombre, alergias: cita.alergias),
          ),
        ),
      );
      await _cargar();
      return;
    }
    if (nuevo is! EstadoCita) return;
    try {
      await widget.repo.cambiarEstado(cita.id, nuevo);
      await _cargar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo actualizar la cita.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final esHoy = _dia.year == hoy.year && _dia.month == hoy.month && _dia.day == hoy.day;
    final resumen = ResumenDia.de(_citas);
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(_dia);
    final titulo = esHoy ? 'Hoy, $fecha' : '${fecha[0].toUpperCase()}${fecha.substring(1)}';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(
          _nombre.isEmpty ? 'Hola' : 'Hola, $_nombre',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Elegir día',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _elegirDia,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            _TarjetaResumen(resumen: resumen, esHoy: esHoy),
            const SizedBox(height: 18),
            Row(
              children: [
                IconButton(
                  tooltip: 'Día anterior',
                  onPressed: () => _moverDia(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Día siguiente',
                  onPressed: () => _moverDia(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _Vacio(texto: _error!, icono: Icons.wifi_off)
            else if (_citas.isEmpty && _bloqueos.isEmpty)
              const _Vacio(texto: 'No hay citas este día', icono: Icons.event_available)
            else
              ..._lineaTiempo(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-agenda',
        tooltip: 'Nueva cita',
        onPressed: _nuevaCita,
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _lineaTiempo() {
    final items = <({DateTime inicio, Widget widget})>[
      for (final c in _citas) (inicio: c.inicio, widget: _FilaCita(cita: c, onTap: () => _accionesCita(c))),
      for (final b in _bloqueos) (inicio: b.inicio, widget: _FilaBloqueo(bloqueo: b)),
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
    return [
      for (final i in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: i.widget),
    ];
  }
}

IconData _iconoEstado(EstadoCita e) => switch (e) {
      EstadoCita.enCurso => Icons.play_circle_outline,
      EstadoCita.completada => Icons.check_circle_outline,
      EstadoCita.noShow => Icons.person_off_outlined,
      EstadoCita.cancelada => Icons.cancel_outlined,
      _ => Icons.schedule,
    };

Color _colorEstado(EstadoCita e) => switch (e) {
      EstadoCita.completada => NailsyColors.verde,
      EstadoCita.enCurso => NailsyColors.rosa,
      EstadoCita.pendiente => NailsyColors.ambar,
      EstadoCita.noShow || EstadoCita.cancelada => NailsyColors.rojo,
      EstadoCita.confirmada => NailsyColors.rosaSuave,
    };

String _textoAccion(EstadoCita e) => switch (e) {
      EstadoCita.enCurso => 'Empezar cita',
      EstadoCita.completada => 'Marcar como completada',
      EstadoCita.noShow => 'La clienta no vino',
      EstadoCita.cancelada => 'Cancelar cita',
      _ => etiquetaEstado(e),
    };

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.resumen, required this.esHoy});

  final ResumenDia resumen;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: NailsyColors.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NailsyColors.rosa.withValues(alpha: 0.55)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Dato(
                etiqueta: esHoy ? 'Ingresos de hoy' : 'Ingresos del día',
                valor: _euros.format(resumen.ingresos),
              ),
            ),
            const VerticalDivider(color: NailsyColors.borde, width: 1),
            Expanded(child: _Dato(etiqueta: 'Citas hechas', valor: '${resumen.hechas}/${resumen.total}')),
          ],
        ),
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
    return Column(
      children: [
        Text(etiqueta, style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ColumnaHora extends StatelessWidget {
  const _ColumnaHora({required this.inicio, required this.fin});

  final DateTime inicio;
  final DateTime fin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hora.format(inicio), style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(_hora.format(fin), style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
        ],
      ),
    );
  }
}

class _FilaCita extends StatelessWidget {
  const _FilaCita({required this.cita, required this.onTap});

  final Cita cita;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(cita.estado);
    final apagada = !cita.activa;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColumnaHora(inicio: cita.inicio, fin: cita.fin),
        Expanded(
          child: Opacity(
            opacity: apagada ? 0.5 : 1,
            child: Material(
              color: NailsyColors.superficie,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cita.clientaNombre,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: apagada ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          Text(_euros.format(cita.precio),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(cita.servicioNombre, style: const TextStyle(color: NailsyColors.textoSecundario)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Etiqueta(texto: etiquetaEstado(cita.estado), color: color),
                          if (cita.estadoPago == EstadoPago.pagado)
                            const _Etiqueta(texto: 'Pagada', color: NailsyColors.verde),
                          if (cita.alergias.isNotEmpty)
                            AvisoAlergia(alergias: cita.alergias.map(etiquetaAlergia).toList(), compacto: true),
                        ],
                      ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColumnaHora(inicio: bloqueo.inicio, fin: bloqueo.fin),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: NailsyColors.gris.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(bloqueo.motivo ?? 'Bloqueado',
                style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(icono, size: 48, color: NailsyColors.gris),
          const SizedBox(height: 12),
          Text(texto, style: const TextStyle(color: NailsyColors.textoSecundario)),
        ],
      ),
    );
  }
}
