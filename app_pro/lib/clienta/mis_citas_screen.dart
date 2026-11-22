import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'acceso_clienta.dart';
import 'clienta_repo.dart';
import '../i18n.dart';

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
      aviso(context, tr('No se pudieron cargar tus citas.'));
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
                      for (final c in proximas) _TarjetaCita(cita: c, onCancelar: () => _cancelar(c)),
                      if (pasadas.isNotEmpty) ...[
                        TituloSeccion(tr('Anteriores y canceladas')),
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
              if (c.estado == 'cancelada')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(tr('Cancelada'),
                      style: const TextStyle(color: NailsyColors.rojo, fontWeight: FontWeight.w600)),
                ),
              if (onCancelar != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancelar,
                    child: Text(tr('Cancelar cita'), style: const TextStyle(color: NailsyColors.rojo)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
