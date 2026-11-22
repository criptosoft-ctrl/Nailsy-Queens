import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/catalogo.dart';
import '../models/publico.dart';
import '../sectores.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'acceso_clienta.dart';
import 'clienta_repo.dart';
import '../i18n.dart';

/// Reserva: extras → día → hueco libre → confirmar. Devuelve `true` si se reservó.
class ReservarScreen extends StatefulWidget {
  const ReservarScreen({super.key, required this.repo, required this.perfil, required this.servicio, this.desde});

  final ClientaRepo repo;
  final PerfilPublico perfil;
  final Servicio servicio;

  /// Primer día a mostrar (por defecto hoy).
  final DateTime? desde;

  @override
  State<ReservarScreen> createState() => _ReservarScreenState();
}

class _ReservarScreenState extends State<ReservarScreen> {
  final Map<String, int> _cantidades = {};
  late final List<DateTime> _dias;
  late DateTime _dia;
  List<DateTime> _huecos = [];
  DateTime? _hora;
  bool _cargandoHuecos = true;
  bool _reservando = false;
  final _notas = TextEditingController();

  Presupuesto get _p => Presupuesto.calcular(widget.servicio, widget.perfil.anadidos, _cantidades);

  @override
  void initState() {
    super.initState();
    final hoy = widget.desde ?? DateTime.now();
    final laborables = widget.perfil.diasLaborables;
    _dias = [
      for (var i = 0; i < 21; i++)
        DateTime(hoy.year, hoy.month, hoy.day + i),
    ].where((d) => laborables.isEmpty || laborables.contains(d.weekday)).toList();
    _dia = _dias.isNotEmpty ? _dias.first : DateTime(hoy.year, hoy.month, hoy.day);
    _cargarHuecos();
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargarHuecos() async {
    setState(() {
      _cargandoHuecos = true;
      _hora = null;
    });
    try {
      final h = await widget.repo.huecosLibres(widget.perfil.id, _dia, _p.duracionMin);
      if (!mounted) return;
      setState(() {
        _huecos = h;
        _cargandoHuecos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _huecos = [];
        _cargandoHuecos = false;
      });
      aviso(context, tr('No se pudieron cargar los horarios.'));
    }
  }

  void _cambiarCantidad(Anadido a, int n) {
    setState(() => _cantidades[a.id!] = n);
    // La duración cambia: los huecos disponibles también.
    _cargarHuecos();
  }

  Future<void> _confirmar() async {
    if (_hora == null) return;
    final ok = await pedirAcceso(context, widget.repo, motivo: tr('Para guardar tu reserva necesitamos tu nombre y email.'));
    if (!ok || !mounted) return;
    setState(() => _reservando = true);
    try {
      await widget.repo.reservar(
        manicuristaId: widget.perfil.id,
        servicio: widget.servicio,
        inicio: _hora!,
        anadidos: Map.of(_cantidades),
        notas: _notas.text,
      );
      if (!mounted) return;
      setState(() => _reservando = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NailsyColors.superficie,
          icon: const Icon(Icons.check_circle, color: NailsyColors.verde, size: 56),
          title: Text(tr('¡Reserva confirmada!')),
          content: Text(
            '${tr('{s} con {p}', {'s': widget.servicio.nombre, 'p': widget.perfil.nombre})}\n'
            '${toBeginningOfSentenceCase(DateFormat.MMMMEEEEd(codigoIdioma).add_Hm().format(_hora!))}',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Ver mis citas'))),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _reservando = false);
      aviso(context, mensajeError(e));
      _cargarHuecos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final perfil = widget.perfil;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Reservar · {n}', {'n': perfil.nombre}))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
        children: [
          Tarjeta(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.servicio.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(formatoDuracion(widget.servicio.duracionMin),
                          style: const TextStyle(color: NailsyColors.textoSecundario)),
                    ],
                  ),
                ),
                Text(precio(widget.servicio.precio), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),

          // ---- Extras ----
          if (perfil.anadidos.isNotEmpty) ...[
            TituloSeccion(tr(context.sector.cobroPorUna ? 'Añade Nail Art o extras' : 'Añade extras')),
            for (final a in perfil.anadidos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tarjeta(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('+${precio(a.precio)}${a.porUna ? tr(' por uña') : ''}',
                                style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (!a.porUna)
                        Switch(value: (_cantidades[a.id] ?? 0) > 0, onChanged: (v) => _cambiarCantidad(a, v ? 1 : 0))
                      else ...[
                        IconButton(
                          tooltip: tr('Menos uñas'),
                          onPressed: (_cantidades[a.id] ?? 0) > 0 ? () => _cambiarCantidad(a, _cantidades[a.id]! - 1) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(
                          width: 24,
                          child: Text('${_cantidades[a.id] ?? 0}',
                              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          tooltip: tr('Más uñas'),
                          onPressed: (_cantidades[a.id] ?? 0) < 10
                              ? () => _cambiarCantidad(a, (_cantidades[a.id] ?? 0) + 1)
                              : null,
                          icon: Icon(Icons.add_circle_outline, color: context.acento),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],

          // ---- Día ----
          TituloSeccion(tr('Elige día')),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _dias[i];
                final sel = d == _dia;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _dia = d);
                    _cargarHuecos();
                  },
                  child: Container(
                    width: 58,
                    decoration: BoxDecoration(
                      color: sel ? context.acento : NailsyColors.superficie,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('EEE', codigoIdioma).format(d).toUpperCase().replaceAll('.', ''),
                            style: TextStyle(fontSize: 12, color: sel ? context.sobreAcento : NailsyColors.textoSecundario)),
                        Text('${d.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: sel ? context.sobreAcento : null)),
                        Text(DateFormat('MMM', codigoIdioma).format(d).replaceAll('.', ''),
                            style: TextStyle(fontSize: 11, color: sel ? context.sobreAcento : NailsyColors.textoSecundario)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ---- Hora ----
          TituloSeccion(tr('Elige hora')),
          if (_cargandoHuecos)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (perfil.diasLaborables.isEmpty)
            Tarjeta(
              child: Text(
                tr('{n} todavía no ha publicado su horario, así que aún no se puede reservar online.', {'n': perfil.nombre}),
                style: const TextStyle(color: NailsyColors.textoSecundario),
              ),
            )
          else if (_huecos.isEmpty)
            Tarjeta(
              child: Text(tr('No quedan huecos libres este día. Prueba con otro.'),
                  style: const TextStyle(color: NailsyColors.textoSecundario)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in _huecos)
                  ChoiceChip(
                    label: Text(DateFormat('HH:mm').format(h)),
                    selected: _hora == h,
                    onSelected: (_) => setState(() => _hora = h),
                  ),
              ],
            ),

          TituloSeccion(tr('Nota para {p}', {'p': tr(context.sector.elProfesional)})),
          TextField(
            controller: _notas,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                hintText: tr(context.sector.cobroPorUna ? 'Diseño que te gustaría, largo, color… (opcional)' : 'Lo que te gustaría (opcional)')),
          ),
          const SizedBox(height: 12),
          Text(
            tr('Cancelación gratuita hasta {h} h antes desde "Mis citas".', {'h': perfil.horasCancelacion}),
            style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: NailsyColors.superficie,
            border: Border(top: BorderSide(color: NailsyColors.borde)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _hora == null
                          ? formatoDuracion(p.duracionMin)
                          : '${DateFormat.MMMEd(codigoIdioma).add_Hm().format(_hora!)} · ${formatoDuracion(p.duracionMin)}',
                      style: const TextStyle(color: NailsyColors.textoSecundario),
                    ),
                  ),
                  Text(precio(p.precio), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Pagas en el local. Sin comisiones.'),
                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12)),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: (_hora == null || _reservando) ? null : _confirmar,
                child: _reservando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(tr(_hora == null ? 'Elige una hora' : 'Confirmar reserva')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
