import 'cita.dart';
import 'publico.dart';

/// Tramo de tiempo libre dentro del horario de trabajo.
class Hueco {
  const Hueco(this.inicio, this.fin);
  final DateTime inicio;
  final DateTime fin;
  Duration get duracion => fin.difference(inicio);
}

/// Huecos libres de un día: horario de trabajo menos citas activas y bloqueos.
/// Solo devuelve huecos de al menos [minimoMin] minutos.
List<Hueco> huecosDelDia(
  DateTime dia,
  List<FranjaHorario> horario,
  List<Cita> citas,
  List<Bloqueo> bloqueos, {
  int minimoMin = 30,
}) {
  final d0 = DateTime(dia.year, dia.month, dia.day);
  final ocupados = <(DateTime, DateTime)>[
    for (final c in citas)
      if (c.activa) (c.inicio, c.fin),
    for (final b in bloqueos) (b.inicio, b.fin),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  final res = <Hueco>[];
  final franjas = horario.where((f) => f.dia == dia.weekday).toList()
    ..sort((a, b) => a.inicioMin.compareTo(b.inicioMin));
  for (final f in franjas) {
    var cursor = d0.add(Duration(minutes: f.inicioMin));
    final finFranja = d0.add(Duration(minutes: f.finMin));
    for (final (ini, fin) in ocupados) {
      if (!fin.isAfter(cursor) || !ini.isBefore(finFranja)) continue;
      if (ini.isAfter(cursor)) res.add(Hueco(cursor, ini));
      if (fin.isAfter(cursor)) cursor = fin;
    }
    if (finFranja.isAfter(cursor)) res.add(Hueco(cursor, finFranja));
  }
  return res.where((h) => h.duracion.inMinutes >= minimoMin).toList();
}
