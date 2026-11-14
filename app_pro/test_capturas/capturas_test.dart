// Genera capturas de pantalla reales de las dos apps (modo demo) para el vídeo tutorial.
// Se ejecuta en CI con:  flutter test --update-goldens test_capturas/capturas_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nailsy_pro/clienta/app_clienta.dart';
import 'package:nailsy_pro/clienta/clienta_repo.dart';
import 'package:nailsy_pro/clienta/reservar_screen.dart';
import 'package:nailsy_pro/data/agenda_repo.dart';
import 'package:nailsy_pro/screens/clientas_screen.dart';
import 'package:nailsy_pro/screens/home_shell.dart';
import 'package:nailsy_pro/screens/login_screen.dart';
import 'package:nailsy_pro/theme.dart';

Future<void> _cargarFuentes() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> carga(String familia, List<String> archivos) async {
    final l = FontLoader(familia);
    for (final a in archivos) {
      final f = File('$dir/$a');
      if (f.existsSync()) l.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
    await l.load();
  }

  final roboto = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
    'Roboto-Light.ttf',
  ];
  for (final fam in [
    'Roboto',
    'FlutterTest', // fuente por defecto de los tests: así nada sale como bloques
    'Ahem',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ]) {
    await carga(fam, roboto);
  }
  await carga('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void _movil(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone (390 x 844 a 3x)
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: nailsyTheme(),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );

Future<void> _foto(String nombre) =>
    expectLater(find.byType(MaterialApp).first, matchesGoldenFile('capturas/$nombre.png'));

NavigatorState _nav(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

DateTime _proximoLunes() {
  final h = DateTime.now();
  final d = DateTime(h.year, h.month, h.day + 1);
  return d.add(Duration(days: (8 - d.weekday) % 7));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await _cargarFuentes();
  });

  testWidgets('Capturas · app de clientas', (tester) async {
    _movil(tester);
    final repo = DemoClientaRepo();
    await tester.pumpWidget(ClientaApp(repo: repo));
    await tester.pumpAndSettle();
    await _foto('c01_buscar');

    await tester.tap(find.text('Eudy Nails'));
    await tester.pumpAndSettle();
    await _foto('c02_perfil');

    final perfil = (await repo.perfil('m1'))!;
    final rusa = perfil.servicios.first;
    _nav(tester).push(MaterialPageRoute<bool>(
      builder: (_) => ReservarScreen(repo: repo, perfil: perfil, servicio: rusa, desde: _proximoLunes()),
    ));
    await tester.pumpAndSettle();
    final mas = find.byTooltip('Más uñas');
    for (var i = 0; i < 3; i++) {
      await tester.tap(mas);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(ChoiceChip, '10:00'));
    await tester.pumpAndSettle();
    await _foto('c03_reservar');

    await tester.tap(find.text('Confirmar reserva'));
    await tester.pumpAndSettle();
    await _foto('c04_confirmada');
    await tester.tap(find.text('Ver mis citas'));
    await tester.pumpAndSettle();
    _nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mis citas').last);
    await tester.pumpAndSettle();
    await _foto('c05_mis_citas');

    // Cuenta sin sesión (formulario de alta)
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo(conSesion: false), key: UniqueKey()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta').last);
    await tester.pumpAndSettle();
    await _foto('c06_cuenta');
  });

  testWidgets('Capturas · Nailsy Pro', (tester) async {
    _movil(tester);
    await tester.pumpWidget(_app(const LoginScreen()));
    await tester.pumpAndSettle();
    await _foto('p01_login');

    await tester.pumpWidget(_app(HomeShell(repo: DemoAgendaRepo(), key: UniqueKey())));
    await tester.pumpAndSettle();
    await _foto('p02_agenda');

    await tester.tap(find.text('Lucía Pérez'));
    await tester.pumpAndSettle();
    await _foto('p03_cita');
    _nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nueva cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir clienta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Lucía Pérez').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manicura rusa + gel'));
    await tester.pumpAndSettle();
    final mas = find.byTooltip('Más uñas').first;
    await tester.ensureVisible(mas);
    await tester.tap(mas);
    await tester.pumpAndSettle();
    await tester.tap(mas);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hora'));
    await tester.pumpAndSettle();
    await _foto('p05_rueda');
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await _foto('p04_nueva_cita');
    _nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clientas').last);
    await tester.pumpAndSettle();
    await _foto('p06_clientas');
    await tester.tap(find.descendant(of: find.byType(ClientasScreen), matching: find.text('Lucía Pérez')));
    await tester.pumpAndSettle();
    await _foto('p07_ficha');
    _nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portafolio').last);
    await tester.pumpAndSettle();
    await _foto('p08_portafolio');

    await tester.tap(find.text('Tarifario').last);
    await tester.pumpAndSettle();
    await _foto('p09_tarifario');

    await tester.tap(find.text('Ajustes').last);
    await tester.pumpAndSettle();
    await _foto('p10_ajustes');

    await tester.tap(find.text('Horario de trabajo'));
    await tester.pumpAndSettle();
    await _foto('p11_horario');
    _nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mi perfil público'));
    await tester.pumpAndSettle();
    await _foto('p12_perfil_publico');
  });
}
