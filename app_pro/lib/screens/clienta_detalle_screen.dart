import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/agenda_repo.dart';
import '../models/cita.dart';
import '../models/clienta.dart';
import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'clientas_screen.dart';
import 'ficha_form_screen.dart';
import 'nueva_cita_screen.dart';

final _diaCorto = DateFormat('d MMM', 'es');

/// Ficha de una clienta: pestañas Ficha · Historial · Notas.
class ClientaDetalleScreen extends StatefulWidget {
  const ClientaDetalleScreen({super.key, required this.repo, required this.clienta});

  final AgendaRepo repo;
  final Clienta clienta;

  @override
  State<ClientaDetalleScreen> createState() => _ClientaDetalleScreenState();
}

class _ClientaDetalleScreenState extends State<ClientaDetalleScreen> {
  late Clienta _clienta = widget.clienta;
  FichaUna? _ficha;
  bool _consentimiento = false;
  List<Cita> _historial = [];
  List<FotoPortafolio> _fotos = [];
  bool _cargando = true;
  int _pestana = 0;

  String get _id => _clienta.id!;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      // Datos completos (puede llegar solo con id y nombre desde una cita)
      final todas = await widget.repo.clientas();
      final completa = todas.where((c) => c.id == _id).firstOrNull;
      final consentimiento = await widget.repo.tieneConsentimiento(_id);
      final ficha = consentimiento ? await widget.repo.ficha(_id) : null;
      final historial = await widget.repo.historialClienta(_id);
      final fotos = await widget.repo.fotosClienta(_id);
      if (!mounted) return;
      setState(() {
        if (completa != null) _clienta = completa;
        _consentimiento = consentimiento;
        _ficha = ficha;
        _historial = historial;
        _fotos = fotos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  Future<void> _editarDatos() async {
    final c = await editarClienta(context, widget.repo, inicial: _clienta);
    if (c != null && mounted) setState(() => _clienta = c);
  }

  Future<void> _pedirConsentimiento() async {
    final metodo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Consentimiento de datos de salud',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Para guardar alergias y diagnósticos, la clienta debe aceptar este texto. '
                'Enséñale la pantalla o léeselo:',
                style: TextStyle(color: NailsyColors.textoSecundario),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: NailsyColors.fondo,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NailsyColors.borde),
                ),
                child: Text('“$textoConsentimiento”', style: const TextStyle(height: 1.4)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'en_persona'),
                child: const Text('La clienta acepta (en persona)'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ahora no')),
            ],
          ),
        ),
      ),
    );
    if (metodo == null || !mounted) return;
    try {
      await widget.repo.registrarConsentimiento(_id, metodo);
      await _cargar();
      if (mounted) await _editarFicha();
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    }
  }

  Future<void> _editarFicha() async {
    final guardada = await Navigator.push<FichaUna>(
      context,
      MaterialPageRoute(
        builder: (_) => FichaFormScreen(
          repo: widget.repo,
          clientaNombre: _clienta.nombre,
          inicial: _ficha ?? FichaUna(clientaId: _id),
        ),
      ),
    );
    if (guardada != null && mounted) {
      setState(() {
        _ficha = guardada;
        _clienta = _clienta.copyWith(alergias: guardada.alergias);
      });
    }
  }

  Future<void> _reservar() async {
    final ahora = DateTime.now();
    final creada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaCitaScreen(
          repo: widget.repo,
          dia: DateTime(ahora.year, ahora.month, ahora.day),
          clientaInicial: _clienta,
        ),
      ),
    );
    if (creada == true) {
      await _cargar();
      if (mounted) aviso(context, 'Cita guardada');
    }
  }

  Cita? get _proxima {
    final ahora = DateTime.now();
    final futuras = _historial.where((c) => c.activa && c.estado != EstadoCita.completada && c.fin.isAfter(ahora)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    return futuras.firstOrNull;
  }

  Cita? get _ultima {
    final hechas = _historial.where((c) => c.estado == EstadoCita.completada).toList()
      ..sort((a, b) => b.inicio.compareTo(a.inicio));
    return hechas.firstOrNull;
  }

  String _textoProxima(Cita c) {
    final hoy = DateTime.now();
    final d = DateTime(c.inicio.year, c.inicio.month, c.inicio.day);
    final h = DateFormat('HH:mm').format(c.inicio);
    if (d == DateTime(hoy.year, hoy.month, hoy.day)) return 'hoy, $h';
    if (d == DateTime(hoy.year, hoy.month, hoy.day + 1)) return 'mañana, $h';
    return '${DateFormat("EEE d MMM", 'es').format(c.inicio)}, $h';
  }

  @override
  Widget build(BuildContext context) {
    final proxima = _proxima;
    return Scaffold(
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                children: [
                  Row(
                    children: [
                      BotonCuadrado(icono: Icons.chevron_left, tooltip: 'Volver', onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Text('Clientas',
                              style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 17, fontWeight: FontWeight.w600))),
                      IconButton(
                          tooltip: 'Editar datos', onPressed: _editarDatos, icon: const Icon(Icons.edit_outlined)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      AvatarIniciales(nombre: _clienta.nombre, tam: 76),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_clienta.nombre, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              proxima == null ? 'Sin citas próximas' : 'Próxima cita: ${_textoProxima(proxima)}',
                              style: const TextStyle(color: NailsyColors.textoSecundario),
                            ),
                            if (_clienta.telefono != null)
                              Text(_clienta.telefono!, style: const TextStyle(color: NailsyColors.textoSecundario)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Pestanas(
                    actual: _pestana,
                    titulos: const ['Ficha', 'Historial', 'Notas'],
                    onCambio: (i) => setState(() => _pestana = i),
                  ),
                  const SizedBox(height: 16),
                  ...switch (_pestana) {
                    0 => _pestanaFicha(),
                    1 => _pestanaHistorial(),
                    _ => _pestanaNotas(),
                  },
                ],
              ),
      ),
      bottomNavigationBar: _cargando
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(onPressed: _reservar, child: const Text('Reservar nueva cita')),
              ),
            ),
    );
  }

  List<Widget> _pestanaFicha() {
    if (!_consentimiento) {
      return [
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Para guardar alergias y diagnósticos hace falta el consentimiento de la clienta (RGPD).',
                style: TextStyle(color: NailsyColors.textoSecundario),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _pedirConsentimiento,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Pedir consentimiento'),
              ),
            ],
          ),
        ),
      ];
    }
    final f = _ficha;
    final ultima = _ultima;
    final fotoUltima = ultima == null ? null : _fotos.where((x) => x.citaId == ultima.id).firstOrNull ?? _fotos.firstOrNull;
    return [
      if (f != null && f.alergias.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: NailsyColors.rojoFondo,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NailsyColors.rojo.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: NailsyColors.rojo),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  const TextSpan(
                      text: 'Alergia: ', style: TextStyle(color: NailsyColors.rojo, fontWeight: FontWeight.w800)),
                  TextSpan(text: f.alergias.map(etiquetaAlergia).join(', ').toLowerCase()),
                ])),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
      Row(
        children: [
          const Expanded(child: TituloSeccion('Diagnóstico')),
          TextButton.icon(
            onPressed: _editarFicha,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(f == null ? 'Rellenar' : 'Editar'),
          ),
        ],
      ),
      if (f == null)
        Tarjeta(
            onTap: _editarFicha,
            child: const Text('Sin ficha todavía. Toca para rellenarla.',
                style: TextStyle(color: NailsyColors.textoSecundario)))
      else ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in f.diagnosticos)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration:
                    BoxDecoration(color: NailsyColors.superficieAlta, borderRadius: BorderRadius.circular(20)),
                child: Text(etiquetaDiagnostico(d), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            if (f.diagnosticos.isEmpty)
              const Text('Sin diagnóstico', style: TextStyle(color: NailsyColors.textoSecundario)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _Dato('Forma deseada', f.formaDeseada ?? '—')),
            const SizedBox(width: 10),
            Expanded(child: _Dato('Tono favorito', f.tonosFavoritos.isEmpty ? '—' : f.tonosFavoritos.first)),
          ],
        ),
        if ((f.observaciones ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Tarjeta(child: Text(f.observaciones!, style: const TextStyle(height: 1.4))),
        ],
      ],
      const TituloSeccion('Última visita'),
      if (ultima == null)
        const Tarjeta(
            child: Text('Todavía no tiene visitas completadas.', style: TextStyle(color: NailsyColors.textoSecundario)))
      else
        Tarjeta(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                    width: 66,
                    height: 66,
                    child: FotoRemota(url: widget.repo.urlFoto(fotoUltima?.ruta), icono: Icons.spa_outlined)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ultima.servicioNombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _diaCorto.format(ultima.inicio),
                        if (f != null && f.tonosFavoritos.isNotEmpty) 'Tono ${f.tonosFavoritos.first}',
                      ].join(' · '),
                      style: const TextStyle(color: NailsyColors.textoSecundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _pestanaHistorial() {
    if (_historial.isEmpty) {
      return const [
        Tarjeta(child: Text('Aún no tiene citas.', style: TextStyle(color: NailsyColors.textoSecundario))),
      ];
    }
    return [
      for (final c in _historial)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Tarjeta(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.servicioNombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${DateFormat("d MMM yyyy · HH:mm", 'es').format(c.inicio)} · ${etiquetaEstado(c.estado)}',
                        style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(precio(c.precio), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _pestanaNotas() {
    final notasCitas = _historial.where((c) => (c.notas ?? '').trim().isNotEmpty).toList();
    return [
      Tarjeta(
        onTap: _editarDatos,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                (_clienta.notas ?? '').trim().isEmpty ? 'Sin notas. Toca para añadir.' : _clienta.notas!,
                style: TextStyle(
                    height: 1.4, color: (_clienta.notas ?? '').trim().isEmpty ? NailsyColors.textoSecundario : null),
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: NailsyColors.textoSecundario),
          ],
        ),
      ),
      if (notasCitas.isNotEmpty) ...[
        const TituloSeccion('Notas de sus citas'),
        for (final c in notasCitas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_diaCorto.format(c.inicio)} · ${c.servicioNombre}',
                      style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(c.notas!, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ),
      ],
    ];
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.titulo, this.valor);

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: NailsyColors.superficie, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
        ],
      ),
    );
  }
}

/// Selector de pestañas segmentado (como en el diseño).
class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.actual, required this.titulos, required this.onCambio});

  final int actual;
  final List<String> titulos;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: NailsyColors.superficie, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          for (var i = 0; i < titulos.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onCambio(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: i == actual ? NailsyColors.superficieAlta : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    titulos[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                      color: i == actual ? NailsyColors.texto : NailsyColors.textoSecundario,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
