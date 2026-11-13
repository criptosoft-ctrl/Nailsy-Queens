import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/agenda_repo.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/nueva_contrasena_screen.dart';
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

class NailsyProApp extends StatelessWidget {
  const NailsyProApp({super.key, required this.demo});

  final bool demo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nailsy Queens Pro',
      debugShowCheckedModeBanner: false,
      theme: nailsyTheme(),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES'), Locale('es', 'CO'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: demo ? HomeShell(repo: DemoAgendaRepo(), modoDemo: true) : const _PuertaSesion(),
    );
  }
}

/// Muestra el login, la app o la pantalla de nueva contraseña según la sesión.
class _PuertaSesion extends StatefulWidget {
  const _PuertaSesion();

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
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = _auth.currentSession;
    if (sesion == null) return const LoginScreen();
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
