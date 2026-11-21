import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/publico.dart';
import '../sectores.dart';
import '../theme.dart';
import '../ubicacion.dart';
import '../widgets/comunes.dart';
import 'clienta_repo.dart';
import 'perfil_manicurista_screen.dart';

/// Pantalla principal de la clienta ("Descubrir"): buscar manicurista por zona, estilo,
/// cercanía o disponibilidad hoy.
class BuscarScreen extends StatefulWidget {
  const BuscarScreen({super.key, required this.repo, required this.alReservar, this.sector = 'nails'});

  final ClientaRepo repo;

  /// Sector de GlamGo que se está buscando (uñas, barbería…).
  final String sector;

  /// Se llama tras una reserva para llevar a "Mis citas".
  final VoidCallback alReservar;

  @override
  State<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends State<BuscarScreen> {
  final _texto = TextEditingController();
  String? _estilo;
  bool _soloHoy = false;
  ({double lat, double lng})? _cerca;
  List<ResumenManicurista> _resultados = [];
  bool _cargando = true;
  bool _localizando = false;

  static const _estilos = {
    'rusa': 'Rusa',
    'gel': 'Gel',
    'acrilico': 'Acrílico',
    'semipermanente': 'Semipermanente',
    'nail_art': 'Nail Art',
    'pedicura': 'Pedicura',
  };

  Sector get _sector => sectorPorId(widget.sector);

  static String _mayuscula(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

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
      final r = await widget.repo.buscar(
        texto: _texto.text,
        estilo: _estilo,
        lat: _cerca?.lat,
        lng: _cerca?.lng,
        soloHoy: _soloHoy,
        sector: widget.sector,
      );
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

  Widget _chip(String texto, bool sel, VoidCallback onTap, {Widget? icono}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: sel ? NailsyColors.rosa : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: sel ? NailsyColors.rosa : NailsyColors.borde)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icono != null) ...[icono, const SizedBox(width: 6)],
                Text(texto,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: sel ? NailsyColors.sobreRosa : NailsyColors.texto)),
              ],
            ),
          ),
        ),
      ),
    );
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (Navigator.canPop(context)) ...[
                            BotonCuadrado(
                              icono: Icons.arrow_back,
                              tooltip: 'Volver a GlamGo',
                              onTap: () => Navigator.maybePop(context),
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Text(_sector.marca,
                                style: const TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.w800, color: NailsyColors.rosa)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _texto,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '${_mayuscula(_sector.profesional)}, estilo o zona',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) {
                          setState(() => _cerca = null);
                          _buscar();
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _chip('Hoy', _soloHoy, () {
                        setState(() => _soloHoy = !_soloHoy);
                        _buscar();
                      }),
                      _chip(
                        'Cerca de mí',
                        _cerca != null,
                        _localizando ? () {} : _cercaDeMi,
                        icono: _localizando
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                      ),
                      if (widget.sector == 'nails')
                      for (final e in _estilos.entries)
                        _chip(e.value, _estilo == e.key, () {
                          setState(() => _estilo = _estilo == e.key ? null : e.key);
                          _buscar();
                        }),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              if (_cargando)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (_resultados.isEmpty)
                SliverToBoxAdapter(
                  child: EstadoVacio(
                    icono: Icons.search_off,
                    texto: _soloHoy
                        ? 'Nadie tiene huecos libres hoy con esos filtros.\nQuita "Hoy" para ver los próximos días.'
                        : 'No hemos encontrado manicuristas con esos filtros.\nPrueba con otra zona o estilo.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: _resultados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 26),
                    itemBuilder: (_, i) => _BloqueManicurista(
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

/// "Libre hoy a las 14:00", "Libre mañana a las 10:00", "Libre lun 24 a las 9:30"…
String textoProximoHueco(DateTime h, DateTime ahora) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final d = DateTime(h.year, h.month, h.day);
  final hora = DateFormat('HH:mm').format(h);
  if (d == hoy) return 'Libre hoy a las $hora';
  if (d == hoy.add(const Duration(days: 1))) return 'Libre mañana a las $hora';
  return 'Libre el ${DateFormat('EEE d', 'es').format(h).replaceAll('.', '')} a las $hora';
}

class _BloqueManicurista extends StatelessWidget {
  const _BloqueManicurista({required this.m, required this.repo, required this.onTap});

  final ResumenManicurista m;
  final ClientaRepo repo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final otras = m.fotos.length > 1 ? m.fotos.sublist(1) : const <String>[];
    final datos = [
      if (m.ciudad != null) m.ciudad!,
      if (m.distanciaKm != null)
        m.distanciaKm! < 1 ? 'a ${(m.distanciaKm! * 1000).round()} m' : 'a ${m.distanciaKm!.toStringAsFixed(1)} km',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: NailsyColors.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: NailsyColors.borde),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: FotoRemota(url: repo.urlFoto(m.fotos.isNotEmpty ? m.fotos.first : m.foto)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.nombre, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                      if (datos.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 16, color: NailsyColors.textoSecundario),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(datos,
                                  style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
                      if (m.especialidades.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in m.especialidades.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: NailsyColors.superficieAlta,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(estilosBuscables[e] ?? e,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.proximoHueco == null
                                      ? 'Sin huecos en los próximos días'
                                      : textoProximoHueco(m.proximoHueco!, DateTime.now()),
                                  style: TextStyle(
                                    color: m.proximoHueco == null ? NailsyColors.textoSecundario : NailsyColors.verde,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                if (m.precioDesde != null) ...[
                                  const SizedBox(height: 2),
                                  Text.rich(TextSpan(children: [
                                    const TextSpan(
                                        text: 'Desde  ', style: TextStyle(color: NailsyColors.textoSecundario)),
                                    TextSpan(
                                        text: precio(m.precioDesde!),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                  ])),
                                ],
                              ],
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                            ),
                            onPressed: onTap,
                            child: const Text('Reservar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (otras.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Más trabajos de ${m.nombre.split(' ').first}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: otras.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: 92, child: FotoRemota(url: repo.urlFoto(otras[i]))),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
