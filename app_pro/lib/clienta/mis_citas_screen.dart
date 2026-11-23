import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'acceso_clienta.dart';
import 'clienta_repo.dart';
import '../i18n.dart';
import '../whatsapp.dart';
import '../widgets/resenas.dart';

class MisCitasScreen extends StatefulWidget {
  const MisCitasScreen({super.key, required this.repo, required this.alBuscar});

  final ClientaRepo repo;
  final VoidCallback alBuscar;

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  List<MiCita> _citas = [];

  /// WhatsApp de cada profesional con cita próxima (solo si ella lo muestra).
  Map<String, String> _whatsapp = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!widget.repo.conSesion) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final c = await widget.repo.misCitas();
      final wa = <String, String>{};
      for (final id in {for (final x in c) if (x.futura && x.activa) x.manicuristaId}) {
        try {
          final tel = (await widget.repo.perfil(id))?.whatsapp;
          if (enlaceWhatsapp(tel, '') != null) wa[id] = tel!;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _citas = c;
        _whatsapp = wa;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, tr('No se pudieron cargar tus citas.'));
    }
  }

  Future<void> _entrar() async {
    if (await pedirAcceso(context, widget.repo)) {
      setState(() => _cargando = true);
      await _cargar();
    }
  }

  /// Hoja para valorar una cita finalizada.
  Future<void> _valorar(MiCita c, [int inicial = 0]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NailsyColors.superficie,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _HojaValorar(cita: c, repo: widget.repo, inicial: inicial),
    );
    if (ok == true && mounted) {
      aviso(context, tr('¡Gracias por tu reseña!'));
      await _cargar();
    }
  }

  Future<void> _cancelar(MiCita c) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NailsyColors.superficie,
        title: Text(tr('¿Cancelar la cita?')),
        content: Text(c.cancelacionGratis
            ? tr('Se liberará el hueco para otra persona.')
            : tr('Faltan menos de {h} h. Avisa también a {n} si puedes.', {'h': c.horasCancelacion, 'n': c.manicurista})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('No'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Sí, cancelar'))),
        ],
      ),
    );
    if (si != true) return;
    try {
      await widget.repo.cancelar(c.id);
      await _cargar();
      if (mounted) aviso(context, tr('Cita cancelada'));
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final proximas = _citas.where((c) => c.futura && c.activa).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));
    final pasadas = _citas.where((c) => !(c.futura && c.activa)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Mis citas'), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : !widget.repo.conSesion
              ? EstadoVacio(
                  icono: Icons.lock_outline,
                  texto: tr('Entra en tu cuenta para ver tus citas.'),
                  accion: FilledButton(onPressed: _entrar, child: Text(tr('Entrar o crear cuenta'))),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: [
                      TituloSeccion(tr('Próximas')),
                      if (proximas.isEmpty)
                        EstadoVacio(
                          icono: Icons.event_available_outlined,
                          texto: tr('No tienes citas próximas.'),
                          accion: FilledButton.icon(
                            onPressed: widget.alBuscar,
                            icon: const Icon(Icons.search),
                            label: Text(tr('Buscar en GlamGo')),
                          ),
                        ),
                      for (final c in proximas)
                        _TarjetaCita(cita: c, onCancelar: () => _cancelar(c), whatsapp: _whatsapp[c.manicuristaId]),
                      if (pasadas.isNotEmpty) ...[
                        TituloSeccion(tr('Anteriores y canceladas')),
                        for (final c in pasadas)
                          _TarjetaCita(cita: c, onValorar: c.valorable ? (n) => _valorar(c, n) : null),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _TarjetaCita extends StatelessWidget {
  const _TarjetaCita({required this.cita, this.onCancelar, this.whatsapp, this.onValorar});

  final MiCita cita;
  final VoidCallback? onCancelar;

  /// Cita finalizada sin valorar: al tocar una estrella se abre la hoja para valorar.
  final ValueChanged<int>? onValorar;
  final String? whatsapp;

  @override
  Widget build(BuildContext context) {
    final c = cita;
    final apagada = onCancelar == null && onValorar == null && cita.misEstrellas == null;
    final fecha = DateFormat.MMMEd(codigoIdioma).add_Hm().format(c.inicio);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: apagada ? 0.6 : 1,
        child: Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${fecha[0].toUpperCase()}${fecha.substring(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  Text(precio(c.precio), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 4),
              Text('${c.servicio} · ${c.manicurista}'),
              if (c.direccion != null || c.ciudad != null)
                Text(
                    c.aDomicilio
                        ? tr('A domicilio · {d}', {'d': c.direccion ?? ''})
                        : [c.direccion, c.ciudad].whereType<String>().join(', '),
                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
              if (onValorar != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(tr('¿Qué tal fue?'),
                          style: const TextStyle(color: NailsyColors.oro, fontWeight: FontWeight.w700)),
                    ),
                    for (var i = 1; i <= 5; i++)
                      InkResponse(
                        onTap: () => onValorar!(i),
                        radius: 20,
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.star_outline_rounded, size: 26, color: NailsyColors.textoSecundario),
                        ),
                      ),
                  ],
                ),
              ],
              if (c.misEstrellas != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Text(tr('Tu valoración'),
                          style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                      const SizedBox(width: 6),
                      Estrellas(valor: c.misEstrellas!, tamano: 14),
                    ],
                  ),
                ),
              if (c.estado == 'cancelada')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(tr('Cancelada'),
                      style: const TextStyle(color: NailsyColors.rojo, fontWeight: FontWeight.w600)),
                ),
              if (onCancelar != null)
                Row(
                  children: [
                    if (whatsapp != null)
                      Flexible(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: verdeWhatsapp),
                          onPressed: () => abrirWhatsapp(
                              whatsapp,
                              tr('Hola {n}, te escribo por mi cita del {f} en GlamGo.',
                                  {'n': c.manicurista, 'f': fecha})),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: Text(tr('WhatsApp'), overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: onCancelar,
                      child: Text(tr('Cancelar cita'), style: const TextStyle(color: NailsyColors.rojo)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estrellas grandes, comentario opcional y "Publicar reseña".
class _HojaValorar extends StatefulWidget {
  const _HojaValorar({required this.cita, required this.repo, this.inicial = 0});

  final MiCita cita;
  final ClientaRepo repo;
  final int inicial;

  @override
  State<_HojaValorar> createState() => _HojaValorarState();
}

class _HojaValorarState extends State<_HojaValorar> {
  static const _etiquetas = ['', 'Muy mal', 'Mal', 'Normal', 'Muy bien', '¡Excelente!'];
  final _comentario = TextEditingController();
  late int _estrellas = widget.inicial;
  bool _enviando = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    setState(() => _enviando = true);
    try {
      await widget.repo.valorar(widget.cita.id, _estrellas, comentario: _comentario.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      aviso(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cita;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: NailsyColors.borde, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text(tr('Valora tu cita con {n}', {'n': c.manicurista}),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            '${c.servicio} · ${DateFormat.MMMEd(codigoIdioma).add_Hm().format(c.inicio)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: tr('{n} estrellas', {'n': i}),
                  iconSize: 40,
                  onPressed: () => setState(() => _estrellas = i),
                  icon: Icon(i <= _estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i <= _estrellas ? NailsyColors.oro : NailsyColors.textoSecundario),
                ),
            ],
          ),
          SizedBox(
            height: 22,
            child: Text(_estrellas == 0 ? '' : tr(_etiquetas[_estrellas]),
                textAlign: TextAlign.center,
                style: const TextStyle(color: NailsyColors.oro, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comentario,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: tr('Cuéntanos qué tal (opcional)')),
          ),
          Text(tr('Se publica con tu nombre y la inicial del apellido.'),
              style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _estrellas == 0 || _enviando ? null : _publicar,
            child: Text(tr(_estrellas == 0 ? 'Elige las estrellas' : 'Publicar reseña')),
          ),
        ],
      ),
    );
  }
}
