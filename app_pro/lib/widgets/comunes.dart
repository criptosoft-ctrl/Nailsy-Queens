import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/agenda_repo.dart';
import '../theme.dart';
import '../i18n.dart';

final euros = NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2);

/// "35 €" si es redondo, "35,50 €" si no.
String precio(double v) => v == v.roundToDouble()
    ? NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0).format(v)
    : euros.format(v);

void aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Traduce cualquier error a un mensaje para la manicurista.
String mensajeError(Object e) {
  if (e is ErrorNailsy) return tr(e.mensaje);
  // Mientras probamos, enseñamos el motivo técnico para poder arreglarlo.
  if (e is StorageException) return 'Error al guardar el archivo (${e.statusCode ?? '-'}): ${e.message}';
  if (e is PostgrestException) return 'Error de la base de datos (${e.code ?? '-'}): ${e.message}';
  if (e is AuthException) return 'Error de sesión: ${e.message}';
  return 'Algo ha fallado: $e';
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Icon(icono, size: 48, color: NailsyColors.gris),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: NailsyColors.textoSecundario)),
          if (accion != null) ...[const SizedBox(height: 16), accion!],
        ],
      ),
    );
  }
}

/// Aviso rojo de alergias (se ve en agenda, clientas y al crear cita).
class AvisoAlergia extends StatelessWidget {
  const AvisoAlergia({super.key, required this.alergias, this.compacto = false});

  final List<String> alergias;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    if (alergias.isEmpty) return const SizedBox.shrink();
    final texto = 'Alergia: ${alergias.join(', ')}';
    if (compacto) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: NailsyColors.rojo.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 14, color: NailsyColors.rojo),
            const SizedBox(width: 4),
            Text(texto, style: const TextStyle(color: NailsyColors.rojo, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NailsyColors.rojo.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NailsyColors.rojo),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: NailsyColors.rojo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(color: NailsyColors.rojo, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.trailing});

  final String texto;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(texto.toUpperCase(),
                style: const TextStyle(
                    color: NailsyColors.textoSecundario, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NailsyColors.superficie,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Lee un número escrito con coma o punto ("12,5" → 12.5).
double? leerNumero(String? s) => s == null ? null : double.tryParse(s.trim().replaceAll(',', '.'));

/// Foto remota con fondo de marca mientras carga o si no hay foto.
class FotoRemota extends StatelessWidget {
  const FotoRemota({super.key, required this.url, this.fit = BoxFit.cover, this.icono = Icons.spa_outlined});

  final String? url;
  final BoxFit fit;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final fondo = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Theme.of(context).colorScheme.primary.withValues(alpha: 0.18), NailsyColors.superficie),
            NailsyColors.superficie,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icono, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6), size: 32),
    );
    if (url == null) return fondo;
    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, __, ___) => fondo,
      loadingBuilder: (_, child, progreso) => progreso == null ? child : fondo,
    );
  }
}

/// Selector de hora con ruedas (horas y minutos), en 24 h y de 5 en 5 minutos.
Future<TimeOfDay?> elegirHoraRueda(BuildContext context, {TimeOfDay? inicial, String titulo = 'Elige la hora'}) {
  final base = inicial ?? const TimeOfDay(hour: 10, minute: 0);
  var elegida = TimeOfDay(hour: base.hour, minute: (base.minute ~/ 5) * 5);
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: NailsyColors.superficie,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(color: NailsyColors.texto, fontSize: 24),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  minuteInterval: 5,
                  initialDateTime: DateTime(2000, 1, 1, elegida.hour, elegida.minute),
                  onDateTimeChanged: (d) => elegida = TimeOfDay(hour: d.hour, minute: d.minute),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(ctx, elegida), child: const Text('Aceptar')),
          ],
        ),
      ),
    ),
  );
}

/// Iniciales de un nombre ("Marta Gómez" → "MG").
String inicialesDe(String nombre) {
  final p = nombre.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  if (p.length == 1) return p.first[0].toUpperCase();
  return (p[0][0] + p[1][0]).toUpperCase();
}

