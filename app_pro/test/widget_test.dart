import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nailsy_pro/main.dart';
import 'package:nailsy_pro/models/catalogo.dart';
import 'package:nailsy_pro/models/clienta.dart';
import 'package:nailsy_pro/screens/clientas_screen.dart';
import 'package:nailsy_pro/screens/tarifario_screen.dart';
import 'package:nailsy_pro/models/cita.dart';

/// Pantalla de móvil alta (400x900) para que toda la agenda quepa.
void _movil(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('El modo demo muestra la agenda de hoy con su resumen', (tester) async {
    _movil(tester);
    await tester.pumpWidget(const NailsyProApp(demo: true));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Eudy'), findsOneWidget);
    expect(find.text('Marta Gómez'), findsOneWidget);
    expect(find.text('Lucía Pérez'), findsOneWidget);
    expect(find.text('Carla Sanz'), findsOneWidget);
    expect(find.text('Almuerzo'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget); // 1 completada de 3
  });

  testWidgets('Marcar una cita como "no vino" la saca del resumen', (tester) async {
    _movil(tester);
    await tester.pumpWidget(const NailsyProApp(demo: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lucía Pérez'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('La clienta no vino'));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
  });

  test('ResumenDia ignora canceladas y ausencias', () {
    final base = DateTime(2026, 11, 12, 9);
    Cita c(String id, double p, EstadoCita e) => Cita(
          id: id,
          clientaNombre: id,
          servicioNombre: 's',
          inicio: base,
          fin: base.add(const Duration(hours: 1)),
          precio: p,
          estado: e,
        );
    final r = ResumenDia.de([
      c('a', 35, EstadoCita.completada),
      c('b', 50, EstadoCita.confirmada),
      c('c', 28, EstadoCita.cancelada),
      c('d', 20, EstadoCita.noShow),
    ]);
    expect(r.ingresos, 85);
    expect(r.hechas, 1);
    expect(r.total, 2);
  });

  test('Cita.fromMap lee una fila de Supabase', () {
    final cita = Cita.fromMap({
      'id': 'x',
      'inicio': '2026-11-12T09:00:00+00:00',
      'fin': '2026-11-12T10:30:00+00:00',
      'precio_total': 35,
      'estado': 'no_show',
      'estado_pago': 'pagado',
      'clientas': {'nombre': 'Marta'},
      'servicios': {'nombre': 'Rusa'},
    });
    expect(cita.clientaNombre, 'Marta');
    expect(cita.estado, EstadoCita.noShow);
    expect(cita.estadoPago, EstadoPago.pagado);
    expect(cita.activa, isFalse);
  });

  testWidgets('Sin citas muestra el estado vacío', (tester) async {
    _movil(tester);
    await tester.pumpWidget(const NailsyProApp(demo: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('No hay citas este día'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('Presupuesto suma servicio y añadidos (por uña y fijos)', () {
    const s = Servicio(id: 's', nombre: 'Rusa', categoria: 'rusa', duracionMin: 90, precio: 35);
    const a = [
      Anadido(id: 'a1', nombre: 'Mano alzada', duracionMin: 5, precio: 2, porUna: true),
      Anadido(id: 'a2', nombre: 'Cristales', duracionMin: 3, precio: 1, porUna: true),
      Anadido(id: 'a3', nombre: 'Retirada', duracionMin: 15, precio: 5),
    ];
    final p = Presupuesto.calcular(s, a, {'a1': 3, 'a3': 1});
    expect(p.duracionMin, 120);
    expect(p.precio, 46);
    expect(formatoDuracion(p.duracionMin), '2 h');
    expect(formatoDuracion(55), '55 min');
    expect(formatoDuracion(95), '1 h 35 min');
  });

  test('Clienta.fromMap lee las alergias embebidas como objeto o lista', () {
    final a = Clienta.fromMap({
      'id': '1',
      'nombre': 'Ana López',
      'fichas_una': {'alergias': ['acrilatos']},
    });
    final b = Clienta.fromMap({
      'id': '2',
      'nombre': 'Bea',
      'fichas_una': [
        {'alergias': ['latex']},
      ],
    });
    final c = Clienta.fromMap({'id': '3', 'nombre': 'Carla', 'fichas_una': null});
    expect(a.alergias, ['acrilatos']);
    expect(a.iniciales, 'AL');
    expect(b.alergias, ['latex']);
    expect(c.tieneAlergias, isFalse);
  });

  testWidgets('Pestaña Clientas: lista, alergia en rojo y ficha', (tester) async {
    _movil(tester);
    await tester.pumpWidget(const NailsyProApp(demo: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clientas').last);
    await tester.pumpAndSettle();

    final enClientas = find.descendant(of: find.byType(ClientasScreen), matching: find.text('Lucía Pérez'));
    expect(enClientas, findsOneWidget);
    expect(
        find.descendant(of: find.byType(ClientasScreen), matching: find.text('Alergia: Acrilatos')), findsOneWidget);

    await tester.tap(enClientas);
    await tester.pumpAndSettle();
    expect(find.text('Almendrada'), findsOneWidget);
    expect(find.text('Historial de citas'.toUpperCase()), findsOneWidget);
  });

  testWidgets('Pestaña Tarifario muestra servicios y añadidos', (tester) async {
    _movil(tester);
    await tester.pumpWidget(const NailsyProApp(demo: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarifario').last);
    await tester.pumpAndSettle();
    final t = find.byType(TarifarioScreen);
    expect(find.descendant(of: t, matching: find.text('Manicura rusa + gel')), findsOneWidget);
    expect(find.descendant(of: t, matching: find.text('Diseño a mano alzada')), findsOneWidget);
  });

  testWidgets('Nueva cita calcula duración y precio, y pide la hora', (tester) async {
    _movil(tester);
    await tester.pumpWidget(const NailsyProApp(demo: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nueva cita'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cita'), findsOneWidget);

    await tester.tap(find.text('Elegir clienta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Carla Sanz').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Semipermanente'));
    await tester.pumpAndSettle();
    String precioTotal() => tester.widget<TextField>(find.byKey(const Key('precio-total'))).controller!.text;
    expect(precioTotal(), '20');

    final mas = find.byTooltip('Más uñas').first;
    await tester.ensureVisible(mas);
    await tester.tap(mas);
    await tester.pump();
    await tester.tap(mas);
    await tester.pumpAndSettle();
    expect(precioTotal(), '24');
    expect(find.text('Duración 55 min'), findsOneWidget);

    await tester.tap(find.text('Guardar cita'));
    await tester.pump();
    expect(find.text('Falta elegir la hora.'), findsOneWidget);
  });
}
