import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/agenda_repo.dart';
import '../models/publico.dart';
import '../theme.dart';
import '../ubicacion.dart';
import '../widgets/comunes.dart';

/// Lo que ven las clientas en el buscador.
class PerfilPublicoScreen extends StatefulWidget {
  const PerfilPublicoScreen({super.key, required this.repo});

  final AgendaRepo repo;

  @override
  State<PerfilPublicoScreen> createState() => _PerfilPublicoScreenState();
}

class _PerfilPublicoScreenState extends State<PerfilPublicoScreen> {
  final _form = GlobalKey<FormState>();
  final _negocio = TextEditingController();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _direccion = TextEditingController();
  final _bio = TextEditingController();
  final _instagram = TextEditingController();
  MiPerfil _perfil = const MiPerfil(nombre: '');
  Set<String> _especialidades = {};
  bool _publico = false;
  String _zona = 'Atlantic/Canary';
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoFoto = false;
  bool _buscandoUbicacion = false;
  List<String> _pendientes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_negocio, _telefono, _ciudad, _direccion, _bio, _instagram]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final p = await widget.repo.miPerfil();
      final servicios = await widget.repo.servicios();
      final horario = await widget.repo.horario();
      final fotos = await widget.repo.fotos();
      if (!mounted) return;
      setState(() {
        _perfil = p;
        _negocio.text = p.nombreNegocio ?? '';
        _telefono.text = p.telefono ?? '';
        _ciudad.text = p.ciudad ?? '';
        _direccion.text = p.direccion ?? '';
        _bio.text = p.bio ?? '';
        _instagram.text = p.instagram ?? '';
        _especialidades = {...p.especialidades};
        _publico = p.publico;
        _zona = zonasHorarias.containsKey(p.zonaHoraria) ? p.zonaHoraria : 'Atlantic/Canary';
        _pendientes = p.pendientes(
          tieneServicios: servicios.isNotEmpty,
          tieneHorario: horario.isNotEmpty,
          tieneFotos: fotos.any((f) => f.publica),
        );
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  MiPerfil _construir() => MiPerfil(
        nombre: _perfil.nombre,
        nombreNegocio: _t(_negocio),
        telefono: _t(_telefono),
        ciudad: _t(_ciudad),
        direccion: _t(_direccion),
        bio: _t(_bio),
        foto: _perfil.foto,
        instagram: _t(_instagram)?.replaceAll('@', ''),
        especialidades: _especialidades.toList(),
        publico: _publico,
        lat: _perfil.lat,
        lng: _perfil.lng,
        zonaHoraria: _zona,
      );

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      _perfil = _construir();
      await widget.repo.guardarPerfil(_perfil);
      if (!mounted) return;
      aviso(context, _publico ? 'Perfil guardado. Ya apareces en el buscador.' : 'Perfil guardado.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      aviso(context, mensajeError(e));
    }
  }

  Future<void> _cambiarFoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (img == null) return;
    setState(() => _subiendoFoto = true);
    try {
      final bytes = await img.readAsBytes();
      final ext = img.name.contains('.') ? img.name.split('.').last : 'jpg';
      final ruta = await widget.repo.subirFoto(bytes, extension: ext, alPortafolio: false);
      _perfil = _construir().copyWith(foto: ruta);
      await widget.repo.guardarPerfil(_perfil);
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _usarUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    try {
      final u = await ubicacionActual();
      _perfil = _construir().copyWith(lat: u.lat, lng: u.lng);
      if (mounted) aviso(context, 'Ubicación guardada. Las clientas cercanas te verán primero.');
    } catch (e) {
      if (mounted) aviso(context, e is ErrorNailsy ? e.mensaje : 'No se pudo obtener la ubicación.');
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(appBar: AppBar(title: const Text('Mi perfil público')), body: const Center(child: CircularProgressIndicator()));
    }
    final tieneUbicacion = _perfil.lat != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil público')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [
            // ---- Visibilidad ----
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _publico,
                    onChanged: (v) => setState(() => _publico = v),
                    title: const Text('Aparecer en el buscador', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Las clientas podrán encontrarte y reservar en tus huecos libres'),
                  ),
                  if (_pendientes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Para que las clientas puedan reservar, completa: ${_pendientes.join(', ')}.',
                        style: const TextStyle(color: NailsyColors.ambar, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            // ---- Foto ----
            const TituloSeccion('Foto de perfil'),
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: FotoRemota(url: widget.repo.urlFoto(_perfil.foto), icono: Icons.person_outline),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _subiendoFoto ? null : _cambiarFoto,
                  icon: _subiendoFoto
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cambiar foto'),
                ),
              ],
            ),
            // ---- Datos ----
            const TituloSeccion('Tu negocio'),
            TextFormField(
              controller: _negocio,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Nombre comercial', hintText: 'Ej. ${_perfil.nombre} Nails'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Sobre ti', hintText: 'Tu especialidad, experiencia, estilo…'),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _instagram,
              decoration: const InputDecoration(labelText: 'Instagram (opcional)', prefixText: '@'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono (no se muestra a las clientas)'),
            ),
            // ---- Especialidades ----
            const TituloSeccion('Especialidades'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in estilosBuscables.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: _especialidades.contains(e.key),
                    onSelected: (v) => setState(() => v ? _especialidades.add(e.key) : _especialidades.remove(e.key)),
                  ),
              ],
            ),
            // ---- Ubicación ----
            const TituloSeccion('Dónde trabajas'),
            TextFormField(
              controller: _ciudad,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ciudad o zona', hintText: 'Ej. Las Palmas de Gran Canaria'),
              validator: (v) => (_publico && (v == null || v.trim().isEmpty)) ? 'Necesaria para aparecer en el buscador' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccion,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Dirección (se muestra al reservar)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _buscandoUbicacion ? null : _usarUbicacion,
              icon: _buscandoUbicacion
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(tieneUbicacion ? Icons.where_to_vote : Icons.my_location),
              label: Text(tieneUbicacion ? 'Ubicación guardada · actualizar' : 'Usar mi ubicación actual (desde el local)'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sirve para que te encuentren las clientas que buscan "cerca de mí". Hazlo estando en tu local.',
              style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 12),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _zona,
              decoration: const InputDecoration(labelText: 'Zona horaria'),
              items: [for (final z in zonasHorarias.entries) DropdownMenuItem(value: z.key, child: Text(z.value))],
              onChanged: (v) => setState(() => _zona = v ?? _zona),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Guardar perfil'),
          ),
        ),
      ),
    );
  }
}
