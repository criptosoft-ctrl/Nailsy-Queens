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

  void _verImagen(List<String> rutas, int inicial) {
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
              for (final f in rutas)
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
    final urlPerfil = widget.repo.urlFoto(p.foto);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList.list(
              children: [
                // ---- Foto de perfil y datos ----
                Center(
                  child: GestureDetector(
                    onTap: urlPerfil == null ? null : () => _verImagen([p.foto!], 0),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [NailsyColors.rosa, NailsyColors.rosaSuave]),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 118,
                          height: 118,
                          child: FotoRemota(url: urlPerfil, icono: Icons.person_outline),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(p.nombre,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                if (p.ciudad != null || p.direccion != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.place_outlined, size: 16, color: NailsyColors.rosaSuave),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text([p.direccion, p.ciudad].whereType<String>().join(', '),
                            textAlign: TextAlign.center, style: const TextStyle(color: NailsyColors.textoSecundario)),
                      ),
                    ],
                  ),
                ],
                if (p.instagram != null) ...[
                  const SizedBox(height: 2),
                  Text('@${p.instagram}',
                      textAlign: TextAlign.center, style: const TextStyle(color: NailsyColors.rosaSuave)),
                ],
                if (p.especialidades.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in p.especialidades)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: NailsyColors.rosa.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(estilosBuscables[e] ?? e,
                              style: const TextStyle(color: NailsyColors.rosaSuave, fontSize: 12)),
                        ),
                    ],
                  ),
                ],
                if (p.bio != null) ...[
                  const SizedBox(height: 12),
                  Text(p.bio!, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
                ],

                // ---- Trabajos ----
                if (p.fotos.isNotEmpty) ...[
                  TituloSeccion('Trabajos (${p.fotos.length})'),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                    itemCount: p.fotos.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _verImagen(p.fotos, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FotoRemota(url: widget.repo.urlFoto(p.fotos[i])),
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
