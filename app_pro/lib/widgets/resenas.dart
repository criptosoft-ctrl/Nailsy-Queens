import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../i18n.dart';
import '../models/publico.dart';
import '../theme.dart';

/// Nota con un decimal en el idioma de la app: 4,9 / 4.9.
String textoNota(double n) => NumberFormat('0.0', codigoIdioma).format(n);

/// Fila de estrellas (llenas hasta [valor]).
class Estrellas extends StatelessWidget {
  const Estrellas({super.key, required this.valor, this.tamano = 14});

  final int valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= valor ? Icons.star_rounded : Icons.star_outline_rounded,
              size: tamano, color: i <= valor ? NailsyColors.oro : NailsyColors.borde),
      ],
    );
  }
}

/// "★ 4,9 (23)" o, si aún no tiene reseñas, "Nueva en GlamGo".
class InsigniaNota extends StatelessWidget {
  const InsigniaNota({super.key, required this.valoracion});

  final Valoracion valoracion;

  @override
  Widget build(BuildContext context) {
    final v = valoracion;
    if (!v.hay) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NailsyColors.borde),
        ),
        child: Text(tr('Nueva en GlamGo'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NailsyColors.textoSecundario)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NailsyColors.oro.withValues(alpha: 0.14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: NailsyColors.oro),
          const SizedBox(width: 3),
          Text(textoNota(v.nota!),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NailsyColors.oro)),
          const SizedBox(width: 3),
          Text('(${v.total})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NailsyColors.textoSecundario)),
        ],
      ),
    );
  }
}

/// Resumen: nota grande, estrellas y barras por número de estrellas.
class ResumenValoracion extends StatelessWidget {
  const ResumenValoracion({super.key, required this.valoracion});

  final Valoracion valoracion;

  @override
  Widget build(BuildContext context) {
    final v = valoracion;
    final maximo = v.reparto.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NailsyColors.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NailsyColors.borde),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Column(
              children: [
                Text(textoNota(v.nota ?? 0),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: NailsyColors.oro, height: 1)),
                const SizedBox(height: 6),
                Estrellas(valor: (v.nota ?? 0).round(), tamano: 14),
                const SizedBox(height: 4),
                Text(tr('{n} reseñas', {'n': v.total}),
                    style: const TextStyle(fontSize: 12, color: NailsyColors.textoSecundario)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (var e = 5; e >= 1; e--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 12,
                            child: Text('$e', style: const TextStyle(fontSize: 12, color: NailsyColors.textoSecundario))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: maximo == 0 ? 0 : (v.reparto[e] ?? 0) / maximo,
                              minHeight: 6,
                              color: NailsyColors.oro,
                              backgroundColor: NailsyColors.borde,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 22,
                          child: Text('${v.reparto[e] ?? 0}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: NailsyColors.textoSecundario)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una reseña con su respuesta (si la hay).
class TarjetaResena extends StatelessWidget {
  const TarjetaResena({super.key, required this.resena, required this.profesional, this.pie});

  final Resena resena;

  /// Nombre de la profesional, para "Respuesta de …".
  final String profesional;

  /// Contenido extra al final (en GlamGo Pro: la caja para responder).
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final r = resena;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NailsyColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NailsyColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: NailsyColors.borde,
                child: Text(r.autor.isEmpty ? '?' : r.autor[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.autor, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      [
                        DateFormat.MMMd(codigoIdioma).format(r.fecha),
                        if (r.servicio != null) r.servicio! else tr('Cita verificada'),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: NailsyColors.textoSecundario),
                    ),
                  ],
                ),
              ),
              Estrellas(valor: r.estrellas, tamano: 14),
            ],
          ),
          if (r.comentario != null) ...[
            const SizedBox(height: 10),
            Text(r.comentario!, style: const TextStyle(height: 1.45)),
          ],
          if (r.respuesta != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NailsyColors.fondo,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: context.acento, width: 3)),
              ),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${tr('Respuesta de {n}:', {'n': profesional})} ',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                  TextSpan(text: r.respuesta),
                ]),
                style: const TextStyle(fontSize: 13.5, color: NailsyColors.textoSecundario, height: 1.4),
              ),
            ),
          ],
          if (pie != null) pie!,
        ],
      ),
    );
  }
}
