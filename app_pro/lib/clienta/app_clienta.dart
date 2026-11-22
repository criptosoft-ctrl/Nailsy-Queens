import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../screens/nueva_contrasena_screen.dart';
import '../sectores.dart';
import '../theme.dart';
import 'buscar_screen.dart';
import 'clienta_repo.dart';
import 'cuenta_screen.dart';
import 'inicio_glamgo_screen.dart';
import 'mis_citas_screen.dart';

class ClientaApp extends StatelessWidget {
  const ClientaApp({super.key, required this.repo, this.demo = false});

  final ClientaRepo repo;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: marcaGlamGo,
      debugShowCheckedModeBanner: false,
      theme: temaGlamGo(),
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
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.repo.pideNuevaContrasena.listen((_) => _pedirContrasena());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _pedirContrasena() {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => NuevaContrasenaScreen(
        guardar: widget.repo.cambiarContrasena,
        alTerminar: () => Navigator.of(ctx).pop(),
      ),
    ));
  }

  void _abrirSector(Sector sector) {
    final raiz = Navigator.of(context);
    final interno = GlobalKey<NavigatorState>();
    raiz.push(MaterialPageRoute(
      builder: (_) => Theme(
        // Cada sección lleva su color (rosa en uñas, azul en barbería…) en todas sus pantallas.
        data: sector.tema,
        child: SectorScope(
          sector: sector,
          child: NavigatorPopHandler(
          onPopWithResult: (_) => interno.currentState?.maybePop(),
          child: Navigator(
            key: interno,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => BuscarScreen(
                repo: widget.repo,
                sector: sector.id,
                alVolver: () => raiz.pop(),
                alReservar: () {
                  // Tras reservar, volvemos a la portada y abrimos "Mis citas".
                  raiz.popUntil((r) => r.isFirst);
                  irAMisCitas();
                },
              ),
            ),
          ),
        ),
        ),
      ),
    ));
  }

  void irAMisCitas() => setState(() {
        _tab = 1;
        _visitas++;
      });

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      InicioGlamGoScreen(alAbrir: _abrirSector),
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
      backgroundColor: NailsyColors.fondoProfundo,
      bottomNavigationBar: _BarraGlamGo(
        seleccionada: _tab,
        alElegir: (i) => setState(() {
          if (i != _tab) _visitas++;
          _tab = i;
        }),
      ),
    );
  }
}


/// Barra de abajo flotante, con la pestaña elegida en oro y una rayita debajo (diseño GlamGo).
class _BarraGlamGo extends StatelessWidget {
  const _BarraGlamGo({required this.seleccionada, required this.alElegir});

  final int seleccionada;
  final ValueChanged<int> alElegir;

  static const _opciones = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Mis citas'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        height: 74,
        decoration: BoxDecoration(
          color: NailsyColors.barraNavegacion.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _opciones.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => alElegir(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(i == seleccionada ? _opciones[i].$2 : _opciones[i].$1,
                          color: i == seleccionada ? NailsyColors.oro : NailsyColors.textoSecundario, size: 26),
                      const SizedBox(height: 4),
                      Text(
                        _opciones[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: i == seleccionada ? FontWeight.w700 : FontWeight.w500,
                          color: i == seleccionada ? NailsyColors.oro : NailsyColors.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == seleccionada ? 46 : 0,
                        height: 3,
                        decoration: BoxDecoration(color: NailsyColors.oro, borderRadius: BorderRadius.circular(2)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
