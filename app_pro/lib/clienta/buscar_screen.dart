import 'package:flutter/material.dart';

import '../models/publico.dart';
import '../theme.dart';
import '../ubicacion.dart';
import '../widgets/comunes.dart';
import 'clienta_repo.dart';
import 'perfil_manicurista_screen.dart';

/// Pantalla principal de la clienta: buscar manicurista por zona, estilo o cercanía.
class BuscarScreen extends StatefulWidget {
  const BuscarScreen({super.key, required this.repo, required this.alReservar});

  final ClientaRepo repo;

  /// Se llama tras una reserva para llevar a "Mis citas".
  final VoidCallback alReservar;

  @override
  State<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends State<BuscarScreen> {
  final _texto = TextEditingController();
  String? _estilo;
  ({double lat, double lng})? _cerca;
  List<ResumenManicurista> _resultados = [];
  bool _cargando = true;
  bool _localizando = false;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() => _cargando = true);
    try {
      final r = await widget.repo.buscar(texto: _texto.text, estilo: _estilo, lat: _cerca?.lat, lng: _cerca?.lng);
      if (!mounted) return;
      setState(() {
        _resultados = r;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, 'No se pudo buscar. Revisa tu conexión.');
    }
  }

  Future<void> _cercaDeMi() async {
    if (_cerca != null) {
      setState(() => _cerca = null);
      await _buscar();
      return;
    }
    setState(() => _localizando = true);
    try {
      final u = await ubicacionActual();
      if (!mounted) return;
      setState(() {
        _cerca = u;
        _texto.clear();
      });
      await _buscar();
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _localizando = false);
    }
  }

  Future<void> _abrir(ResumenManicurista m) async {
    final reservado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PerfilManicuristaScreen(repo: widget.repo, manicuristaId: m.id)),
    );
    if (reservado == true) widget.alReservar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _buscar,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nailsy Queens',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: NailsyColors.rosa)),
                      const Text('Encuentra tu manicurista y reserva al momento',
                          style: TextStyle(color: NailsyColors.textoSecundario)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _texto,
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                hintText: 'Ciudad, zona o nombre',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onSubmitted: (_) {
                                setState(() => _cerca = null);
                                _buscar();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Cerca de mí',
                            isSelected: _cerca != null,
                            onPressed: _localizando ? null : _cercaDeMi,
                            icon: _localizando
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                      if (_cerca != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Ordenadas por cercanía a ti',
                              style: TextStyle(color: NailsyColors.rosaSuave, fontSize: 13)),
                        ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: _estilo == null,
                              onSelected: (_) {
                                setState(() => _estilo = null);
                                _buscar();
                              },
                            ),
                            for (final e in estilosBuscables.entries)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ChoiceChip(
                                  label: Text(e.value),
                                  selected: _estilo == e.key,
                                  onSelected: (v) {
                                    setState(() => _estilo = v ? e.key : null);
                                    _buscar();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (_cargando)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (_resultados.isEmpty)
                const SliverToBoxAdapter(
                  child: EstadoVacio(
                    icono: Icons.search_off,
                    texto: 'No hemos encontrado manicuristas con esos filtros.\nPrueba con otra zona o estilo.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: _resultados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _TarjetaManicurista(
                      m: _resultados[i],
                      repo: widget.repo,
                      onTap: () => _abrir(_resultados[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaManicurista extends StatelessWidget {
  const _TarjetaManicurista({required this.m, required this.repo, required this.onTap});

  final ResumenManicurista m;
  final ClientaRepo repo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fotos = m.fotos.isEmpty ? <String?>[null] : m.fotos;
    final datos = [
      if (m.ciudad != null) m.ciudad!,
      if (m.distanciaKm != null)
        m.distanciaKm! < 1 ? 'a ${(m.distanciaKm! * 1000).round()} m' : 'a ${m.distanciaKm!.toStringAsFixed(1)} km',
    ].join(' · ');
    return Material(
      color: NailsyColors.superficie,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrusel de trabajos
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView(
                    children: [for (final f in fotos) FotoRemota(url: repo.urlFoto(f))],
                  ),
                  if (fotos.length > 1)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: Text('${fotos.length} fotos ›',
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: FotoRemota(url: repo.urlFoto(m.foto), icono: Icons.person_outline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        if (datos.isNotEmpty)
                          Text(datos, style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                        if (m.especialidades.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final e in m.especialidades.take(3))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: NailsyColors.rosa.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(estilosBuscables[e] ?? e,
                                      style: const TextStyle(color: NailsyColors.rosaSuave, fontSize: 12)),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (m.precioDesde != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('desde', style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 12)),
                        Text(precio(m.precioDesde!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
