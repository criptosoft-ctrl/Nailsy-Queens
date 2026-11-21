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
    final principal = sectores.where((s) => s.activo).toList();
    final proximos = sectores.where((s) => !s.activo).toList();
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
            for (final s in principal) ...[
              _TarjetaPrincipal(sector: s, onTap: () => _tocar(context, s)),
              const SizedBox(height: 14),
            ],
            for (final s in proximos) ...[
              _TarjetaProxima(sector: s, onTap: () => _tocar(context, s)),
              const SizedBox(height: 12),
            ],
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
        TextSpan(text: 'Go', style: TextStyle(color: NailsyColors.rosa)),
      ]),
      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    );
  }
}

class _TarjetaPrincipal extends StatelessWidget {
  const _TarjetaPrincipal({required this.sector, required this.onTap});

  final Sector sector;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(radioNailsy + 4),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [NailsyColors.rosa, Color(0xFFB8336F)],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: NailsyColors.sobreRosa.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(sector.icono, color: NailsyColors.sobreRosa, size: 28),
                    ),
                    const Spacer(),
                    Pildora(texto: sector.nombre, color: NailsyColors.sobreRosa, fondo: Colors.white24),
                  ],
                ),
                const SizedBox(height: 26),
                Text(sector.marca,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: NailsyColors.sobreRosa)),
                const SizedBox(height: 4),
                Text(sector.descripcion,
                    style: TextStyle(fontSize: 15, color: NailsyColors.sobreRosa.withValues(alpha: 0.8))),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Text('Reservar',
                        style: TextStyle(fontWeight: FontWeight.w800, color: NailsyColors.sobreRosa, fontSize: 16)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, color: NailsyColors.sobreRosa, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaProxima extends StatelessWidget {
  const _TarjetaProxima({required this.sector, required this.onTap});

  final Sector sector;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NailsyColors.superficie,
      borderRadius: BorderRadius.circular(radioNailsy),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: NailsyColors.superficieAlta,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(sector.icono, color: NailsyColors.textoSecundario),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sector.marca, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sector.descripcion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Pildora(texto: 'Próximamente', color: NailsyColors.ambar),
            ],
          ),
        ),
      ),
    );
  }
}
