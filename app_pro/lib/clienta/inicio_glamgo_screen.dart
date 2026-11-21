import 'package:flutter/material.dart';

import '../sectores.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Portada de GlamGo: la clienta elige qué tipo de servicio quiere reservar.
/// Cada sector abre su propia sección (Nailsy Queens para uñas, Barbershop…).
class InicioGlamGoScreen extends StatelessWidget {
  const InicioGlamGoScreen({super.key, required this.alAbrir});

  /// Se llama al tocar un sector ya disponible.
  final ValueChanged<Sector> alAbrir;

  void _tocar(BuildContext context, Sector s) {
    if (s.activo) {
      alAbrir(s);
    } else {
      aviso(context, '${s.marca} llega muy pronto a GlamGo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          children: [
            const _Logo(),
            const SizedBox(height: 6),
            const Text('Reserva belleza cerca de ti, sin llamadas.',
                style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 15)),
            const SizedBox(height: 26),
            const TituloSeccion('¿Qué te apetece hoy?'),
            // Todas las secciones con el mismo tamaño, en cuadrícula de 2 columnas.
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
              children: [
                for (final s in sectores) _TarjetaSector(sector: s, onTap: () => _tocar(context, s)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Glam', style: TextStyle(color: NailsyColors.texto)),
        TextSpan(text: 'Go', style: TextStyle(color: NailsyColors.oro)),
      ]),
      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    );
  }
}

/// Tarjeta de una sección. Las disponibles van en su color; las que llegan pronto, en oscuro.
class _TarjetaSector extends StatelessWidget {
  const _TarjetaSector({required this.sector, required this.onTap});

  final Sector sector;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activo = sector.activo;
    final textoFuerte = activo ? sector.sobreColor : NailsyColors.texto;
    final textoSuave = activo ? sector.sobreColor.withValues(alpha: 0.8) : NailsyColors.textoSecundario;
    return Material(
      color: activo ? null : NailsyColors.superficie,
      borderRadius: BorderRadius.circular(radioNailsy + 2),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: activo
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [sector.color, Color.lerp(sector.color, Colors.black, 0.28)!],
                ),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: activo ? sector.sobreColor.withValues(alpha: 0.18) : sector.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(sector.icono, color: activo ? sector.sobreColor : sector.color, size: 26),
                ),
                const Spacer(),
                Text(sector.marca,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.15, color: textoFuerte)),
                const SizedBox(height: 4),
                Text(sector.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, height: 1.3, color: textoSuave)),
                const SizedBox(height: 12),
                if (activo)
                  Row(
                    children: [
                      Text('Reservar', style: TextStyle(fontWeight: FontWeight.w800, color: textoFuerte, fontSize: 15)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: textoFuerte, size: 18),
                    ],
                  )
                else
                  const Pildora(texto: 'Próximamente', color: NailsyColors.textoSecundario),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
