import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/agenda_repo.dart';
import '../theme.dart';

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
String mensajeError(Object e) => e is ErrorNailsy ? e.mensaje : 'Algo ha fallado. Inténtalo de nuevo.';

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
