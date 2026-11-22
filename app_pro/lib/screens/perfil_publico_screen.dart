import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/agenda_repo.dart';
import '../models/publico.dart';
import '../theme.dart';
import '../ubicacion.dart';
import '../widgets/comunes.dart';
import '../sectores.dart';

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
  final _nombre = TextEditingController();
  final _bio = TextEditingController();
  final _instagram = TextEditingController();
  final _suplemento = TextEditingController();
  bool _atiendeLocal = true;
  Domicilio _dom = const Domicilio();
  MiPerfil _perfil = const MiPerfil(nombre: '');
  List<String> _especialidades = [];
  final _nuevaEspecialidad = TextEditingController();
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
    for (final c in [_nombre, _negocio, _telefono, _ciudad, _direccion, _bio, _instagram, _suplemento, _nuevaEspecialidad]) {
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
        _nombre.text = p.nombre;
        _negocio.text = p.nombreNegocio ?? '';
        _telefono.text = p.telefono ?? '';
        _ciudad.text = p.ciudad ?? '';
        _direccion.text = p.direccion ?? '';
        _bio.text = p.bio ?? '';
        _instagram.text = p.instagram ?? '';
        // Las antiguas claves (rusa, gel…) se pasan a su nombre para que ella las pueda editar.
        _especialidades = [for (final e in p.especialidades) etiquetaEstilo(e)];
        _atiendeLocal = p.atiendeLocal;
        _dom = p.domicilio;
        _suplemento.text = _dom.importe == 0 ? '' : _formatoImporte(_dom.importe);
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
        nombre: _t(_nombre) ?? _perfil.nombre,
        nombreNegocio: _t(_negocio),
        telefono: _t(_telefono),
        ciudad: _t(_ciudad),
        direccion: _t(_direccion),
        bio: _t(_bio),
        foto: _perfil.foto,
        instagram: _t(_instagram)?.replaceAll('@', ''),
        especialidades: List.of(_especialidades),
        publico: _publico,
        lat: _perfil.lat,
        lng: _perfil.lng,
        zonaHoraria: _zona,
        atiendeLocal: _atiendeLocal,
        domicilio: _dom.copyWith(importe: _importe()),
      );

  double _importe() => double.tryParse(_suplemento.text.trim().replaceAll(',', '.').replaceAll('€', '')) ?? 0;

  Future<void> _guardar() async {
    // Si dejó escrita una especialidad sin pulsar +, se añade también.
    if (_nuevaEspecialidad.text.trim().isNotEmpty) _anadirEspecialidad();
    if (!_atiendeLocal && !_dom.activo) {
      aviso(context, 'Elige al menos un sitio donde atiendes: tu local o a domicilio.');
      return;
    }
    if (_dom.activo && _perfil.lat == null) {
      aviso(context, 'Para atender a domicilio guarda tu ubicación (botón "Usar mi ubicación actual"): desde ahí se mide tu zona.');
      return;
    }
    if (!_form.currentState!.validate()) {
      // El campo con error puede estar fuera de la pantalla: avisamos aquí también.
      aviso(
          context,
          _nombre.text.trim().isEmpty
              ? 'Falta tu nombre (en "Tu negocio").'
              : 'Para aparecer en el buscador falta la ciudad (más abajo, en "Dónde trabajas").');
      return;
    }
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
      final ruta = await widget.repo.subirFoto(bytes, extension: ext, mime: img.mimeType, alPortafolio: false);
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
      if (mounted) aviso(context, 'Ubicación guardada. ${_mayus(context.sector.lasClientes)} cercanos te verán primero.'.replaceFirst('clientas cercanos', 'clientas cercanas'));
    } catch (e) {
      if (mounted) aviso(context, e is ErrorNailsy ? e.mensaje : 'No se pudo obtener la ubicación.');
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  void _anadirEspecialidad() {
    final t = _nuevaEspecialidad.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return;
    final nueva = t[0].toUpperCase() + t.substring(1);
    if (_especialidades.any((e) => e.toLowerCase() == nueva.toLowerCase())) {
      aviso(context, 'Ya tienes "$nueva".');
      return;
    }
    setState(() {
      _especialidades.add(nueva);
      _nuevaEspecialidad.clear();
    });
  }

  /// Zona en km, suplemento (lo pone ella) y tiempo de viaje.
  Widget _ajustesDomicilio() {
    final acento = context.acento;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: NailsyColors.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NailsyColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Hasta dónde vas', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('${_dom.radioKm} km', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: acento)),
            ],
          ),
          Slider(
            value: _dom.radioKm.clamp(3, 30).toDouble(),
            min: 3,
            max: 30,
            divisions: 27,
            label: '${_dom.radioKm} km',
            onChanged: (v) => setState(() => _dom = _dom.copyWith(radioKm: v.round())),
          ),
          const Text('Se mide en línea recta desde tu ubicación guardada.',
              style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 12)),
          const SizedBox(height: 14),
          const Text('Suplemento por desplazamiento', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Fijo por cita')),
              ButtonSegment(value: true, label: Text('Por km')),
            ],
            selected: {_dom.porKm},
            onSelectionChanged: (v) => setState(() => _dom = _dom.copyWith(porKm: v.first)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _suplemento,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _dom.porKm ? 'Importe por km' : 'Importe por cita',
              hintText: _dom.porKm ? 'Ej. 0,50' : 'Ej. 5',
              suffixText: _dom.porKm ? '€/km' : '€',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _importe() <= 0
                ? 'Déjalo vacío o en 0 si no cobras el desplazamiento.'
                : _dom.porKm
                    ? 'Ej.: a 6 km se suman ${precio(double.parse((_importe() * 6).toStringAsFixed(2)))} a la cita.'
                    : 'Se suman ${precio(_importe())} a cada cita a domicilio.',
            style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Text('Tiempo de viaje entre citas', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [15, 30, 45])
                ChoiceChip(
                  label: Text('$m min'),
                  selected: _dom.viajeMin == m,
                  onSelected: (_) => setState(() => _dom = _dom.copyWith(viajeMin: m)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Se bloquea en tu agenda antes y después de cada cita a domicilio.',
              style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 12)),
        ],
      ),
    );
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
                    subtitle: Text('${_mayus(context.sector.lasClientes)} podrán encontrarte y reservar en tus huecos libres'),
                  ),
                  if (_pendientes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Para que ${context.sector.lasClientes} puedan reservar, completa: ${_pendientes.join(', ')}.',
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
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Tu nombre', hintText: 'Así te saludamos en la agenda'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _negocio,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Nombre comercial', hintText: 'Ej. ${_nombre.text.isEmpty ? 'Eudy' : _nombre.text} Nails'),
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
              decoration: InputDecoration(labelText: 'Teléfono (no se muestra a ${context.sector.lasClientes})'),
            ),
            // ---- Especialidades ----
            const TituloSeccion('Especialidades'),
            const Text('Escribe lo que haces. Se muestran en tu tarjeta y sirven para que te encuentren.',
                style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
            const SizedBox(height: 10),
            if (_especialidades.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _especialidades)
                    InputChip(
                      label: Text(e),
                      onDeleted: () => setState(() => _especialidades.remove(e)),
                      deleteButtonTooltipMessage: 'Quitar',
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_especialidades.length < _maxEspecialidades)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nuevaEspecialidad,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 24,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _anadirEspecialidad(),
                      decoration: InputDecoration(
                        labelText: 'Nueva especialidad',
                        hintText: context.sector.id == 'barberia' ? 'Ej. Degradado' : 'Ej. Uñas esculpidas',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Añadir',
                    onPressed: _anadirEspecialidad,
                    icon: const Icon(Icons.add),
                  ),
                ],
              )
            else
              Text('Máximo $_maxEspecialidades. Quita una para añadir otra.',
                  style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
            // ---- Ubicación ----
            const TituloSeccion('Dónde trabajas'),
            TextFormField(
              controller: _ciudad,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ciudad o zona', hintText: 'Ej. Las Palmas de Gran Canaria'),
              validator: (v) => (_publico && (v == null || v.trim().isEmpty)) ? 'Necesaria para aparecer en el buscador' : null,
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _atiendeLocal,
              onChanged: (v) => setState(() => _atiendeLocal = v),
              secondary: Icon(Icons.storefront_outlined, color: context.acento),
              title: const Text('En mi local', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${_mayus(context.sector.lasClientes)} vienen a tu salón o cabina'),
            ),
            if (_atiendeLocal) ...[
              TextFormField(
                controller: _direccion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Dirección del local (se muestra al reservar)'),
              ),
              const SizedBox(height: 4),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _dom.activo,
              onChanged: (v) => setState(() => _dom = _dom.copyWith(activo: v)),
              secondary: Icon(Icons.home_outlined, color: context.acento),
              title: const Text('A domicilio', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Vas a casa de ${context.sector.laCliente}'),
            ),
            if (_dom.activo) _ajustesDomicilio(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _buscandoUbicacion ? null : _usarUbicacion,
              icon: _buscandoUbicacion
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(tieneUbicacion ? Icons.where_to_vote : Icons.my_location),
              label: Text(tieneUbicacion ? 'Ubicación guardada · actualizar' : 'Usar mi ubicación actual'),
            ),
            const SizedBox(height: 4),
            Text(
              _dom.activo
                  ? 'Sirve para que te encuentren ${context.sector.lasClientes} que buscan "cerca de mí" y para medir tu zona a domicilio. Hazlo desde tu local o desde donde sales.'
                  : 'Sirve para que te encuentren ${context.sector.lasClientes} que buscan "cerca de mí". Hazlo estando en tu local.',
              style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12),
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


String _mayus(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

const _maxEspecialidades = 8;

String _formatoImporte(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');
