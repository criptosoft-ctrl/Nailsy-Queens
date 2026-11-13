import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/agenda_repo.dart';
import '../models/cita.dart';
import '../models/clienta.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'clientas_screen.dart';
import 'ficha_form_screen.dart';

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
  bool _cargando = true;

  String get _id => _clienta.id!;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final consentimiento = await widget.repo.tieneConsentimiento(_id);
      final ficha = consentimiento ? await widget.repo.ficha(_id) : null;
      final historial = await widget.repo.historialClienta(_id);
      if (!mounted) return;
      setState(() {
        _consentimiento = consentimiento;
        _ficha = ficha;
        _historial = historial;
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
                  borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    final alergias = (_ficha?.alergias ?? _clienta.alergias).map(etiquetaAlergia).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_clienta.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(tooltip: 'Editar datos', onPressed: _editarDatos, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                if (alergias.isNotEmpty) ...[AvisoAlergia(alergias: alergias), const SizedBox(height: 12)],
                Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Linea(icono: Icons.phone_outlined, texto: _clienta.telefono ?? 'Sin teléfono'),
                      if (_clienta.email != null) _Linea(icono: Icons.mail_outline, texto: _clienta.email!),
                      if (_clienta.notas != null) _Linea(icono: Icons.notes, texto: _clienta.notas!),
                    ],
                  ),
                ),
                TituloSeccion('Ficha de la uña',
                    trailing: _consentimiento
                        ? TextButton.icon(
                            onPressed: _editarFicha,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(_ficha == null ? 'Rellenar' : 'Editar'),
                          )
                        : null),
                if (!_consentimiento)
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
                  )
                else if (_ficha == null)
                  Tarjeta(
                    onTap: _editarFicha,
                    child: const Text('Sin ficha todavía. Toca para rellenarla.',
                        style: TextStyle(color: NailsyColors.textoSecundario)),
                  )
                else
                  _ResumenFicha(ficha: _ficha!),
                const TituloSeccion('Historial de citas'),
                if (_historial.isEmpty)
                  const Tarjeta(
                      child: Text('Aún no tiene citas.', style: TextStyle(color: NailsyColors.textoSecundario)))
                else
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
                                  Text(c.servicioNombre, style: const TextStyle(fontWeight: FontWeight.w600)),
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
              ],
            ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: NailsyColors.textoSecundario),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class _ResumenFicha extends StatelessWidget {
  const _ResumenFicha({required this.ficha});
  final FichaUna ficha;

  @override
  Widget build(BuildContext context) {
    Widget fila(String titulo, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(titulo, style: const TextStyle(color: NailsyColors.textoSecundario)),
              ),
              Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );
    String o(List<String> l, String Function(String) f) => l.isEmpty ? '—' : l.map(f).join(', ');
    return Tarjeta(
      child: Column(
        children: [
          fila('Diagnóstico', o(ficha.diagnosticos, etiquetaDiagnostico)),
          fila('Alergias', o(ficha.alergias, etiquetaAlergia)),
          fila('Forma', ficha.formaDeseada ?? '—'),
          fila('Largo', ficha.largoDeseado ?? '—'),
          fila('Tonos', o(ficha.tonosFavoritos, (s) => s)),
          if (ficha.observaciones != null) fila('Notas', ficha.observaciones!),
        ],
      ),
    );
  }
}
