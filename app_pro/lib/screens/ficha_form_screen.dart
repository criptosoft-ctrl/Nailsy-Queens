import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../models/clienta.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Edición de la ficha técnica de la uña. Devuelve la ficha guardada.
class FichaFormScreen extends StatefulWidget {
  const FichaFormScreen({super.key, required this.repo, required this.clientaNombre, required this.inicial});

  final AgendaRepo repo;
  final String clientaNombre;
  final FichaUna inicial;

  @override
  State<FichaFormScreen> createState() => _FichaFormScreenState();
}

class _FichaFormScreenState extends State<FichaFormScreen> {
  late final Set<String> _diagnosticos = {...widget.inicial.diagnosticos};
  late final Set<String> _alergias = {...widget.inicial.alergias};
  late String? _forma = widget.inicial.formaDeseada;
  late String? _largo = widget.inicial.largoDeseado;
  late final _tonos = TextEditingController(text: widget.inicial.tonosFavoritos.join(', '));
  late final _observaciones = TextEditingController(text: widget.inicial.observaciones);
  final _otraAlergia = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _tonos.dispose();
    _observaciones.dispose();
    _otraAlergia.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final ficha = FichaUna(
      clientaId: widget.inicial.clientaId,
      diagnosticos: _diagnosticos.toList(),
      alergias: _alergias.toList(),
      formaDeseada: _forma,
      largoDeseado: _largo,
      tonosFavoritos: _tonos.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      observaciones: _observaciones.text,
    );
    try {
      await widget.repo.guardarFicha(ficha);
      if (mounted) Navigator.pop(context, ficha);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      aviso(context, mensajeError(e));
    }
  }

  void _anadirOtraAlergia() {
    final t = _otraAlergia.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _alergias.add(t);
      _otraAlergia.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final otrasAlergias = _alergias.where((a) => !alergiasComunes.containsKey(a)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Ficha · ${widget.clientaNombre}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          const TituloSeccion('Alergias'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in alergiasComunes.entries)
                FilterChip(
                  label: Text(e.value),
                  selected: _alergias.contains(e.key),
                  selectedColor: NailsyColors.rojo.withValues(alpha: 0.3),
                  checkmarkColor: NailsyColors.rojo,
                  onSelected: (v) => setState(() => v ? _alergias.add(e.key) : _alergias.remove(e.key)),
                ),
              for (final a in otrasAlergias)
                InputChip(
                  label: Text(a),
                  selected: true,
                  selectedColor: NailsyColors.rojo.withValues(alpha: 0.3),
                  onDeleted: () => setState(() => _alergias.remove(a)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _otraAlergia,
                  decoration: const InputDecoration(hintText: 'Otra alergia…'),
                  onSubmitted: (_) => _anadirOtraAlergia(),
                ),
              ),
              IconButton(onPressed: _anadirOtraAlergia, icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          const TituloSeccion('Diagnóstico de la uña'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in diagnosticosComunes.entries)
                FilterChip(
                  label: Text(e.value),
                  selected: _diagnosticos.contains(e.key),
                  onSelected: (v) => setState(() => v ? _diagnosticos.add(e.key) : _diagnosticos.remove(e.key)),
                ),
            ],
          ),
          const TituloSeccion('Forma preferida'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in formasUna)
                ChoiceChip(
                  label: Text(f),
                  selected: _forma == f,
                  onSelected: (v) => setState(() => _forma = v ? f : null),
                ),
            ],
          ),
          const TituloSeccion('Largo preferido'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in largosUna)
                ChoiceChip(
                  label: Text(l),
                  selected: _largo == l,
                  onSelected: (v) => setState(() => _largo = v ? l : null),
                ),
            ],
          ),
          const TituloSeccion('Tonos favoritos'),
          TextField(
            controller: _tonos,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Separados por comas: Nude rosado, Rojo cereza…'),
          ),
          const TituloSeccion('Observaciones'),
          TextField(
            controller: _observaciones,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Lo que convenga recordar para la próxima cita'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Guardar ficha'),
          ),
        ),
      ),
    );
  }
}
