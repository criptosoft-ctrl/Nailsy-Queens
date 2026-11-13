import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nailsy_pro/clienta/app_clienta.dart';
import 'package:nailsy_pro/clienta/clienta_repo.dart';
import 'package:nailsy_pro/clienta/reservar_screen.dart';
import 'package:nailsy_pro/models/publico.dart';
import 'package:nailsy_pro/theme.dart';

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

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('El buscador muestra manicuristas y filtra por estilo', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo(), demo: true));
    await tester.pumpAndSettle();

    expect(find.text('Eudy Nails'), findsOneWidget);
    expect(find.text('Acrylic Studio'), findsOneWidget);

    final acrilico = find.widgetWithText(ChoiceChip, 'Acrílico');
    await tester.ensureVisible(acrilico);
    await tester.pumpAndSettle();
    await tester.tap(acrilico);
    await tester.pumpAndSettle();
    expect(find.text('Eudy Nails'), findsNothing);
    expect(find.text('Acrylic Studio'), findsOneWidget);
  });

  testWidgets('El perfil muestra servicios y botón de reservar', (tester) async {
    _movil(tester);
    await tester.pumpWidget(ClientaApp(repo: DemoClientaRepo()));
    await tester.pumpAndSettle();

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
}
