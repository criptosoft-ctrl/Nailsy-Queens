import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/agenda_repo.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
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

/// Muestra el login o la app según haya sesión iniciada.
class _PuertaSesion extends StatelessWidget {
  const _PuertaSesion();

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final sesion = auth.currentSession;
        if (sesion == null) return const LoginScreen();
        return HomeShell(
          key: ValueKey(sesion.user.id),
          repo: SupabaseAgendaRepo(Supabase.instance.client),
        );
      },
    );
  }
}
