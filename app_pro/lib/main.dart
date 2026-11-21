import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/agenda_repo.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/nueva_contrasena_screen.dart';
import 'sectores.dart';
import 'theme.dart';

/// Se pasan al compilar:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
/// Si no se pasan, la app arranca en MODO DEMO con datos de ejemplo.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const modoDemo = supabaseUrl == '' || supabaseAnonKey == '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  if (!modoDemo) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const NailsyProApp(demo: modoDemo));
}

class NailsyProApp extends StatefulWidget {
  const NailsyProApp({super.key, required this.demo, this.ahora, this.sector = 'nails'});

  final bool demo;

  /// Reloj fijo para pruebas (en la app real, la hora del móvil).
  final DateTime Function()? ahora;

  /// Sector inicial (en la app real se lee del perfil al entrar).
  final String sector;

  @override
  State<NailsyProApp> createState() => _NailsyProAppState();
}

class _NailsyProAppState extends State<NailsyProApp> {
  late final _sector = ValueNotifier<Sector>(sectorPorId(widget.sector));

  @override
  void dispose() {
    _sector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlamGo Pro',
      debugShowCheckedModeBanner: false,
      theme: nailsyTheme(),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES'), Locale('es', 'CO'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // El color y el vocabulario dependen del sector de la profesional (uñas en rosa, barbería en azul…).
      builder: (context, child) => ValueListenableBuilder<Sector>(
        valueListenable: _sector,
        builder: (context, sector, _) =>
            Theme(data: sector.tema, child: SectorScope(sector: sector, child: child!)),
      ),
      home: widget.demo
          ? HomeShell(repo: DemoAgendaRepo(), modoDemo: true, ahora: widget.ahora)
          : _PuertaSesion(sector: _sector),
    );
  }
}

/// Muestra el login, la app o la pantalla de nueva contraseña según la sesión.
class _PuertaSesion extends StatefulWidget {
  const _PuertaSesion({required this.sector});

  final ValueNotifier<Sector> sector;

  @override
  State<_PuertaSesion> createState() => _PuertaSesionState();
}

class _PuertaSesionState extends State<_PuertaSesion> {
  final _auth = Supabase.instance.client.auth;
  late final StreamSubscription<AuthState> _sub;
  bool _recuperando = false;

  @override
  void initState() {
    super.initState();
    _sub = _auth.onAuthStateChange.listen((estado) {
      if (!mounted) return;
      setState(() {
        if (estado.event == AuthChangeEvent.passwordRecovery) _recuperando = true;
        if (estado.event == AuthChangeEvent.signedOut) _recuperando = false;
      });
      if (estado.event == AuthChangeEvent.signedIn) _cargarSector();
    });
    // Después del primer dibujo: cambiar el sector repinta toda la app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarSector());
  }

  /// Lee el sector de la profesional (uñas, barbería…) para poner su color y vocabulario.
  Future<void> _cargarSector() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;
    final delAlta = usuario.userMetadata?['sector'] as String?;
    if (delAlta != null) widget.sector.value = sectorPorId(delAlta);
    try {
      final fila = await Supabase.instance.client
          .from('manicuristas')
          .select('sector')
          .eq('id', usuario.id)
          .maybeSingle();
      final id = fila?['sector'] as String?;
      if (id != null && mounted) widget.sector.value = sectorPorId(id);
    } catch (_) {
      // Sin conexión: se queda el sector del alta o el de uñas.
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = _auth.currentSession;
    if (sesion == null) return Theme(data: temaGlamGo(), child: const LoginScreen());
    if (_recuperando) {
      return NuevaContrasenaScreen(
        guardar: (nueva) => _auth.updateUser(UserAttributes(password: nueva)),
        alTerminar: () => setState(() => _recuperando = false),
      );
    }
    return HomeShell(
      key: ValueKey(sesion.user.id),
      repo: SupabaseAgendaRepo(Supabase.instance.client),
    );
  }
}
