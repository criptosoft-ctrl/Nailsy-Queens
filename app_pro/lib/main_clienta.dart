import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'clienta/app_clienta.dart';
import 'clienta/clienta_repo.dart';

/// App de CLIENTAS (buscar manicurista y reservar).
/// Se compila con:  flutter build web -t lib/main_clienta.dart
/// Sin SUPABASE_URL / SUPABASE_ANON_KEY arranca en modo demo.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const modoDemo = supabaseUrl == '' || supabaseAnonKey == '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final ClientaRepo repo;
  if (modoDemo) {
    repo = DemoClientaRepo();
  } else {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    repo = SupabaseClientaRepo(
      Supabase.instance.client,
      urlRetorno: kIsWeb ? '${Uri.base.origin}/' : null,
    );
  }
  runApp(ClientaApp(repo: repo, demo: modoDemo));
}
