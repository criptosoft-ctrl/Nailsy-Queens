import 'package:flutter/material.dart';

import '../sectores.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import '../widgets/selector_idioma.dart';
import '../i18n.dart';

/// Portada de GlamGo: la clienta elige qué tipo de servicio quiere reservar.
/// Cada sector abre su propia sección (Manicura, Barbería…).
class InicioGlamGoScreen extends StatelessWidget {
  const InicioGlamGoScreen({super.key, required this.alAbrir});

  /// Se llama al tocar un sector ya disponible.
  final ValueChanged<Sector> alAbrir;

  void _tocar(BuildContext context, Sector s) {
    if (s.activo) {
      alAbrir(s);
    } else {
      aviso(context, tr('{s} llega muy pronto a GlamGo.', {'s': tr(s.marca)}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NailsyColors.fondoProfundo,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NailsyColors.fondo, NailsyColors.fondoProfundo],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const _Cabecera(),
              const SizedBox(height: 18),
              _TituloOro(tr('¿Qué te apetece hoy?')),
              const SizedBox(height: 14),
              // Todas las secciones con el mismo tamaño, en cuadrícula de 2 columnas.
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.72,
                children: [
                  for (final s in sectores) _TarjetaSector(sector: s, onTap: () => _tocar(context, s)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo "GlamGo" con el trazo dorado y el perfil de mujer a la derecha.
class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: 0,
            bottom: 0,
            child: ShaderMask(
              // Funde la imagen con el fondo por la izquierda.
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.transparent, Colors.white],
                stops: [0.0, 0.45],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset('assets/portada/cabecera.jpg', fit: BoxFit.cover, height: 190),
            ),
          ),
          Positioned(
            left: 0,
            top: 34,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Glam', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'Go', style: TextStyle(color: NailsyColors.oro)),
                  ]),
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1),
                ),
                const SizedBox(height: 4),
                CustomPaint(size: const Size(190, 14), painter: _TrazoDorado()),
                const SizedBox(height: 14),
                Text(tr('Reserva belleza cerca de ti, sin llamadas.'),
                    style: TextStyle(color: Color(0xFFD5DAE8), fontSize: 16)),
              ],
            ),
          ),
          // Idioma (ES / EN / DE), siempre a mano para los turistas.
          const Positioned(top: 10, right: 0, child: BotonIdioma()),
        ],
      ),
    );
  }
}

/// Pincelada dorada bajo el logo.
class _TrazoDorado extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pintura = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00E8B86D), NailsyColors.oro, Color(0xFFF6DDA8), Color(0x00E8B86D)],
        stops: [0.0, 0.35, 0.75, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    final w = size.width, h = size.height;
    final trazo = Path()
      ..moveTo(w * 0.05, h * 0.75)
      ..quadraticBezierTo(w * 0.5, h * 0.05, w, h * 0.25)
      ..quadraticBezierTo(w * 0.5, h * 0.35, w * 0.05, h * 0.75)
      ..close();
    canvas.drawPath(trazo, pintura);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Título de sección con la barrita dorada a la izquierda.
class _TituloOro extends StatelessWidget {
  const _TituloOro(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(color: NailsyColors.oro, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            texto.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFC9CFDF),
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de una sección: color del sector, foto a la derecha, icono redondo y botón.
class _TarjetaSector extends StatelessWidget {
  const _TarjetaSector({required this.sector, required this.onTap});

  final Sector sector;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activo = sector.activo;
    final base =
        activo ? sector.color : Color.alphaBlend(sector.color.withValues(alpha: 0.22), NailsyColors.superficie);
    final oscuro = Color.lerp(base, NailsyColors.fondoProfundo, activo ? 0.35 : 0.45)!;
    const radio = 26.0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radio),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radio),
          border: Border.all(color: Colors.white.withValues(alpha: activo ? 0.22 : 0.12)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, oscuro],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Foto decorativa a la derecha, fundida hacia la izquierda.
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 100,
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.65],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Opacity(
                    opacity: activo ? 0.95 : 0.8,
                    child: Image.asset(sector.imagen, fit: BoxFit.cover, alignment: Alignment.topCenter),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(base, Colors.black, 0.28),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Icon(sector.icono, color: Colors.white, size: 26),
                    ),
                    const Spacer(),
                    Text(
                      tr(sector.marca),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(sector.descripcion),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 1.3, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 14),
                    if (activo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(tr('Reservar'),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, color: Colors.white, size: 17),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.white.withValues(alpha: 0.10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                        ),
                        child: Text(tr('Próximamente'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD5DAE8), fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
