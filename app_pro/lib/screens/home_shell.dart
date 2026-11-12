import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../theme.dart';
import 'agenda_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      AgendaScreen(repo: widget.repo),
      const _Proximamente(titulo: 'Clientas', texto: 'Fichas de clientas y de la uña'),
      const _Proximamente(titulo: 'Portafolio', texto: 'Fotos de tus trabajos'),
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
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clientas'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Portafolio'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class _Proximamente extends StatelessWidget {
  const _Proximamente({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_outlined, size: 48, color: NailsyColors.gris),
            const SizedBox(height: 12),
            Text(texto, style: const TextStyle(color: NailsyColors.textoSecundario)),
            const SizedBox(height: 4),
            const Text('Próximamente', style: TextStyle(color: NailsyColors.rosaSuave)),
          ],
        ),
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
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Nailsy Queens Pro'),
            subtitle: Text('Versión 0.1 · Fase 1'),
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
