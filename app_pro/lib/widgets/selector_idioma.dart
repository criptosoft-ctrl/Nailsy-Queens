import 'package:flutter/material.dart';

import '../i18n.dart';
import '../theme.dart';

/// Abre la hoja para elegir idioma (Español, English, Deutsch).
Future<void> mostrarSelectorIdioma(BuildContext context) async {
  final elegido = await showModalBottomSheet<Idioma>(
    context: context,
    backgroundColor: NailsyColors.superficie,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(tr('Idioma'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final i in Idioma.values)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: NailsyColors.superficieAlta,
                  child: Text(i.corto,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: NailsyColors.oro)),
                ),
                title: Text(i.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: i == idiomaActual.value ? const Icon(Icons.check_circle, color: NailsyColors.oro) : null,
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    ),
  );
  if (elegido != null) await elegirIdioma(elegido);
}

/// Botoncito "ES ▾" para la cabecera de la portada.
class BotonIdioma extends StatelessWidget {
  const BotonIdioma({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('Idioma'),
      child: Material(
      color: NailsyColors.fondoProfundo.withValues(alpha: 0.6),
      shape: StadiumBorder(side: BorderSide(color: NailsyColors.oro.withValues(alpha: 0.5))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => mostrarSelectorIdioma(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, size: 16, color: NailsyColors.oro),
              const SizedBox(width: 6),
              Text(idiomaActual.value.corto,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: NailsyColors.texto)),
              const Icon(Icons.expand_more, size: 16, color: NailsyColors.textoSecundario),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
