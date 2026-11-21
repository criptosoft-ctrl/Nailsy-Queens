import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../theme.dart';
import 'horario_screen.dart';
import 'perfil_publico_screen.dart';
import 'tarifario_screen.dart';

/// "Mi cuenta": perfil público, horario, tarifario y sesión.
class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key, required this.repo, this.modoDemo = false});

  final AgendaRepo repo;
  final bool modoDemo;

  @override
  Widget build(BuildContext context) {
    Widget opcion(IconData icono, String titulo, String sub, Widget Function() destino) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: NailsyColors.superficie,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radioNailsy),
              side: const BorderSide(color: NailsyColors.borde),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(color: NailsyColors.rosaOscuro, borderRadius: BorderRadius.circular(14)),
                child: Icon(icono, color: NailsyColors.rosa),
              ),
              title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub, style: const TextStyle(color: NailsyColors.textoSecundario)),
              trailing: const Icon(Icons.chevron_right, color: NailsyColors.textoSecundario),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destino())),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          opcion(Icons.storefront_outlined, 'Mi perfil público', 'Lo que ven las clientas en el buscador',
              () => PerfilPublicoScreen(repo: repo)),
          opcion(Icons.schedule_outlined, 'Horario de trabajo', 'Los huecos que pueden reservar las clientas',
              () => HorarioScreen(repo: repo)),
          opcion(Icons.sell_outlined, 'Tarifario', 'Servicios, precios, duraciones y Nail Art',
              () => TarifarioScreen(repo: repo)),
          const SizedBox(height: 12),
          const ListTile(
            leading: Icon(Icons.info_outline, color: NailsyColors.textoSecundario),
            title: Text('GlamGo Pro'),
            subtitle: Text('Versión 0.5'),
          ),
          if (!modoDemo)
            ListTile(
              leading: const Icon(Icons.logout, color: NailsyColors.rojo),
              title: const Text('Cerrar sesión', style: TextStyle(color: NailsyColors.rojo)),
              onTap: () async {
                Navigator.popUntil(context, (r) => r.isFirst);
                await repo.cerrarSesion();
              },
            ),
        ],
      ),
    );
  }
}
