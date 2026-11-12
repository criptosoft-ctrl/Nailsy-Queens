import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nailsy_pro/main.dart';
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
}
