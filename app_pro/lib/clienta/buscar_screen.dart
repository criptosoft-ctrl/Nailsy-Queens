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
  const BuscarScreen(
      {super.key, required this.repo, required this.alReservar, this.sector = 'nails', this.alVolver});

  final ClientaRepo repo;

  /// Sector de GlamGo que se está buscando (uñas, barbería…).
  final String sector;

  /// Vuelve a la portada de GlamGo (si es null no se muestra la flecha).
  final VoidCallback? alVolver;

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

  Sector get _sector => sectorPorId(widget.sector);
  Color get _acento => Theme.of(context).colorScheme.primary;
  Color get _sobreAcento => Theme.of(context).colorScheme.onPrimary;

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

  /// Quita todos los filtros y vuelve a buscar.
  void _restablecer() {
    _texto.clear();
    setState(() {
      _soloHoy = false;
      _estilo = null;
      _cerca = null;
    });
    _buscar();
  }

  Widget _chip(String texto, bool sel, VoidCallback onTap, {Widget? icono}) {
    // Activo: fondo del color de la sección. Resto: oscuro con borde sutil.
    return Material(
      color: sel ? _acento : NailsyColors.barraNavegacion,
      shape: StadiumBorder(side: BorderSide(color: sel ? _acento : NailsyColors.borde)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[icono, const SizedBox(width: 6)],
              Text(texto,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: sel ? _sobreAcento : const Color(0xFFE4E8F2))),
            ],
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
                          if (widget.alVolver != null) ...[
                            // Flecha atrás discreta: círculo fino.
                            Tooltip(
                              message: 'Volver a GlamGo',
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(side: BorderSide(color: NailsyColors.borde)),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: widget.alVolver,
                                  child: const SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: Icon(Icons.chevron_left, color: NailsyColors.textoSecundario, size: 24),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_sector.marca,
                                    style: TextStyle(
                                        fontSize: 26, height: 1.1, fontWeight: FontWeight.w800, color: _acento)),
                                const SizedBox(height: 2),
                                Text(_sector.lema,
                                    style: const TextStyle(fontSize: 14, color: NailsyColors.textoSecundario)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _texto,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '${_mayuscula(_sector.profesional)}, estilo o zona',
                          prefixIcon: Icon(Icons.search, color: _acento),
                          filled: true,
                          fillColor: NailsyColors.superficie,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: NailsyColors.borde),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: _acento, width: 1.5),
                          ),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                      for (final e in _sector.estilos.entries)
                        _chip(e.value, _estilo == e.key, () {
                          setState(() => _estilo = _estilo == e.key ? null : e.key);
                          _buscar();
                        }),
                    ],
                  ),
                ),
              ),
              if (!_cargando && _resultados.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text(
                      '${_resultados.length} ${_resultados.length == 1 ? _sector.profesional : '${_sector.profesional}s'}'
                      '${_cerca != null ? ' · por cercanía' : ''}',
                      style: const TextStyle(fontSize: 13, color: NailsyColors.textoSecundario),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              if (_cargando)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (_resultados.isEmpty)
                SliverToBoxAdapter(
                  child: _SinResultados(
                    sector: _sector,
                    soloHoy: _soloHoy,
                    alRestablecer: _restablecer,
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

/// "Hoy · 14:00", "Mañana · 09:00", "Lun 24 · 09:30"… (tarjeta del buscador).
String textoDisponible(DateTime h, DateTime ahora) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final d = DateTime(h.year, h.month, h.day);
  final hora = DateFormat('HH:mm').format(h);
  if (d == hoy) return 'Hoy · $hora';
  if (d == hoy.add(const Duration(days: 1))) return 'Mañana · $hora';
  final dia = DateFormat('EEE d', 'es').format(h).replaceAll('.', '');
  return '${dia[0].toUpperCase()}${dia.substring(1)} · $hora';
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
    final distancia = m.distanciaKm == null
        ? null
        : m.distanciaKm! < 1
            ? 'A ${(m.distanciaKm! * 1000).round()} m'
            : 'A ${m.distanciaKm!.toStringAsFixed(1).replaceAll('.', ',')} km';
    final acento = Theme.of(context).colorScheme.primary;
    final acentoSuave = Theme.of(context).colorScheme.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: NailsyColors.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: NailsyColors.borde),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FotoRemota(url: repo.urlFoto(m.fotos.isNotEmpty ? m.fotos.first : m.foto)),
                      if (distancia != null)
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: NailsyColors.fondoProfundo.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.place_outlined, size: 14, color: NailsyColors.texto),
                                const SizedBox(width: 4),
                                Text(distancia,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      if (m.ciudad != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 16, color: NailsyColors.textoSecundario),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(m.ciudad!,
                                  style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
                      if (m.especialidades.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in m.especialidades.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: acento.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(etiquetaEstilo(e),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: acentoSuave)),
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
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: m.proximoHueco == null
                                            ? NailsyColors.textoSecundario
                                            : NailsyColors.verde,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        m.proximoHueco == null
                                            ? 'Sin huecos próximos'
                                            : textoDisponible(m.proximoHueco!, DateTime.now()),
                                        style: TextStyle(
                                          color: m.proximoHueco == null
                                              ? NailsyColors.textoSecundario
                                              : NailsyColors.verde,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (m.precioDesde != null) ...[
                                  const SizedBox(height: 4),
                                  Text.rich(TextSpan(children: [
                                    const TextSpan(
                                        text: 'Desde ',
                                        style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                                    TextSpan(
                                        text: precio(m.precioDesde!),
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                    if (m.duracionDesde != null)
                                      TextSpan(
                                          text: ' · ${duracionCorta(Duration(minutes: m.duracionDesde!))}',
                                          style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                                  ])),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: onTap,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Reservar'),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
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


/// Pantalla de "sin resultados": ilustración dorada de la sección, mensaje y botón para quitar filtros.
class _SinResultados extends StatelessWidget {
  const _SinResultados({required this.sector, required this.soloHoy, required this.alRestablecer});

  final Sector sector;
  final bool soloHoy;
  final VoidCallback alRestablecer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: ShaderMask(
              // Funde los bordes de la ilustración con el fondo.
              shaderCallback: (r) => const RadialGradient(
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.78, 1.0],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset(sector.imagenVacio, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No hemos encontrado ${sector.profesional}s con esos filtros.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            soloHoy ? 'Quita «Hoy» para ver los próximos días.' : 'Prueba con otra zona o estilo.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: NailsyColors.textoSecundario),
          ),
          const SizedBox(height: 26),
          OutlinedButton.icon(
            onPressed: alRestablecer,
            style: OutlinedButton.styleFrom(
              foregroundColor: NailsyColors.texto,
              side: const BorderSide(color: NailsyColors.oro, width: 1.5),
              minimumSize: const Size(0, 54),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.refresh_rounded, color: NailsyColors.oro),
            label: const Text('Restablecer filtros'),
          ),
        ],
      ),
    );
  }
}
