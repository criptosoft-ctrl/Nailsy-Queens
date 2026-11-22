import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nailsy_pro/main.dart';
import 'package:nailsy_pro/models/catalogo.dart';
import 'package:nailsy_pro/models/cita.dart';
import 'package:nailsy_pro/models/clienta.dart';
import 'package:nailsy_pro/models/huecos.dart';
import 'package:nailsy_pro/models/publico.dart';
import 'package:nailsy_pro/screens/clientas_screen.dart';
import 'package:nailsy_pro/screens/estadisticas_screen.dart';

/// Pantalla de móvil alta (400x900) para que quepa todo.
void _movil(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _abrirPro(WidgetTester tester) async {
  _movil(tester);
  // Reloj fijo a las 9:45: la cita de Marta (9:00–10:30) está en curso y la de Lucía (11:00) aún no.
  final h = DateTime.now();
  await tester.pumpWidget(NailsyProApp(demo: true, ahora: () => DateTime(h.year, h.month, h.day, 9, 45)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('La agenda muestra el día con su resumen, almuerzo y huecos libres', (tester) async {
    await _abrirPro(tester);
    expect(find.text('Hola, Eudy'), findsOneWidget);
    expect(find.text('Marta Gómez'), findsOneWidget);
    expect(find.text('Lucía Pérez'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Carla Sanz'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Carla Sanz'), findsOneWidget);
    expect(find.text('Almuerzo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hola, Eudy'), -300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('113'), findsWidgets); // previsto: 35 + 50 + 28
    expect(find.textContaining('Alergia acrilatos'), findsOneWidget);
    expect(find.textContaining('En curso'), findsOneWidget);
    expect(find.text('Hueco libre'), findsOneWidget); // dato del resumen
  });

  testWidgets('GlamGo Pro de un barbero habla de clientes y usa la ficha del pelo', (tester) async {
    _movil(tester);
    final h = DateTime.now();
    await tester.pumpWidget(
        NailsyProApp(demo: true, sector: 'barberia', ahora: () => DateTime(h.year, h.month, h.day, 9, 45)));
    await tester.pumpAndSettle();
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Clientas'), findsNothing);

    await tester.tap(find.text('Marta Gómez'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ficha del pelo'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Ficha del pelo'), findsOneWidget);
    expect(find.text('Corte'), findsOneWidget);
  });

  testWidgets('Ficha de cita: alergia con consejo, empezar y finalizar cobrando', (tester) async {
    await _abrirPro(tester);
    await tester.tap(find.text('Lucía Pérez'));
    await tester.pumpAndSettle();
    expect(find.text('Ficha de cita'), findsOneWidget);
    await tester.tap(find.text('Empezar cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Finalizar y cobrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cita finalizada y cobrada'), findsOneWidget);
    expect(find.textContaining('Cobrada'), findsWidgets);

    // La de Marta (alérgica) muestra el consejo y su ficha
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marta Gómez'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sin HEMA'), findsOneWidget);
    expect(find.text('Almendrada'), findsOneWidget);
    expect(find.text('Nude 12'), findsOneWidget);
  });

  test('huecosDelDia descuenta citas y bloqueos del horario', () {
    final d = DateTime(2026, 11, 23); // lunes
    DateTime h(int hh, [int mm = 0]) => DateTime(2026, 11, 23, hh, mm);
    final huecos = huecosDelDia(
      d,
      const [FranjaHorario(dia: 1, inicioMin: 9 * 60, finMin: 18 * 60)],
      [
        Cita(id: 'a', clientaNombre: 'A', servicioNombre: 's', inicio: h(9), fin: h(10, 30), precio: 1, estado: EstadoCita.confirmada),
        Cita(id: 'b', clientaNombre: 'B', servicioNombre: 's', inicio: h(11), fin: h(13), precio: 1, estado: EstadoCita.confirmada),
        Cita(id: 'c', clientaNombre: 'C', servicioNombre: 's', inicio: h(15), fin: h(16), precio: 1, estado: EstadoCita.cancelada),
      ],
      [Bloqueo(inicio: h(13), fin: h(14), motivo: 'Almuerzo')],
    );
    expect(huecos.map((x) => '${x.inicio.hour}:${x.inicio.minute}-${x.fin.hour}:${x.fin.minute}').toList(),
        ['10:30-11:0', '14:0-18:0']);
  });

  test('Las citas a domicilio ocupan también el viaje de ida y vuelta', () {
    final d = DateTime(2026, 11, 23); // lunes
    DateTime h(int hh, [int mm = 0]) => DateTime(2026, 11, 23, hh, mm);
    final huecos = huecosDelDia(
      d,
      const [FranjaHorario(dia: 1, inicioMin: 9 * 60, finMin: 18 * 60)],
      [
        Cita(
            id: 'a',
            clientaNombre: 'A',
            servicioNombre: 's',
            inicio: h(11),
            fin: h(12),
            precio: 1,
            estado: EstadoCita.confirmada,
            aDomicilio: true,
            viajeMin: 30),
      ],
      const [],
    );
    expect(huecos.map((x) => '${x.inicio.hour}:${x.inicio.minute}-${x.fin.hour}:${x.fin.minute}').toList(),
        ['9:0-10:30', '12:30-18:0']);
  });

  testWidgets('La ficha de una cita a domicilio muestra la dirección, Cómo llegar y Llamar', (tester) async {
    await _abrirPro(tester);
    await tester.scrollUntilVisible(find.text('Carla Sanz'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Viaje de ida'), findsOneWidget);
    expect(find.textContaining('Vuelta'), findsOneWidget);
    await tester.tap(find.text('Carla Sanz'));
    await tester.pumpAndSettle();
    expect(find.text('A domicilio'), findsOneWidget);
    expect(find.textContaining('C/ Perojo 22'), findsOneWidget);
    expect(find.text('Cómo llegar'), findsOneWidget);
    expect(find.text('Llamar'), findsOneWidget);
  });

  test('ResumenMes calcula ingresos, ausencias y servicios', () {
    DateTime h(int d) => DateTime(2026, 11, d, 10);
    Cita c(String id, int dia, double p, EstadoCita e, String s) => Cita(
        id: id, clientaId: id, clientaNombre: id, servicioNombre: s, inicio: h(dia),
        fin: h(dia).add(const Duration(hours: 1)), precio: p, estado: e);
    final r = ResumenMes([
      c('a', 2, 35, EstadoCita.completada, 'Rusa'),
      c('b', 9, 50, EstadoCita.completada, 'Acrílicas'),
      c('c', 10, 35, EstadoCita.completada, 'Rusa'),
      c('d', 12, 20, EstadoCita.noShow, 'Semi'),
    ], DateTime(2026, 11, 30));
    expect(r.ingresos, 120);
    expect(r.noShows, 1);
    expect(r.tasaAusencias, 0.25);
    expect(r.topServicios.first.$1, 'Rusa');
    expect(r.porSemana[1], 85);
  });

  test('Cita.fromMap lee una fila de Supabase', () {
    final cita = Cita.fromMap({
      'id': 'x',
      'inicio': '2026-11-12T09:00:00+00:00',
      'fin': '2026-11-12T10:30:00+00:00',
      'precio_total': 35,
      'estado': 'no_show',
      'estado_pago': 'pagado',
      'notas': 'Nude 12',
      'clientas': {'nombre': 'Marta', 'fichas_una': {'alergias': ['acrilatos']}},
      'servicios': {'nombre': 'Rusa'},
    });
    expect(cita.clientaNombre, 'Marta');
    expect(cita.estado, EstadoCita.noShow);
    expect(cita.estadoPago, EstadoPago.pagado);
    expect(cita.alergias, ['acrilatos']);
    expect(cita.notas, 'Nude 12');
    expect(cita.activa, isFalse);
  });

  test('Presupuesto suma servicio y añadidos (por uña y fijos)', () {
    const s = Servicio(id: 's', nombre: 'Rusa', categoria: 'rusa', duracionMin: 90, precio: 35);
    const a = [
      Anadido(id: 'a1', nombre: 'Mano alzada', duracionMin: 5, precio: 2, porUna: true),
      Anadido(id: 'a3', nombre: 'Retirada', duracionMin: 15, precio: 5),
    ];
    final p = Presupuesto.calcular(s, a, {'a1': 3, 'a3': 1});
    expect(p.duracionMin, 120);
    expect(p.precio, 46);
    expect(formatoDuracion(95), '1 h 35 min');
  });

  test('Clienta.fromMap lee las alergias embebidas como objeto o lista', () {
    final a = Clienta.fromMap({'id': '1', 'nombre': 'Ana López', 'fichas_una': {'alergias': ['acrilatos']}});
    final b = Clienta.fromMap({'id': '2', 'nombre': 'Bea', 'fichas_una': [{'alergias': ['latex']}]});
    expect(a.alergias, ['acrilatos']);
    expect(a.iniciales, 'AL');
    expect(b.alergias, ['latex']);
  });

  testWidgets('Clientas: lista y ficha con pestañas', (tester) async {
    await _abrirPro(tester);
    await tester.tap(find.text('Clientas').last);
    await tester.pumpAndSettle();
    final marta = find.descendant(of: find.byType(ClientasScreen), matching: find.text('Marta Gómez'));
    expect(marta, findsOneWidget);
    await tester.tap(marta);
    await tester.pumpAndSettle();
    expect(find.text('Ficha'), findsOneWidget);
    expect(find.text('Almendrada'), findsOneWidget);
    expect(find.text('Reservar nueva cita'), findsOneWidget);
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gel con nail art'), findsOneWidget);
  });

  testWidgets('Estadísticas muestra ingresos y servicios', (tester) async {
    await _abrirPro(tester);
    await tester.tap(find.text('Estadísticas').last);
    await tester.pumpAndSettle();
    expect(find.byType(EstadisticasScreen), findsOneWidget);
    expect(find.text('Ingresos cobrados'), findsOneWidget);
    expect(find.text('Servicios más hechos'.toUpperCase()), findsOneWidget);
  });

  testWidgets('Mi cuenta abre tarifario, horario y perfil público', (tester) async {
    await _abrirPro(tester);
    await tester.tap(find.byTooltip('Mi cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarifario'));
    await tester.pumpAndSettle();
    expect(find.text('Manicura rusa + gel'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Horario de trabajo'));
    await tester.pumpAndSettle();
    expect(find.text('Lunes'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi perfil público'));
    await tester.pumpAndSettle();
    expect(find.text('Aparecer en el buscador'), findsOneWidget);
  });

  testWidgets('Nueva cita calcula duración y precio, y pide la hora', (tester) async {
    await _abrirPro(tester);
    await tester.tap(find.byTooltip('Nueva cita'));
    await tester.pumpAndSettle();
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
