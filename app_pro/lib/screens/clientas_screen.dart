import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../models/clienta.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'clienta_detalle_screen.dart';

class ClientasScreen extends StatefulWidget {
  const ClientasScreen({super.key, required this.repo});

  final AgendaRepo repo;

  @override
  State<ClientasScreen> createState() => _ClientasScreenState();
}

class _ClientasScreenState extends State<ClientasScreen> {
  List<Clienta> _todas = [];
  String _busqueda = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final c = await widget.repo.clientas();
      if (!mounted) return;
      setState(() {
        _todas = c;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  Future<void> _nueva() async {
    final c = await editarClienta(context, widget.repo);
    if (c == null || !mounted) return;
    await _cargar();
    if (!mounted) return;
    await _abrir(c);
  }

  Future<void> _abrir(Clienta c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientaDetalleScreen(repo: widget.repo, clienta: c)),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final q = _busqueda.trim().toLowerCase();
    final lista = q.isEmpty
        ? _todas
        : _todas
            .where((c) => c.nombre.toLowerCase().contains(q) || (c.telefono ?? '').replaceAll(' ', '').contains(q))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Clientas', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-clientas',
        tooltip: 'Nueva clienta',
        onPressed: _nueva,
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o teléfono',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                  const SizedBox(height: 12),
                  if (_todas.isEmpty)
                    EstadoVacio(
                      icono: Icons.people_outline,
                      texto: 'Todavía no tienes clientas.\nAñade la primera para crear su ficha.',
                      accion: FilledButton.icon(
                        onPressed: _nueva,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Añadir clienta'),
                      ),
                    )
                  else if (lista.isEmpty)
                    const EstadoVacio(icono: Icons.search_off, texto: 'Ninguna clienta coincide con la búsqueda')
                  else
                    for (final c in lista)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Tarjeta(
                          onTap: () => _abrir(c),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: NailsyColors.rosa.withValues(alpha: 0.2),
                                foregroundColor: NailsyColors.rosaSuave,
                                child: Text(c.iniciales, style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    if (c.telefono != null)
                                      Text(c.telefono!, style: const TextStyle(color: NailsyColors.textoSecundario)),
                                    if (c.tieneAlergias) ...[
                                      const SizedBox(height: 4),
                                      AvisoAlergia(
                                          alergias: c.alergias.map(etiquetaAlergia).toList(), compacto: true),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: NailsyColors.gris),
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

/// Abre el formulario de clienta (nueva si [inicial] es null). Devuelve la clienta guardada.
Future<Clienta?> editarClienta(BuildContext context, AgendaRepo repo, {Clienta? inicial}) {
  return showModalBottomSheet<Clienta>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NailsyColors.superficie,
    showDragHandle: true,
    builder: (_) => _FormClienta(repo: repo, inicial: inicial),
  );
}

class _FormClienta extends StatefulWidget {
  const _FormClienta({required this.repo, this.inicial});
  final AgendaRepo repo;
  final Clienta? inicial;

  @override
  State<_FormClienta> createState() => _FormClientaState();
}

class _FormClientaState extends State<_FormClienta> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.inicial?.nombre);
  late final _telefono = TextEditingController(text: widget.inicial?.telefono);
  late final _email = TextEditingController(text: widget.inicial?.email);
  late final _notas = TextEditingController(text: widget.inicial?.notas);
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _email.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final c = await widget.repo.guardarClienta(Clienta(
        id: widget.inicial?.id,
        nombre: _nombre.text,
        telefono: _telefono.text,
        email: _email.text,
        notas: _notas.text,
        alergias: widget.inicial?.alergias ?? const [],
      ));
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      aviso(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.inicial == null ? 'Nueva clienta' : 'Editar clienta',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombre,
                autofocus: widget.inicial == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre y apellido'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (opcional)'),
                validator: (v) => (v != null && v.trim().isNotEmpty && !v.contains('@')) ? 'Email no válido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notas,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
