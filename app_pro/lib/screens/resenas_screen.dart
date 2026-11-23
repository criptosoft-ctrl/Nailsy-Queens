import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../models/publico.dart';
import '../sectores.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import '../widgets/resenas.dart';

/// GlamGo Pro · Mis reseñas: nota media, reseñas y respuesta (una por reseña).
class ResenasScreen extends StatefulWidget {
  const ResenasScreen({super.key, required this.repo});

  final AgendaRepo repo;

  @override
  State<ResenasScreen> createState() => _ResenasScreenState();
}

class _ResenasScreenState extends State<ResenasScreen> {
  List<Resena> _resenas = [];
  String _nombre = '';
  bool _cargando = true;
  final _textos = <String, TextEditingController>{};
  final _enviando = <String>{};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _textos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.repo.misResenas();
      var nombre = '';
      try {
        final p = await widget.repo.miPerfil();
        nombre = (p.nombreNegocio ?? '').trim().isNotEmpty ? p.nombreNegocio! : p.nombre;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _resenas = r;
        _nombre = nombre;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  Future<void> _responder(Resena r) async {
    final c = _textos[r.id]!;
    final texto = c.text.trim();
    if (texto.isEmpty) return;
    setState(() => _enviando.add(r.id));
    try {
      await widget.repo.responderResena(r.id, texto);
      if (!mounted) return;
      setState(() {
        final i = _resenas.indexWhere((x) => x.id == r.id);
        if (i >= 0) _resenas[i] = _resenas[i].conRespuesta(texto);
        _enviando.remove(r.id);
      });
      aviso(context, 'Respuesta publicada.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando.remove(r.id));
      aviso(context, mensajeError(e));
    }
  }

  Widget _cajaRespuesta(Resena r) {
    final c = _textos.putIfAbsent(r.id, TextEditingController.new);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: c,
            maxLines: 3,
            minLines: 1,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Escribe una respuesta pública…', counterText: ''),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: c.text.trim().isEmpty || _enviando.contains(r.id) ? null : () => _responder(r),
            child: const Text('Responder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _resenas.length;
    final media = total == 0 ? 0.0 : _resenas.fold<int>(0, (a, r) => a + r.estrellas) / total;
    final hace30 = DateTime.now().subtract(const Duration(days: 30));
    final esteMes = _resenas.where((r) => r.fecha.isAfter(hace30)).length;
    final reparto = <int, int>{};
    for (final r in _resenas) {
      reparto[r.estrellas] = (reparto[r.estrellas] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reseñas')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  if (total == 0)
                    EstadoVacio(
                      icono: Icons.star_outline_rounded,
                      texto: 'Aún no tienes reseñas.\nCuando finalices una cita, ${context.sector.laCliente} '
                          'podrá valorarla desde «Mis citas».',
                    )
                  else ...[
                    ResumenValoracion(
                        valoracion: Valoracion(nota: double.parse(media.toStringAsFixed(1)), total: total, reparto: reparto)),
                    if (esteMes > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('+$esteMes en los últimos 30 días',
                            style: const TextStyle(color: NailsyColors.verde, fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 14),
                    for (final r in _resenas)
                      TarjetaResena(
                        resena: r,
                        profesional: _nombre.isEmpty ? 'ti' : _nombre,
                        pie: r.respuesta == null ? _cajaRespuesta(r) : null,
                      ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Solo pueden opinar ${context.sector.lasClientes} con una cita finalizada (botón «Finalizar y cobrar»). '
                    'Puedes responder una vez; las reseñas no se pueden borrar.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
    );
  }
}
