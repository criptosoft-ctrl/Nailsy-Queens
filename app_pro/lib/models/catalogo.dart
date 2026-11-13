/// Tarifario: servicios base y añadidos de Nail Art.
library;

const categorias = <String, String>{
  'semipermanente': 'Semipermanente',
  'gel': 'Gel',
  'acrilico': 'Acrílico',
  'rusa': 'Manicura rusa',
  'pedicura': 'Pedicura',
  'retirada': 'Retirada',
  'otro': 'Otro',
};

double _num(Object? v) => v == null ? 0 : (v as num).toDouble();

class Servicio {
  const Servicio({
    this.id,
    required this.nombre,
    required this.categoria,
    required this.duracionMin,
    required this.precio,
  });

  final String? id;
  final String nombre;
  final String categoria;
  final int duracionMin;
  final double precio;

  factory Servicio.fromMap(Map<String, dynamic> m) => Servicio(
        id: m['id'] as String?,
        nombre: m['nombre'] as String,
        categoria: (m['categoria'] as String?) ?? 'otro',
        duracionMin: (m['duracion_min'] as num).toInt(),
        precio: _num(m['precio']),
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'categoria': categoria,
        'duracion_min': duracionMin,
        'precio': precio,
      };
}

class Anadido {
  const Anadido({
    this.id,
    required this.nombre,
    required this.duracionMin,
    required this.precio,
    this.porUna = false,
  });

  final String? id;
  final String nombre;
  final int duracionMin;
  final double precio;

  /// true = el precio y el tiempo son por cada uña.
  final bool porUna;

  factory Anadido.fromMap(Map<String, dynamic> m) => Anadido(
        id: m['id'] as String?,
        nombre: m['nombre'] as String,
        duracionMin: ((m['duracion_min'] as num?) ?? 0).toInt(),
        precio: _num(m['precio']),
        porUna: (m['por_una'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'duracion_min': duracionMin,
        'precio': precio,
        'por_una': porUna,
      };
}

/// Resultado de sumar servicio + añadidos.
class Presupuesto {
  const Presupuesto(this.duracionMin, this.precio);

  final int duracionMin;
  final double precio;

  /// [cantidades]: id del añadido → cantidad (nº de uñas si es "por uña", 1 si no).
  factory Presupuesto.calcular(Servicio? servicio, List<Anadido> anadidos, Map<String, int> cantidades) {
    var minutos = servicio?.duracionMin ?? 0;
    var precio = servicio?.precio ?? 0;
    for (final a in anadidos) {
      final n = cantidades[a.id] ?? 0;
      if (n <= 0) continue;
      minutos += a.duracionMin * n;
      precio += a.precio * n;
    }
    return Presupuesto(minutos, precio);
  }
}

String formatoDuracion(int minutos) {
  final h = minutos ~/ 60;
  final m = minutos % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}
