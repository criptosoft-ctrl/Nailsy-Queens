import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'acceso_clienta.dart';
import 'clienta_repo.dart';

class MisCitasScreen extends StatefulWidget {
  const MisCitasScreen({super.key, required this.repo, required this.alBuscar});

  final ClientaRepo repo;
  final VoidCallback alBuscar;

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  List<MiCita> _citas = [];
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
      if (!mounted) return;
      setState(() {
        _citas = c;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, 'No se pudieron cargar tus citas.');
    }
  }

  Future<void> _entrar() async {
    if (await pedirAcceso(context, widget.repo)) {
      setState(() => _cargando = true);
      await _cargar();
    }
  }

  Future<void> _cancelar(MiCita c) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NailsyColors.superficie,
        title: const Text('¿Cancelar la cita?'),
        content: Text(c.cancelacionGratis
            ? 'Se liberará el hueco para otra clienta.'
            : 'Faltan menos de ${c.horasCancelacion} h. Avisa también a ${c.manicurista} si puedes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (si != true) return;
    try {
      await widget.repo.cancelar(c.id);
      await _cargar();
      if (mounted) aviso(context, 'Cita cancelada');
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final proximas = _citas.where((c) => c.futura && c.activa).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));
    final pasadas = _citas.where((c) => !(c.futura && c.activa)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : !widget.repo.conSesion
              ? EstadoVacio(
                  icono: Icons.lock_outline,
                  texto: 'Entra en tu cuenta para ver tus citas.',
                  accion: FilledButton(onPressed: _entrar, child: const Text('Entrar o crear cuenta')),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: [
                      const TituloSeccion('Próximas'),
                      if (proximas.isEmpty)
                        EstadoVacio(
                          icono: Icons.event_available_outlined,
                          texto: 'No tienes citas próximas.',
                          accion: FilledButton.icon(
                            onPressed: widget.alBuscar,
                            icon: const Icon(Icons.search),
                            label: const Text('Buscar manicurista'),
                          ),
                        ),
                      for (final c in proximas) _TarjetaCita(cita: c, onCancelar: () => _cancelar(c)),
                      if (pasadas.isNotEmpty) ...[
                        const TituloSeccion('Anteriores y canceladas'),
                        for (final c in pasadas) _TarjetaCita(cita: c),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _TarjetaCita extends StatelessWidget {
  const _TarjetaCita({required this.cita, this.onCancelar});

  final MiCita cita;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final c = cita;
    final apagada = onCancelar == null;
    final fecha = DateFormat("EEE d 'de' MMMM · HH:mm", 'es').format(c.inicio);
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
                Text([c.direccion, c.ciudad].whereType<String>().join(', '),
                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
              if (c.estado == 'cancelada')
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Cancelada', style: TextStyle(color: NailsyColors.rojo, fontWeight: FontWeight.w600)),
                ),
              if (onCancelar != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancelar,
                    child: const Text('Cancelar cita', style: TextStyle(color: NailsyColors.rojo)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
