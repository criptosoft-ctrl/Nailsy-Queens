import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../models/catalogo.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Servicios base y añadidos de Nail Art con su precio y duración.
class TarifarioScreen extends StatefulWidget {
  const TarifarioScreen({super.key, required this.repo});

  final AgendaRepo repo;

  @override
  State<TarifarioScreen> createState() => _TarifarioScreenState();
}

class _TarifarioScreenState extends State<TarifarioScreen> {
  List<Servicio> _servicios = [];
  List<Anadido> _anadidos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final s = await widget.repo.servicios();
      final a = await widget.repo.anadidos();
      if (!mounted) return;
      setState(() {
        _servicios = s;
        _anadidos = a;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  Future<void> _editarServicio([Servicio? s]) async {
    final res = await showModalBottomSheet<_Resultado<Servicio>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      builder: (_) => _FormServicio(inicial: s),
    );
    if (res == null || !mounted) return;
    try {
      if (res.borrar) {
        await widget.repo.borrarServicio(s!.id!);
      } else {
        await widget.repo.guardarServicio(res.valor!);
      }
      await _cargar();
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    }
  }

  Future<void> _editarAnadido([Anadido? a]) async {
    final res = await showModalBottomSheet<_Resultado<Anadido>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      builder: (_) => _FormAnadido(inicial: a),
    );
    if (res == null || !mounted) return;
    try {
      if (res.borrar) {
        await widget.repo.borrarAnadido(a!.id!);
      } else {
        await widget.repo.guardarAnadido(res.valor!);
      }
      await _cargar();
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarifario', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                children: [
                  TituloSeccion('Servicios',
                      trailing: TextButton.icon(
                          onPressed: () => _editarServicio(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Añadir'))),
                  if (_servicios.isEmpty)
                    const EstadoVacio(
                        icono: Icons.spa_outlined,
                        texto: 'Añade tus servicios (manicura rusa, acrílicas…) con su precio y duración.'),
                  for (final s in _servicios)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tarjeta(
                        onTap: () => _editarServicio(s),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('${categorias[s.categoria] ?? s.categoria} · ${formatoDuracion(s.duracionMin)}',
                                      style: const TextStyle(color: NailsyColors.textoSecundario)),
                                ],
                              ),
                            ),
                            Text(precio(s.precio), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  TituloSeccion('Añadidos de Nail Art',
                      trailing: TextButton.icon(
                          onPressed: () => _editarAnadido(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Añadir'))),
                  if (_anadidos.isEmpty)
                    const EstadoVacio(
                        icono: Icons.auto_awesome_outlined,
                        texto: 'Añade decoraciones: mano alzada, cristales, encapsulados…'),
                  for (final a in _anadidos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tarjeta(
                        onTap: () => _editarAnadido(a),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('+${formatoDuracion(a.duracionMin)}${a.porUna ? ' por uña' : ''}',
                                      style: const TextStyle(color: NailsyColors.textoSecundario)),
                                ],
                              ),
                            ),
                            Text('+${precio(a.precio)}${a.porUna ? '/uña' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Resultado<T> {
  const _Resultado.guardar(this.valor) : borrar = false;
  const _Resultado.borrar()
      : valor = null,
        borrar = true;
  final T? valor;
  final bool borrar;
}

class _FormServicio extends StatefulWidget {
  const _FormServicio({this.inicial});
  final Servicio? inicial;

  @override
  State<_FormServicio> createState() => _FormServicioState();
}

class _FormServicioState extends State<_FormServicio> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.inicial?.nombre);
  late final _minutos = TextEditingController(text: widget.inicial?.duracionMin.toString());
  late final _precio = TextEditingController(text: _textoPrecio(widget.inicial?.precio));
  late String _categoria = widget.inicial?.categoria ?? 'semipermanente';

  @override
  void dispose() {
    _nombre.dispose();
    _minutos.dispose();
    _precio.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _Resultado.guardar(Servicio(
        id: widget.inicial?.id,
        nombre: _nombre.text.trim(),
        categoria: _categoria,
        duracionMin: int.parse(_minutos.text.trim()),
        precio: leerNumero(_precio.text)!,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _HojaFormulario(
      titulo: widget.inicial == null ? 'Nuevo servicio' : 'Editar servicio',
      formKey: _form,
      onGuardar: _guardar,
      onBorrar: widget.inicial == null ? null : () => Navigator.pop(context, const _Resultado<Servicio>.borrar()),
      children: [
        TextFormField(
          controller: _nombre,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre (ej. Manicura rusa + gel)'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _categoria,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [for (final e in categorias.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _categoria = v ?? _categoria),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _CampoMinutos(controller: _minutos, label: 'Duración (min)')),
            const SizedBox(width: 12),
            Expanded(child: _CampoPrecio(controller: _precio, label: 'Precio (€)')),
          ],
        ),
      ],
    );
  }
}

class _FormAnadido extends StatefulWidget {
  const _FormAnadido({this.inicial});
  final Anadido? inicial;

  @override
  State<_FormAnadido> createState() => _FormAnadidoState();
}

class _FormAnadidoState extends State<_FormAnadido> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.inicial?.nombre);
  late final _minutos = TextEditingController(text: widget.inicial?.duracionMin.toString() ?? '0');
  late final _precio = TextEditingController(text: _textoPrecio(widget.inicial?.precio));
  late bool _porUna = widget.inicial?.porUna ?? true;

  @override
  void dispose() {
    _nombre.dispose();
    _minutos.dispose();
    _precio.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _Resultado.guardar(Anadido(
        id: widget.inicial?.id,
        nombre: _nombre.text.trim(),
        duracionMin: int.parse(_minutos.text.trim()),
        precio: leerNumero(_precio.text)!,
        porUna: _porUna,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _HojaFormulario(
      titulo: widget.inicial == null ? 'Nuevo añadido' : 'Editar añadido',
      formKey: _form,
      onGuardar: _guardar,
      onBorrar: widget.inicial == null ? null : () => Navigator.pop(context, const _Resultado<Anadido>.borrar()),
      children: [
        TextFormField(
          controller: _nombre,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre (ej. Diseño a mano alzada)'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _CampoMinutos(controller: _minutos, label: 'Tiempo extra (min)', permitirCero: true)),
            const SizedBox(width: 12),
            Expanded(child: _CampoPrecio(controller: _precio, label: 'Precio extra (€)')),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _porUna,
          onChanged: (v) => setState(() => _porUna = v),
          title: const Text('Se cobra por uña'),
          subtitle: const Text('Si lo activas, al crear la cita eliges en cuántas uñas'),
        ),
      ],
    );
  }
}

class _CampoMinutos extends StatelessWidget {
  const _CampoMinutos({required this.controller, required this.label, this.permitirCero = false});
  final TextEditingController controller;
  final String label;
  final bool permitirCero;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final n = int.tryParse(v?.trim() ?? '');
        if (n == null || n < 0 || (!permitirCero && n == 0)) return 'Minutos no válidos';
        return null;
      },
    );
  }
}

class _CampoPrecio extends StatelessWidget {
  const _CampoPrecio({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final n = leerNumero(v);
        return (n == null || n < 0) ? 'Precio no válido' : null;
      },
    );
  }
}

/// Hoja inferior con título, campos y botones Guardar / Borrar.
class _HojaFormulario extends StatelessWidget {
  const _HojaFormulario({
    required this.titulo,
    required this.formKey,
    required this.children,
    required this.onGuardar,
    this.onBorrar,
  });

  final String titulo;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onGuardar;
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 20),
              FilledButton(onPressed: onGuardar, child: const Text('Guardar')),
              if (onBorrar != null)
                TextButton(
                  onPressed: onBorrar,
                  child: const Text('Eliminar', style: TextStyle(color: NailsyColors.rojo)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _textoPrecio(double? v) {
  if (v == null) return null;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceAll('.', ',');
}