/// Cuadrado redondeado con las iniciales (como en el diseño).
class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales({super.key, required this.nombre, this.tam = 56});

  final String nombre;
  final double tam;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tam,
      height: tam,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tam * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Theme.of(context).colorScheme.primary.withValues(alpha: 0.30), NailsyColors.superficie),
            Color.alphaBlend(Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), NailsyColors.superficie),
          ],
        ),
      ),
      child: Text(inicialesDe(nombre),
          style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w800, fontSize: tam * 0.36)),
    );
  }
}

/// Etiqueta redondeada de color (estado, alergia, pago…).
class Pildora extends StatelessWidget {
  const Pildora({super.key, required this.texto, required this.color, this.icono, this.fondo});

  final String texto;
  final Color color;
  final IconData? icono;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 14, color: color), const SizedBox(width: 5)],
          Flexible(
            child: Text(texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Botón cuadrado de icono (cabeceras).
class BotonCuadrado extends StatelessWidget {
  const BotonCuadrado({super.key, required this.icono, required this.onTap, this.relleno = false, this.tooltip});

  final IconData icono;
  final VoidCallback onTap;
  final bool relleno;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final boton = Material(
      color: relleno ? Theme.of(context).colorScheme.primary : NailsyColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: relleno ? BorderSide.none : const BorderSide(color: NailsyColors.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icono, color: relleno ? Theme.of(context).colorScheme.onPrimary : NailsyColors.texto, size: relleno ? 28 : 24),
        ),
      ),
    );
    return tooltip == null ? boton : Tooltip(message: tooltip!, child: boton);
  }
}

/// Texto de duración corto: 90 → "1 h 30 min", 60 → "1 h".
String duracionCorta(Duration d) {
  final h = d.inMinutes ~/ 60, m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Consejo práctico para trabajar con una clienta alérgica.
String? consejoAlergia(List<String> alergias) {
  final a = alergias.map((e) => e.toLowerCase()).toSet();
  final consejos = <String>[
    if (a.contains('acrilatos') || a.contains('hema'))
      'El gel de nivelación y muchos geles llevan acrilatos. Usa un producto sin HEMA o confírmalo con la clienta antes de empezar.',
    if (a.contains('latex')) 'Usa guantes de nitrilo, nunca de látex.',
    if (a.contains('quitaesmalte')) 'Retira con limado o un removedor sin acetona.',
    if (a.contains('niquel')) 'Usa herramientas de acero quirúrgico o titanio y evita decoraciones metálicas.',
    if (a.contains('ppd')) 'Nada de tintes con PPD: usa uno sin PPD y haz la prueba de alergia 48 h antes.',
    if (a.contains('fragancias')) 'Usa after-shave, bálsamo y productos sin perfume.',
    if (a.contains('alcohol')) 'Evita lociones con alcohol; usa aloe o un bálsamo calmante.',
  ];
  return consejos.isEmpty ? null : consejos.join(' ');
}

/// Línea horizontal discontinua.
class LineaDiscontinua extends StatelessWidget {
  const LineaDiscontinua({super.key, this.color = NailsyColors.borde});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(double.infinity, 1), painter: _PintorLinea(color));
  }
}

class _PintorLinea extends CustomPainter {
  _PintorLinea(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(_PintorLinea old) => old.color != color;
}

/// Contenedor con borde redondeado discontinuo (huecos libres, "añadir foto").
class BordeDiscontinuo extends StatelessWidget {
  const BordeDiscontinuo({super.key, required this.child, this.radio = 18, this.color = NailsyColors.borde});

  final Widget child;
  final double radio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PintorBorde(radio, color), child: child);
  }
}

class _PintorBorde extends CustomPainter {
  _PintorBorde(this.radio, this.color);
  final double radio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radio));
    final camino = Path()..addRRect(rr.deflate(0.75));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in camino.computeMetrics()) {
      for (double d = 0; d < m.length; d += 11) {
        canvas.drawPath(m.extractPath(d, (d + 6).clamp(0, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorBorde old) => old.radio != radio || old.color != color;
}
