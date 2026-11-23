import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nailsy_pro/clienta/app_clienta.dart';
import 'package:nailsy_pro/clienta/buscar_screen.dart';
import 'package:nailsy_pro/clienta/clienta_repo.dart';
import 'package:nailsy_pro/clienta/reservar_screen.dart';
import 'package:nailsy_pro/i18n.dart';
import 'package:nailsy_pro/models/publico.dart';
import 'package:nailsy_pro/theme.dart';
import 'package:nailsy_pro/whatsapp.dart';

void _movil(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Próximo lunes (siempre en el futuro, para que haya huecos).
DateTime _proximoLunes() {
  final h = DateTime.now();
  final d = DateTime(h.year, h.month, h.day + 1);
  return d.add(Duration(days: (8 - d.weekday) % 7));
}

/// La app abre en la portada de GlamGo; entra en la sección de uñas.
Future<void> _abrirNails(WidgetTester tester) async {
  await tester.tap(find.text('Manicura'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting());
  tearDown(() => idiomaActual.value = Idioma.es);

  testWidgets('Idiomas: la portada cambia a inglés y alemán desde el botón de idioma', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo()));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué te apetece hoy?'.toUpperCase()), findsOneWidget);

    await tester.tap(find.byTooltip('Idioma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Manicure'), findsOneWidget);
    expect(find.text('Barber'), findsOneWidget);
    expect(find.text('Book'), findsNWidgets(2));
    expect(find.text('My bookings'), findsOneWidget);

    await tester.tap(find.byTooltip('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(find.text('Maniküre'), findsOneWidget);
    expect(find.text('Demnächst'), findsNWidgets(2));

    // El buscador también sale en alemán.
    await tester.tap(find.text('Maniküre'));
    await tester.pumpAndSettle();
    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('In meiner Nähe'), findsOneWidget);
  });

  testWidgets('La portada de GlamGo muestra los sectores y abre Nailsy Queens', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Manicura'), findsOneWidget);
    expect(find.text('Barbería'), findsOneWidget);
    expect(find.text('Salón de Belleza'), findsOneWidget);
    expect(find.text('Próximamente'), findsNWidgets(2));

    await tester.tap(find.text('Salón de Belleza'));
    await tester.pump();
    expect(find.text('Salón de Belleza llega muy pronto a GlamGo.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _abrirNails(tester);
    expect(find.text('Eudy Nails'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a GlamGo'));
    await tester.pumpAndSettle();
    expect(find.text('Barbería'), findsOneWidget);
  });

  testWidgets('Barbershop muestra solo barberos, con sus filtros y vocabulario', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbería'));
    await tester.pumpAndSettle();

    expect(find.text('Leo Barber'), findsOneWidget);
    expect(find.text('Eudy Nails'), findsNothing);
    expect(find.text('Degradado'), findsWidgets);
    expect(find.text('Gel'), findsNothing);

    // Sin resultados: mensaje y botón para quitar filtros.
    await tester.tap(find.text('A domicilio'));
    await tester.pumpAndSettle();
    expect(find.text('No hemos encontrado barberos con esos filtros.'), findsOneWidget);
    await tester.tap(find.text('Restablecer filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Leo Barber'), findsOneWidget);

    await tester.tap(find.text('Leo Barber'));
    await tester.pumpAndSettle();
    expect(find.text('Corte degradado'), findsOneWidget);
  });

  testWidgets('El buscador muestra manicuristas y filtra por estilo', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo(), demo: true));
    await tester.pumpAndSettle();
    await _abrirNails(tester);

    expect(find.text('Eudy Nails'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Acrylic Studio'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Acrylic Studio'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Manicura'), -300, scrollable: find.byType(Scrollable).first);

    final acrilico = find.text('Acrílico').first;
    await tester.ensureVisible(acrilico);
    await tester.pumpAndSettle();
    await tester.tap(acrilico);
    await tester.pumpAndSettle();
    expect(find.text('Eudy Nails'), findsNothing);
    expect(find.text('Acrylic Studio'), findsOneWidget);

    // Arriba queda el estilo elegido; al tocarlo se quita el filtro.
    expect(find.text('Acrílico'), findsNWidgets(2));
    await tester.tap(find.text('Acrílico').first);
    await tester.pumpAndSettle();
    expect(find.text('Eudy Nails'), findsOneWidget);
  });

  testWidgets('El perfil muestra servicios y botón de reservar', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo()));
    await tester.pumpAndSettle();
    await _abrirNails(tester);

    await tester.tap(find.text('Eudy Nails'));
    await tester.pumpAndSettle();
    expect(find.text('Manicura rusa + gel'), findsOneWidget);
    expect(find.text('Semipermanente'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reservar'), findsNWidgets(2));
  });

  testWidgets('Reservar: extras suman al precio y la reserva queda en Mis citas', (tester) async {
    _movil(tester);
    final repo = DemoClientaRepo();
    final perfil = (await repo.perfil('m1'))!;
    final semi = perfil.servicios.firstWhere((s) => s.nombre == 'Semipermanente');

    await tester.pumpWidget(MaterialApp(
      theme: nailsyTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReservarScreen(repo: repo, perfil: perfil, servicio: semi, desde: _proximoLunes()),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'^20\s€$')), findsWidgets);
    final mas = find.byTooltip('Más uñas');
    await tester.tap(mas);
    await tester.pumpAndSettle();
    await tester.tap(mas);
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^24\s€$')), findsOneWidget);

    // Primer hueco del día (09:00) y confirmar
    await tester.tap(find.widgetWithText(ChoiceChip, '09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar reserva'));
    await tester.pumpAndSettle();
    expect(find.text('¡Reserva confirmada!'), findsOneWidget);
    await tester.tap(find.text('Ver mis citas'));
    await tester.pumpAndSettle();

    final citas = await repo.misCitas();
    expect(citas, hasLength(1));
    expect(citas.single.precio, 24);
    expect(citas.single.fin.difference(citas.single.inicio).inMinutes, 55);

    // El hueco ya no está libre
    final libres = await repo.huecosLibres('m1', citas.single.inicio, 55);
    expect(libres.contains(citas.single.inicio), isFalse);
  });

  test('A domicilio: se comprueba la zona y se suma el suplemento que pone ella', () async {
    final repo = DemoClientaRepo();
    final r = await repo.buscar(domicilio: true);
    expect(r.map((m) => m.id), ['m1']);
    expect(r.single.domicilio.importe, 5);

    final z = (await repo.comprobarZona('m1', 28.1, -15.4))!;
    expect(z.dentro, isTrue);
    expect(z.suplemento, 5);
    expect(await repo.comprobarZona('m2', 28.1, -15.4), isNull); // no va a domicilio

    final perfil = (await repo.perfil('m1'))!;
    final semi = perfil.servicios.last; // 45 min, 20 €
    final dia = _proximoLunes();
    final huecos = await repo.huecosLibres('m1', dia, semi.duracionMin, viajeMin: 30);
    await repo.reservar(
      manicuristaId: 'm1',
      servicio: semi,
      inicio: huecos.first,
      domicilio: const DireccionCita(texto: 'C/ Perojo 22', lat: 28.1, lng: -15.4),
    );
    final cita = (await repo.misCitas()).single;
    expect(cita.precio, 25);
    expect(cita.aDomicilio, isTrue);
    expect(cita.direccion, 'C/ Perojo 22');
  });

  testWidgets('Escribir una zona la sitúa en el mapa y busca alrededor', (tester) async {
    final repo = DemoClientaRepo();
    String? pedida;
    await tester.pumpWidget(MaterialApp(
      theme: nailsyTheme(),
      home: BuscarScreen(
        repo: repo,
        alReservar: () {},
        situarZona: (z) async {
          pedida = z;
          return (lat: 27.99, lng: -15.42);
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Telde');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(pedida, 'Telde');
    expect(find.textContaining('cerca de Telde'), findsOneWidget);
  });

  test('WhatsApp: número con prefijo y mensaje', () {
    expect(numeroWhatsapp('600 111 222'), '34600111222');
    expect(numeroWhatsapp('+57 300 123 4567'), '573001234567');
    expect(numeroWhatsapp('123'), isNull);
    final u = enlaceWhatsapp('600111222', 'Hola Eudy')!;
    expect(u.toString(), 'https://wa.me/34600111222?text=Hola+Eudy');
  });

  test('El texto también busca en las especialidades', () async {
    final r = await DemoClientaRepo().buscar(texto: 'acríl');
    expect(r.map((m) => m.nombre), ['Acrylic Studio']);
  });

  testWidgets('Sin sesión, Mis citas pide entrar', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo(conSesion: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis citas').last);
    await tester.pumpAndSettle();
    expect(find.text('Entra en tu cuenta para ver tus citas.'), findsOneWidget);
  });

  test('MiPerfil.pendientes indica qué falta para aparecer', () {
    const p = MiPerfil(nombre: 'Eudy');
    expect(p.pendientes(tieneServicios: false, tieneHorario: true, tieneFotos: true),
        ['la ciudad', 'al menos un servicio en el Tarifario']);
    const q = MiPerfil(nombre: 'Eudy', ciudad: 'Telde');
    expect(q.pendientes(tieneServicios: true, tieneHorario: true, tieneFotos: true), isEmpty);
  });

  test('FranjaHorario lee las horas de Supabase', () {
    final f = FranjaHorario.fromMap({'dia_semana': 2, 'hora_inicio': '09:30:00', 'hora_fin': '14:00:00'});
    expect(f.inicioMin, 570);
    expect(f.toMap()['hora_fin'], '14:00');
  });

  testWidgets('En "Entrar" aparece la opción de recuperar contraseña', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo(conSesion: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('¿Olvidaste tu contraseña?'), findsNothing); // en "Crear cuenta" no sale
    await tester.tap(find.text('¿Ya tienes cuenta? Entra'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ana@correo.com');
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pump();
    expect(find.textContaining('Te hemos enviado un enlace a ana@correo.com'), findsOneWidget);
  });
}
