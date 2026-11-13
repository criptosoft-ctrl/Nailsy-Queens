import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../theme.dart';
import 'agenda_screen.dart';
import 'clientas_screen.dart';
import 'horario_screen.dart';
import 'perfil_publico_screen.dart';
import 'portafolio_screen.dart';
import 'tarifario_screen.dart';

/// Pantalla principal con la barra inferior: Agenda · Clientas · Portafolio · Ajustes.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repo, this.modoDemo = false});

  final AgendaRepo repo;
  final bool modoDemo;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  int _visitas = 0; // fuerza recargar Clientas/Tarifario al volver a la pestaña

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      AgendaScreen(repo: widget.repo),
      ClientasScreen(key: ValueKey('clientas-$_visitas'), repo: widget.repo),
      PortafolioScreen(key: ValueKey('portafolio-$_visitas'), repo: widget.repo),
      TarifarioScreen(key: ValueKey('tarifario-$_visitas'), repo: widget.repo),
      _Ajustes(repo: widget.repo, modoDemo: widget.modoDemo),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (widget.modoDemo)
            Container(
              width: double.infinity,
              color: NailsyColors.ambar,
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 4, bottom: 4),
              child: const Text(
                'MODO DEMO · datos de ejemplo',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: widget.modoDemo,
              child: IndexedStack(index: _tab, children: pantallas),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          if (i != _tab) _visitas++;
          _tab = i;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clientas'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Portafolio'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), label: 'Tarifario'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class _Ajustes extends StatelessWidget {
  const _Ajustes({required this.repo, required this.modoDemo});

  final AgendaRepo repo;
  final bool modoDemo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storefront_outlined, color: NailsyColors.rosa),
            title: const Text('Mi perfil público'),
            subtitle: const Text('Lo que ven las clientas en el buscador'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PerfilPublicoScreen(repo: repo))),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined, color: NailsyColors.rosa),
            title: const Text('Horario de trabajo'),
            subtitle: const Text('Los huecos que pueden reservar las clientas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HorarioScreen(repo: repo))),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Nailsy Queens Pro'),
            subtitle: Text('Versión 0.3'),
          ),
          if (!modoDemo)
            ListTile(
              leading: const Icon(Icons.logout, color: NailsyColors.rojo),
              title: const Text('Cerrar sesión'),
              onTap: repo.cerrarSesion,
            ),
        ],
      ),
    );
  }
}
