import 'package:flutter/material.dart';

import '../models/catalogo.dart';
import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'clienta_repo.dart';
import 'reservar_screen.dart';

/// Perfil de una manicurista tal como lo ve la clienta. Devuelve `true` si se reservó.
class PerfilManicuristaScreen extends StatefulWidget {
  const PerfilManicuristaScreen({super.key, required this.repo, required this.manicuristaId});

  final ClientaRepo repo;
  final String manicuristaId;

  @override
  State<PerfilManicuristaScreen> createState() => _PerfilManicuristaScreenState();
}

class _PerfilManicuristaScreenState extends State<PerfilManicuristaScreen> {
  PerfilPublico? _p;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final p = await widget.repo.perfil(widget.manicuristaId);
      if (!mounted) return;
      setState(() {
        _p = p;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _reservar(Servicio s) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReservarScreen(repo: widget.repo, perfil: _p!, servicio: s)),
    );
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  void _verFoto(int inicial) {
    final fotos = _p!.fotos;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: PageView(
            controller: PageController(initialPage: inicial),
            children: [
              for (final f in fotos)
                InteractiveViewer(child: Center(child: FotoRemota(url: widget.repo.urlFoto(f), fit: BoxFit.contain))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final p = _p;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVacio(icono: Icons.storefront_outlined, texto: 'Este perfil ya no está disponible.'),
      );
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  FotoRemota(url: widget.repo.urlFoto(p.fotos.isNotEmpty ? p.fotos.first : p.foto)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xDD17121A)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            sliver: SliverList.list(
              children: [
                if (p.ciudad != null || p.direccion != null)
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 18, color: NailsyColors.rosaSuave),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text([p.direccion, p.ciudad].whereType<String>().join(', '),
                            style: const TextStyle(color: NailsyColors.textoSecundario)),
                      ),
                    ],
                  ),
                if (p.instagram != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 18, color: NailsyColors.rosaSuave),
                      const SizedBox(width: 6),
                      Text('@${p.instagram}', style: const TextStyle(color: NailsyColors.textoSecundario)),
                    ],
                  ),
                ],
                if (p.bio != null) ...[
                  const SizedBox(height: 12),
                  Text(p.bio!, style: const TextStyle(height: 1.4)),
                ],
                if (p.fotos.isNotEmpty) ...[
                  const TituloSeccion('Trabajos'),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: p.fotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _verFoto(i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(width: 120, child: FotoRemota(url: widget.repo.urlFoto(p.fotos[i]))),
                        ),
                      ),
                    ),
                  ),
                ],
                const TituloSeccion('Servicios'),
                if (p.servicios.isEmpty)
                  const Text('Todavía no ha publicado servicios.', style: TextStyle(color: NailsyColors.textoSecundario)),
                for (final s in p.servicios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Tarjeta(
                      onTap: () => _reservar(s),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                Text(formatoDuracion(s.duracionMin),
                                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(precio(s.precio), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(width: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                            onPressed: () => _reservar(s),
                            child: const Text('Reservar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (p.anadidos.isNotEmpty) ...[
                  const TituloSeccion('Nail Art y extras'),
                  for (final a in p.anadidos)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(a.nombre)),
                          Text('+${precio(a.precio)}${a.porUna ? '/uña' : ''}',
                              style: const TextStyle(color: NailsyColors.textoSecundario)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Cancelación gratuita hasta ${p.horasCancelacion} h antes de la cita.',
                  style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
