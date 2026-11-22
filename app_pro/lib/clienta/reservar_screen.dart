import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/catalogo.dart';
import '../models/publico.dart';
import '../sectores.dart';
import '../theme.dart';
import '../ubicacion.dart';
import 'buscar_screen.dart' show textoSuplemento;
import '../widgets/comunes.dart';
import 'acceso_clienta.dart';
import 'clienta_repo.dart';
import '../i18n.dart';

/// Reserva: extras → día → hueco libre → confirmar. Devuelve `true` si se reservó.
class ReservarScreen extends StatefulWidget {
  const ReservarScreen(
      {super.key, required this.repo, required this.perfil, required this.servicio, this.desde, this.ubicacion});

  final ClientaRepo repo;
  final PerfilPublico perfil;
  final Servicio servicio;

  /// Primer día a mostrar (por defecto hoy).
  final DateTime? desde;

  /// Cómo se obtiene la ubicación (por defecto, la del móvil; se cambia en las pruebas).
  final Future<({double lat, double lng})> Function()? ubicacion;

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

  // A domicilio
  late bool _enCasa;
  final _direccion = TextEditingController();
  ({double lat, double lng})? _punto;
  ZonaComprobada? _zona;
  bool _localizando = false;

  Domicilio get _dom => widget.perfil.domicilio;
  int get _viaje => _enCasa ? _dom.viajeMin : 0;
  double get _suplemento => _enCasa && (_zona?.dentro ?? false) ? _zona!.suplemento : 0;
  bool get _direccionLista =>
      !_enCasa || (_direccion.text.trim().isNotEmpty && _punto != null && (_zona?.dentro ?? false));

  Presupuesto get _p => Presupuesto.calcular(widget.servicio, widget.perfil.anadidos, _cantidades);

  @override
  void initState() {
    super.initState();
    _enCasa = !widget.perfil.atiendeLocal && _dom.activo;
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
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _cargarHuecos() async {
    setState(() {
      _cargandoHuecos = true;
      _hora = null;
    });
    try {
      final h = await widget.repo.huecosLibres(widget.perfil.id, _dia, _p.duracionMin, viajeMin: _viaje);
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

  void _elegirLugar(bool casa) {
    if (casa == _enCasa) return;
    setState(() => _enCasa = casa);
    // Con viaje hay que dejar margen antes y después: cambian los huecos.
    _cargarHuecos();
  }

  Future<void> _usarUbicacion() async {
    setState(() => _localizando = true);
    try {
      final u = await (widget.ubicacion ?? ubicacionActual)();
      final z = await widget.repo.comprobarZona(widget.perfil.id, u.lat, u.lng);
      if (!mounted) return;
      setState(() {
        _punto = u;
        _zona = z;
      });
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _localizando = false);
    }
  }

  Widget _opcionLugar({required bool casa, required IconData icono, required String titulo, required String detalle}) {
    final sel = _enCasa == casa;
    return Expanded(
      child: Material(
        color: sel ? context.acento.withValues(alpha: 0.14) : NailsyColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: sel ? context.acento : NailsyColors.borde, width: sel ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _elegirLugar(casa),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: sel ? context.acento : NailsyColors.textoSecundario),
                const SizedBox(height: 6),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(detalle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _seccionLugar() {
    final perfil = widget.perfil;
    if (!_dom.activo) return const [];
    final detalleCasa = tr('{s} · hasta {k} km', {'s': textoSuplemento(_dom), 'k': _dom.radioKm});
    return [
      TituloSeccion(tr('¿Dónde?')),
      Row(
        children: [
          if (perfil.atiendeLocal) ...[
            _opcionLugar(
              casa: false,
              icono: Icons.storefront_outlined,
              titulo: tr('En su local'),
              detalle: [perfil.direccion, perfil.ciudad].whereType<String>().join(', '),
            ),
            const SizedBox(width: 10),
          ],
          _opcionLugar(casa: true, icono: Icons.home_outlined, titulo: tr('En mi casa'), detalle: detalleCasa),
        ],
      ),
      if (_enCasa) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _direccion,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: tr('Tu dirección'),
            hintText: tr('Calle, número, piso, portal…'),
            prefixIcon: const Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _localizando ? null : _usarUbicacion,
          icon: _localizando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_punto == null ? Icons.my_location : Icons.where_to_vote),
          label: Text(tr(_punto == null ? 'Usar mi ubicación para comprobar la zona' : 'Ubicación lista · actualizar')),
        ),
        if (_punto != null) ...[
          const SizedBox(height: 8),
          _AvisoZona(zona: _zona, radioKm: _dom.radioKm),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            tr('Hazlo desde casa: así sabemos si estás dentro de su zona y cuánto cuesta el desplazamiento.'),
            style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12),
          ),
        ],
      ],
    ];
  }

  Future<void> _confirmar() async {
    if (_hora == null || !_direccionLista) return;
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
        domicilio: _enCasa
            ? DireccionCita(texto: _direccion.text.trim(), lat: _punto!.lat, lng: _punto!.lng)
            : null,
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
            '${toBeginningOfSentenceCase(DateFormat.MMMMEEEEd(codigoIdioma).add_Hm().format(_hora!))}'
            '${_enCasa ? '\n${tr('En tu casa: {d}', {'d': _direccion.text.trim()})}' : ''}',
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

          ..._seccionLugar(),

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
                  Text(precio(p.precio + _suplemento), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    _enCasa
                        ? (_suplemento > 0
                            ? tr('Incluye {s} de desplazamiento. Pagas al terminar, sin comisiones.', {'s': precio(_suplemento)})
                            : tr('Pagas al terminar. Sin comisiones.'))
                        : tr('Pagas en el local. Sin comisiones.'),
                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12)),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: (_hora == null || !_direccionLista || _reservando) ? null : _confirmar,
                child: _reservando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(tr(!_direccionLista
                        ? 'Indica tu dirección'
                        : _hora == null
                            ? 'Elige una hora'
                            : 'Confirmar reserva')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Dentro de su zona · 4,2 km · +5 €" (verde) o "Fuera de su zona" (rojo).
class _AvisoZona extends StatelessWidget {
  const _AvisoZona({required this.zona, required this.radioKm});

  final ZonaComprobada? zona;
  final int radioKm;

  @override
  Widget build(BuildContext context) {
    final z = zona;
    final dentro = z?.dentro ?? false;
    final color = dentro ? NailsyColors.verde : NailsyColors.rojo;
    final km = z?.distanciaKm == null ? '' : ' · ${NumberFormat('0.0', codigoIdioma).format(z!.distanciaKm!)} km';
    final texto = z == null || z.distanciaKm == null
        ? tr('No se pudo comprobar la distancia. Usa tu ubicación.')
        : dentro
            ? '${tr('Dentro de su zona')}$km · ${z.suplemento > 0 ? '+${precio(z.suplemento)}' : tr('sin suplemento')}'
            : '${tr('Fuera de su zona (máx. {k} km)', {'k': radioKm})}$km';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(dentro ? Icons.check_circle : Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
