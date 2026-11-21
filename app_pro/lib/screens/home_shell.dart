import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../theme.dart';
import 'agenda_screen.dart';
import 'clientas_screen.dart';
import 'estadisticas_screen.dart';
import 'portafolio_screen.dart';
import '../sectores.dart';

/// Pantalla principal con la barra inferior: Agenda · Clientas · Portafolio · Ajustes.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repo, this.modoDemo = false, this.ahora});

  final AgendaRepo repo;
  final bool modoDemo;

  /// Reloj (para pruebas y capturas).
  final DateTime Function()? ahora;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  int _visitas = 0; // fuerza recargar Clientas/Portafolio/Estadísticas al volver a la pestaña
  int _visitasAgenda = 0;

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      AgendaScreen(key: ValueKey('agenda-$_visitasAgenda'), repo: widget.repo, modoDemo: widget.modoDemo, ahora: widget.ahora),
      ClientasScreen(key: ValueKey('clientas-$_visitas'), repo: widget.repo),
      PortafolioScreen(key: ValueKey('portafolio-$_visitas'), repo: widget.repo),
      EstadisticasScreen(key: ValueKey('estadisticas-$_visitas'), repo: widget.repo, ahora: widget.ahora),
    ];

    return Scaffold(
      // Cada pantalla interior ya se adapta al teclado; si lo hiciera también esta, se restaría dos veces.
      resizeToAvoidBottomInset: false,
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
          if (i == 0 && _tab != 0) _visitasAgenda++;
          _tab = i;
        }),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
          NavigationDestination(icon: const Icon(Icons.people_outline), label: context.sector.clientes),
          const NavigationDestination(icon: Icon(Icons.photo_outlined), label: 'Portafolio'),
          const NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Estadísticas'),
        ],
      ),
    );
  }
}
