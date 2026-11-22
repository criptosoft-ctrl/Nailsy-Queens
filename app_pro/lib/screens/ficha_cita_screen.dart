import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/agenda_repo.dart';
import '../models/cita.dart';
import '../models/clienta.dart';
import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'agenda_screen.dart' show pildoraEstado, textoEnCurso;
import 'clienta_detalle_screen.dart';
import '../sectores.dart';

final _hora = DateFormat('HH:mm');
final _diaCorto = DateFormat('d MMM', 'es');

/// Todo lo necesario para atender una cita: clienta, alergias, ficha de la uña,
/// trabajos anteriores, notas y finalizar.
class FichaCitaScreen extends StatefulWidget {
  const FichaCitaScreen({super.key, required this.repo, required this.cita, this.ahora});

  final AgendaRepo repo;
  final Cita cita;
  final DateTime Function()? ahora;

  @override
  State<FichaCitaScreen> createState() => _FichaCitaScreenState();
}

class _FichaCitaScreenState extends State<FichaCitaScreen> {
  late Cita _cita = widget.cita;
  FichaUna? _ficha;
  Cita? _ultimaVisita;
  List<FotoPortafolio> _fotos = [];
  bool _cargando = true;
  bool _ocupado = false;

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();
  String? get _clientaId => _cita.clientaId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final id = _clientaId;
    if (id == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final consentimiento = await widget.repo.tieneConsentimiento(id);
      final ficha = consentimiento ? await widget.repo.ficha(id) : null;
      final historial = await widget.repo.historialClienta(id);
      final fotos = await widget.repo.fotosClienta(id);
      if (!mounted) return;
      setState(() {
        _ficha = ficha;
        _ultimaVisita = historial
            .where((c) => c.id != _cita.id && c.estado == EstadoCita.completada && c.inicio.isBefore(_cita.inicio))
            .fold<Cita?>(null, (m, c) => m == null || c.inicio.isAfter(m.inicio) ? c : m);
        _fotos = fotos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  Future<void> _cambiarEstado(EstadoCita e) async {
    setState(() => _ocupado = true);
    try {
      await widget.repo.cambiarEstado(_cita.id, e);
      if (mounted) setState(() => _cita = _cita.copyWith(estado: e));
    } catch (err) {
      if (mounted) aviso(context, mensajeError(err));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _finalizar() async {
    setState(() => _ocupado = true);
    try {
      await widget.repo.finalizarCita(_cita.id);
      if (!mounted) return;
      setState(() => _cita = _cita.copyWith(estado: EstadoCita.completada, estadoPago: EstadoPago.pagado));
      aviso(context, 'Cita finalizada y cobrada · ${precio(_cita.precio)}');
    } catch (err) {
      if (mounted) aviso(context, mensajeError(err));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editarNotas() async {
    final ctrl = TextEditingController(text: _cita.notas);
    final nuevas = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Notas de la cita', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Tono usado, diseño, cómo ha ido…'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar notas')),
          ],
        ),
      ),
    );
    if (nuevas == null) return;
    try {
      await widget.repo.guardarNotasCita(_cita.id, nuevas);
      if (mounted) setState(() => _cita = _cita.copyWith(notas: nuevas));
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    }
  }

  Future<void> _fotoDeHoy() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Hacer foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    final img = await ImagePicker().pickImage(source: origen, maxWidth: 1600, imageQuality: 85);
    if (img == null) return;
    if (!mounted) return;
    final publica = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NailsyColors.superficie,
        title: const Text('¿Mostrarla en tu portafolio?'),
        content: Text('Si la publicas, se verá en tu perfil público. Si no, solo queda en la ficha de ${context.sector.laCliente}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Solo en la ficha')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    if (publica == null) return;
    setState(() => _ocupado = true);
    try {
      final bytes = await img.readAsBytes();
      final ext = img.name.contains('.') ? img.name.split('.').last : 'jpg';
      await widget.repo.subirFoto(bytes,
          extension: ext, mime: img.mimeType, publica: publica, citaId: _cita.id, clientaId: _clientaId);
      final fotos = _clientaId == null ? <FotoPortafolio>[] : await widget.repo.fotosClienta(_clientaId!);
      if (mounted) setState(() => _fotos = fotos);
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _verFicha() {
    if (_clientaId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientaDetalleScreen(
          repo: widget.repo,
          clienta: Clienta(id: _clientaId, nombre: _cita.clientaNombre, alergias: _cita.alergias),
        ),
      ),
    ).then((_) => _cargar());
  }

  void _verFoto(int i) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: PageView(
            controller: PageController(initialPage: i),
            children: [
              for (final f in _fotos)
                InteractiveViewer(
                    child: Center(child: FotoRemota(url: widget.repo.urlFoto(f.ruta), fit: BoxFit.contain))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _cita;
    final ahora = _ahora;
    final enCurso = c.enCursoAhora(ahora);
    final alergias = (_ficha?.alergias ?? c.alergias).map(etiquetaAlergia).toList();
    final consejo = consejoAlergia(_ficha?.alergias ?? c.alergias);
    final estado = enCurso
        ? Pildora(
            texto: textoEnCurso(c, ahora).replaceFirst('En curso · quedan ', ''),
            color: context.acentoSuave,
            fondo: context.acento.withValues(alpha: 0.16),
            icono: Icons.schedule)
        : pildoraEstado(c);

    return Scaffold(
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                children: [
                  // ---- Cabecera ----
                  Row(
                    children: [
                      BotonCuadrado(icono: Icons.chevron_left, tooltip: 'Volver', onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Ficha de cita',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      ),
                      if (estado != null) estado,
                      PopupMenuButton<EstadoCita>(
                        tooltip: 'Más opciones',
                        icon: const Icon(Icons.more_vert, color: NailsyColors.textoSecundario),
                        color: NailsyColors.superficieAlta,
                        onSelected: _cambiarEstado,
                        itemBuilder: (_) => [
                          if (c.estado != EstadoCita.confirmada)
                            const PopupMenuItem(value: EstadoCita.confirmada, child: Text('Marcar como confirmada')),
                          if (c.estado != EstadoCita.noShow)
                            PopupMenuItem(value: EstadoCita.noShow, child: Text('${_mayus(context.sector.laCliente)} no vino')),
                          if (c.estado != EstadoCita.cancelada)
                            const PopupMenuItem(
                                value: EstadoCita.cancelada,
                                child: Text('Cancelar cita', style: TextStyle(color: NailsyColors.rojo))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ---- Clienta ----
                  Row(
                    children: [
                      AvatarIniciales(nombre: c.clientaNombre, tam: 62),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.clientaNombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              _ultimaVisita == null
                                  ? 'Primera visita'
                                  : 'Última visita: ${_diaCorto.format(_ultimaVisita!.inicio)} · ${_ultimaVisita!.servicioNombre}',
                              style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_clientaId != null) TextButton(onPressed: _verFicha, child: const Text('Ver ficha')),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ---- Servicio ----
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: NailsyColors.superficie,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NailsyColors.borde),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.servicioNombre, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                '${_hora.format(c.inicio)} – ${_hora.format(c.fin)} · ${duracionCorta(c.duracion)}',
                                style: const TextStyle(color: NailsyColors.textoSecundario),
                              ),
                            ],
                          ),
                        ),
                        Text(precio(c.precio), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),

                  // ---- A domicilio ----
                  if (c.aDomicilio) ...[
                    const SizedBox(height: 14),
                    TarjetaDomicilio(cita: c),
                  ],

                  // ---- Alergias ----
                  if (alergias.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NailsyColors.rojoFondo,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NailsyColors.rojo.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: NailsyColors.rojo),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alergia a ${alergias.join(', ').toLowerCase()}',
                                    style: const TextStyle(
                                        color: NailsyColors.rojo, fontWeight: FontWeight.w800, fontSize: 15.5)),
                                if (consejo != null) ...[
                                  const SizedBox(height: 4),
                                  Text(consejo, style: const TextStyle(height: 1.4, fontSize: 14)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ---- Ficha de la uña ----
                  const SizedBox(height: 22),
                  Text(context.sector.ficha.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_ficha == null)
                    Tarjeta(
                      onTap: _clientaId == null ? null : _verFicha,
                      child: const Text('Sin ficha todavía. Toca para rellenarla.',
                          style: TextStyle(color: NailsyColors.textoSecundario)),
                    )
                  else
                    _RejillaFicha(ficha: _ficha!),

                  // ---- Trabajos anteriores ----
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                          child: Text('Trabajos anteriores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                      if (_fotos.isNotEmpty) TextButton(onPressed: () => _verFoto(0), child: const Text('Ver todos')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _fotos.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return GestureDetector(
                            onTap: _ocupado ? null : _fotoDeHoy,
                            child: BordeDiscontinuo(
                              radio: 18,
                              color: context.acento,
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: context.acento.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_camera_outlined, color: context.acento),
                                    const SizedBox(height: 4),
                                    Text('Hoy',
                                        style: TextStyle(color: context.acento, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        final f = _fotos[i - 1];
                        return GestureDetector(
                          onTap: () => _verFoto(i - 1),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: SizedBox(
                                    width: 92, height: 92, child: FotoRemota(url: widget.repo.urlFoto(f.ruta))),
                              ),
                              const SizedBox(height: 6),
                              Text(f.fecha == null ? '' : _diaCorto.format(f.fecha!),
                                  style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // ---- Notas ----
                  if ((c.notas ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('Notas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Tarjeta(onTap: _editarNotas, child: Text(c.notas!, style: const TextStyle(height: 1.4))),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: _cargando
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: NailsyColors.borde))),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _editarNotas,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
                      icon: const Icon(Icons.description_outlined, size: 20),
                      label: const Text('Notas'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _botonPrincipal(c, enCurso)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _botonPrincipal(Cita c, bool enCurso) {
    if (c.estado == EstadoCita.completada) {
      return FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(c.estadoPago == EstadoPago.pagado ? 'Cobrada · ${precio(c.precio)}' : 'Completada'),
      );
    }
    if (c.estado == EstadoCita.cancelada || c.estado == EstadoCita.noShow) {
      return FilledButton(onPressed: null, child: Text(c.estado == EstadoCita.noShow ? 'No vino' : 'Cancelada'));
    }
    if (!enCurso) {
      return FilledButton(
        onPressed: _ocupado ? null : () => _cambiarEstado(EstadoCita.enCurso),
        child: const Text('Empezar cita'),
      );
    }
    return FilledButton(
      onPressed: _ocupado ? null : _finalizar,
      child: FittedBox(child: Text('Finalizar y cobrar ${precio(c.precio)}')),
    );
  }
}

class _RejillaFicha extends StatelessWidget {
  const _RejillaFicha({required this.ficha});

  final FichaUna ficha;

  @override
  Widget build(BuildContext context) {
    final unas = context.sector.id == 'nails';
    final tipos = ficha.diagnosticos.where((d) => d != 'cuticula_seca').map(etiquetaDiagnostico).toList();
    final primerTono = ficha.tonosFavoritos.isEmpty ? '—' : ficha.tonosFavoritos.first;
    final datos = unas
        ? [
            ('Tipo de uña', tipos.isEmpty ? '—' : tipos.join(', ')),
            ('Forma', ficha.formaDeseada ?? '—'),
            ('Tono favorito', primerTono),
            ('Cutícula', ficha.diagnosticos.contains('cuticula_seca') ? 'Seca' : 'Normal'),
          ]
        : [
            ('Pelo', tipos.isEmpty ? '—' : tipos.join(', ')),
            ('Corte', ficha.formaDeseada ?? '—'),
            ('Barba', ficha.largoDeseado ?? '—'),
            ('Máquina', ficha.tonosFavoritos.isEmpty ? '—' : ficha.tonosFavoritos.join(' · ')),
          ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.95,
      children: [
        for (final (t, v) in datos)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: NailsyColors.superficie, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t, style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                const SizedBox(height: 2),
                Text(v,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              ],
            ),
          ),
      ],
    );
  }
}


String _mayus(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);


/// Dirección de una cita a domicilio con "Cómo llegar" (Google Maps) y "Llamar".
class TarjetaDomicilio extends StatelessWidget {
  const TarjetaDomicilio({super.key, required this.cita});

  final Cita cita;

  Uri get _mapa {
    final destino = cita.lat != null && cita.lng != null ? '${cita.lat},${cita.lng}' : (cita.direccion ?? '');
    return Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destino});
  }

  @override
  Widget build(BuildContext context) {
    final c = cita;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NailsyColors.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.acento.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pildora(
                texto: 'A domicilio',
                color: context.acentoSuave,
                fondo: context.acento.withValues(alpha: 0.16),
                icono: Icons.home_outlined,
              ),
              const SizedBox(width: 10),
              if (c.suplemento > 0)
                Expanded(
                  child: Text('Desplazamiento +${precio(c.suplemento)}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, color: context.acentoSuave, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c.direccion ?? 'Sin dirección',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (c.viajeMin > 0) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text('Agenda bloqueada ${c.viajeMin} min antes y después para el viaje',
                  style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () => launchUrl(_mapa, mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.directions, size: 20),
                  label: const Text('Cómo llegar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: (c.telefono ?? '').trim().isEmpty
                      ? null
                      : () => launchUrl(Uri(scheme: 'tel', path: c.telefono!.replaceAll(' ', ''))),
                  icon: const Icon(Icons.call_outlined, size: 20),
                  label: const Text('Llamar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
