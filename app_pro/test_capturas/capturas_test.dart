// Genera capturas de pantalla reales de las dos apps (modo demo) para el vídeo tutorial.
// Se ejecuta en CI con:  flutter test --update-goldens test_capturas/capturas_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nailsy_pro/clienta/app_clienta.dart';
import 'package:nailsy_pro/clienta/inicio_glamgo_screen.dart';
import 'package:nailsy_pro/main.dart';
import 'package:nailsy_pro/clienta/clienta_repo.dart';
import 'package:nailsy_pro/clienta/reservar_screen.dart';
import 'package:nailsy_pro/data/agenda_repo.dart';
import 'package:nailsy_pro/i18n.dart';
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
  final pjs = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    pjs.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await pjs.load();
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
    await initializeDateFormatting();
    await _cargarFuentes();
  });

  testWidgets('Capturas · app de clientas', (tester) async {
    _movil(tester);
    final repo = DemoClientaRepo();
    await tester.pumpWidget(ClientaApp(repo: repo));
    await tester.pumpAndSettle();
    // En las pruebas las fotos no se decodifican solas: se cargan antes de la captura.
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(InicioGlamGoScreen));
      for (final f in ['cabecera', 'unas', 'barberia', 'peluqueria', 'estetica']) {
        await precacheImage(AssetImage('assets/portada/$f.jpg'), ctx);
      }
    });
    await tester.pumpAndSettle();
    await _foto('c00_inicio_glamgo');
    await tester.tap(find.text('Manicura'));
    await tester.pumpAndSettle();
    await _foto('c01_buscar');

    await tester.tap(find.text('Eudy Nails'));
    await tester.pumpAndSettle();
    await _foto('c02_perfil');

    final perfil = (await repo.perfil('m1'))!;
    final rusa = perfil.servicios.first;
    // La sección de uñas tiene su propio navegador (el último en el árbol).
    tester.state<NavigatorState>(find.byType(Navigator).last).push(MaterialPageRoute<bool>(
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
    _nav(tester).popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mis citas').last);
    await tester.pumpAndSettle();
    await _foto('c05_mis_citas');

    // Cuenta sin sesión (formulario de alta)
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo(conSesion: false), key: UniqueKey()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    await _foto('c06_cuenta');

    // Barbershop
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo(), key: UniqueKey()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbería'));
    await tester.pumpAndSettle();
    await _foto('c07_barbershop');
    await tester.tap(find.text('Niños'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/vacio/barberia.png'), tester.element(find.text('Restablecer filtros')));
    });
    await tester.pumpAndSettle();
    await _foto('c09_sin_resultados');
    await tester.tap(find.text('Restablecer filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leo Barber'));
    await tester.pumpAndSettle();
    await _foto('c08_perfil_barbero');
  });

  testWidgets('Capturas · GlamGo Pro de un barbero', (tester) async {
    _movil(tester);
    final h = DateTime.now();
    await tester.pumpWidget(
        NailsyProApp(demo: true, sector: 'barberia', ahora: () => DateTime(h.year, h.month, h.day, 9, 45)));
    await tester.pumpAndSettle();
    await _foto('b01_agenda_barbero');
    await tester.tap(find.text('Marta Gómez'));
    await tester.pumpAndSettle();
    await _foto('b02_ficha_cita_barbero');
  });

  testWidgets('Capturas · Nailsy Pro', (tester) async {
    _movil(tester);
    final h = DateTime.now();
    DateTime reloj() => DateTime(h.year, h.month, h.day, 9, 45);
    await tester.pumpWidget(_app(Theme(data: temaGlamGo(), child: const LoginScreen())));
    await tester.pumpAndSettle();
    await _foto('p01_login');

    await tester.pumpWidget(_app(HomeShell(repo: DemoAgendaRepo(), key: UniqueKey(), ahora: reloj)));
    await tester.pumpAndSettle();
    await _foto('p02_agenda');
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await _foto('p02b_agenda_abajo');
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marta Gómez'));
    await tester.pumpAndSettle();
    await _foto('p03_ficha_cita');
    _nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nueva cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir clienta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Marta Gómez').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manicura rusa + gel'));
    await tester.pumpAndSettle();
    await _foto('p04_nueva_cita');
    _nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clientas').last);
    await tester.pumpAndSettle();
    await _foto('p06_clientas');
    await tester.tap(find.descendant(of: find.byType(ClientasScreen), matching: find.text('Marta Gómez')));
    await tester.pumpAndSettle();
    await _foto('p07_ficha_clienta');
    _nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portafolio').last);
    await tester.pumpAndSettle();
    await _foto('p08_portafolio');

    await tester.tap(find.text('Estadísticas').last);
    await tester.pumpAndSettle();
    await _foto('p09_estadisticas');

    await tester.tap(find.text('Agenda').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mi cuenta'));
    await tester.pumpAndSettle();
    await _foto('p10_mi_cuenta');
    await tester.tap(find.text('Tarifario'));
    await tester.pumpAndSettle();
    await _foto('p11_tarifario');
    _nav(tester).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Horario de trabajo'));
    await tester.pumpAndSettle();
    await _foto('p12_horario');
    _nav(tester).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi perfil público'));
    await tester.pumpAndSettle();
    await _foto('p13_perfil_publico');
  });

  testWidgets('Capturas · a domicilio', (tester) async {
    _movil(tester);
    final repo = DemoClientaRepo();
    await tester.pumpWidget(ClientaApp(repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manicura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A domicilio'));
    await tester.pumpAndSettle();
    await _foto('d01_buscar_domicilio');

    final perfil = (await repo.perfil('m1'))!;
    tester.state<NavigatorState>(find.byType(Navigator).last).push(MaterialPageRoute<bool>(
      builder: (_) => ReservarScreen(
        repo: repo,
        perfil: perfil,
        servicio: perfil.servicios.first,
        desde: _proximoLunes(),
        ubicacion: () async => (lat: 28.1036, lng: -15.4176),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En mi casa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'C/ Perojo 22, 3ºB');
    await tester.tap(find.text('Usar mi ubicación para comprobar la zona'));
    await tester.pumpAndSettle();
    final lista = find.descendant(of: find.byType(ReservarScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip, '10:00'), 300, scrollable: lista);
    await tester.tap(find.widgetWithText(ChoiceChip, '10:00'));
    await tester.pumpAndSettle();
    await tester.drag(lista, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await _foto('d02_reservar_domicilio');

    final h = DateTime.now();
    await tester.pumpWidget(_app(HomeShell(
        repo: DemoAgendaRepo(), key: UniqueKey(), ahora: () => DateTime(h.year, h.month, h.day, 9, 45))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Carla Sanz'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await _foto('d03_agenda_viaje');
    await tester.tap(find.text('Carla Sanz'));
    await tester.pumpAndSettle();
    await _foto('d04_ficha_domicilio');
    _nav(tester).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Hola, Eudy'), -300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Mi cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi perfil público'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tiempo de viaje entre citas'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await _foto('d05_pro_domicilio');
  });

  testWidgets('Capturas · idiomas (inglés y alemán)', (tester) async {
    _movil(tester);
    addTearDown(() => idiomaActual.value = Idioma.es);
    for (final idioma in [Idioma.en, Idioma.de]) {
      idiomaActual.value = idioma;
      await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo(), key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(InicioGlamGoScreen));
        for (final f in ['cabecera', 'unas', 'barberia', 'peluqueria', 'estetica']) {
          await precacheImage(AssetImage('assets/portada/$f.jpg'), ctx);
        }
      });
      await tester.pumpAndSettle();
      await _foto('i_${idioma.name}_portada');
      await tester.tap(find.text(idioma == Idioma.en ? 'Manicure' : 'Maniküre'));
      await tester.pumpAndSettle();
      await _foto('i_${idioma.name}_buscar');
    }
  });
}
