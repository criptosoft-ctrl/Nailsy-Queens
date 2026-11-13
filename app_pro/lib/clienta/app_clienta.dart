import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../theme.dart';
import 'buscar_screen.dart';
import 'clienta_repo.dart';
import 'cuenta_screen.dart';
import 'mis_citas_screen.dart';

class ClientaApp extends StatelessWidget {
  const ClientaApp({super.key, required this.repo, this.demo = false});

  final ClientaRepo repo;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nailsy Queens',
      debugShowCheckedModeBanner: false,
      theme: nailsyTheme(),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES'), Locale('es', 'CO'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ClientaShell(repo: repo, demo: demo),
    );
  }
}

class ClientaShell extends StatefulWidget {
  const ClientaShell({super.key, required this.repo, this.demo = false});

  final ClientaRepo repo;
  final bool demo;

  @override
  State<ClientaShell> createState() => _ClientaShellState();
}

class _ClientaShellState extends State<ClientaShell> {
  int _tab = 0;
  int _visitas = 0;

  void irAMisCitas() => setState(() {
        _tab = 1;
        _visitas++;
      });

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      BuscarScreen(repo: widget.repo, alReservar: irAMisCitas),
      MisCitasScreen(key: ValueKey('citas-$_visitas'), repo: widget.repo, alBuscar: () => setState(() => _tab = 0)),
      CuentaScreen(key: ValueKey('cuenta-$_visitas'), repo: widget.repo),
    ];
    return Scaffold(
      // Cada pantalla interior ya se adapta al teclado; si lo hiciera también esta, se restaría dos veces.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          if (widget.demo)
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
              removeTop: widget.demo,
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
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Mis citas'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Cuenta'),
        ],
      ),
    );
  }
}
