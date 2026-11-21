/// Clientas y ficha técnica de la uña.
library;

const diagnosticosComunes = <String, String>{
  'quebradiza': 'Quebradiza',
  'grasa': 'Grasa',
  'mordida': 'Mordida',
  'fina': 'Fina / blanda',
  'cuticula_seca': 'Cutícula seca',
  'estrias': 'Estrías',
  'onicolisis': 'Despegada (onicólisis)',
};

const alergiasComunes = <String, String>{
  'acrilatos': 'Acrilatos',
  'hema': 'HEMA',
  'latex': 'Látex',
  'quitaesmalte': 'Acetona',
  'niquel': 'Níquel',
};

const formasUna = ['Almendrada', 'Bailarina', 'Cuadrada', 'Squoval', 'Ovalada', 'Redonda', 'Stiletto'];
const largosUna = ['Corto', 'Medio', 'Largo', 'Extra largo'];

/// Versión del texto legal que se muestra al pedir el consentimiento.
const versionConsentimiento = 'v1-2026-11';
const textoConsentimiento =
    'Doy mi consentimiento para que mi manicurista guarde en GlamGo información sobre la salud de '
    'mis uñas (diagnósticos y alergias) con el único fin de prestarme el servicio de forma segura. '
    'Puedo retirar este consentimiento en cualquier momento y pedir que se borren mis datos.';

List<String> _lista(Object? v) => v == null ? [] : (v as List).map((e) => e.toString()).toList();

class Clienta {
  const Clienta({
    this.id,
    required this.nombre,
    this.telefono,
    this.email,
    this.notas,
    this.alergias = const [],
  });

  final String? id;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? notas;

  /// Copia de las alergias de su ficha, para avisar en listas y citas.
  final List<String> alergias;

  bool get tieneAlergias => alergias.isNotEmpty;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  /// Lee una fila de `clientas` con el embebido opcional `fichas_una(alergias)`
  /// (PostgREST puede devolverlo como objeto o como lista).
  factory Clienta.fromMap(Map<String, dynamic> m) {
    final ficha = m['fichas_una'];
    Object? alergias;
    if (ficha is Map) alergias = ficha['alergias'];
    if (ficha is List && ficha.isNotEmpty) alergias = (ficha.first as Map)['alergias'];
    return Clienta(
      id: m['id'] as String?,
      nombre: m['nombre'] as String,
      telefono: m['telefono'] as String?,
      email: m['email'] as String?,
      notas: m['notas'] as String?,
      alergias: _lista(alergias),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'telefono': _vacioANull(telefono),
        'email': _vacioANull(email),
        'notas': _vacioANull(notas),
      };

  Clienta copyWith({String? id, List<String>? alergias}) => Clienta(
        id: id ?? this.id,
        nombre: nombre,
        telefono: telefono,
        email: email,
        notas: notas,
        alergias: alergias ?? this.alergias,
      );
}

String? _vacioANull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

class FichaUna {
  const FichaUna({
    required this.clientaId,
    this.diagnosticos = const [],
    this.alergias = const [],
    this.formaDeseada,
    this.largoDeseado,
    this.tonosFavoritos = const [],
    this.observaciones,
  });

  final String clientaId;
  final List<String> diagnosticos;
  final List<String> alergias;
  final String? formaDeseada;
  final String? largoDeseado;
  final List<String> tonosFavoritos;
  final String? observaciones;

  factory FichaUna.fromMap(Map<String, dynamic> m) => FichaUna(
        clientaId: m['clienta_id'] as String,
        diagnosticos: _lista(m['diagnosticos']),
        alergias: _lista(m['alergias']),
        formaDeseada: m['forma_deseada'] as String?,
        largoDeseado: m['largo_deseado'] as String?,
        tonosFavoritos: _lista(m['tonos_favoritos']),
        observaciones: m['observaciones'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'clienta_id': clientaId,
        'diagnosticos': diagnosticos,
        'alergias': alergias,
        'forma_deseada': formaDeseada,
        'largo_deseado': largoDeseado,
        'tonos_favoritos': tonosFavoritos,
        'observaciones': _vacioANull(observaciones),
      };
}

// ---------------- Barbería: ficha del pelo y la barba ----------------
// Se guarda en la misma tabla que la ficha de la uña (fichas_una), con estos significados:
// diagnosticos = pelo y piel · forma_deseada = corte habitual · largo_deseado = barba ·
// tonos_favoritos = números de máquina.

const diagnosticosPelo = <String, String>{
  'liso': 'Liso',
  'ondulado': 'Ondulado',
  'rizado': 'Rizado',
  'afro': 'Afro',
  'fino': 'Fino',
  'grueso': 'Grueso',
  'entradas': 'Entradas / poco pelo',
  'remolino': 'Remolino',
  'caspa': 'Caspa',
  'piel_sensible': 'Piel sensible',
};

const alergiasPelo = <String, String>{
  'ppd': 'Tintes (PPD)',
  'fragancias': 'Perfumes / after-shave',
  'alcohol': 'Alcohol',
  'latex': 'Látex',
  'niquel': 'Níquel',
};

const cortesBarberia = [
  'Degradado bajo',
  'Degradado medio',
  'Degradado alto',
  'Taper',
  'Clásico a tijera',
  'Crop',
  'Pompadour',
  'Mullet',
  'Rapado',
];
const barbasBarberia = ['Sin barba', 'Perfilada', 'Corta', 'Media', 'Larga', 'Bigote', 'Perilla'];

/// Qué guarda la ficha técnica en cada sector y cómo se llama cada apartado.
class FichaSector {
  const FichaSector({
    required this.titulo,
    required this.tituloDiagnosticos,
    required this.diagnosticos,
    required this.alergias,
    required this.tituloForma,
    required this.formas,
    required this.tituloLargo,
    required this.largos,
    required this.tituloTonos,
    required this.pistaTonos,
    required this.textoConsentimiento,
    required this.versionConsentimiento,
  });

  final String titulo;
  final String tituloDiagnosticos;
  final Map<String, String> diagnosticos;
  final Map<String, String> alergias;
  final String tituloForma;
  final List<String> formas;
  final String tituloLargo;
  final List<String> largos;
  final String tituloTonos;
  final String pistaTonos;
  final String textoConsentimiento;
  final String versionConsentimiento;
}

const fichaUnas = FichaSector(
  titulo: 'Ficha de la uña',
  tituloDiagnosticos: 'Diagnóstico de la uña',
  diagnosticos: diagnosticosComunes,
  alergias: alergiasComunes,
  tituloForma: 'Forma preferida',
  formas: formasUna,
  tituloLargo: 'Largo preferido',
  largos: largosUna,
  tituloTonos: 'Tonos favoritos',
  pistaTonos: 'Separados por comas: Nude rosado, Rojo cereza…',
  textoConsentimiento: textoConsentimiento,
  versionConsentimiento: versionConsentimiento,
);

const fichaBarberia = FichaSector(
  titulo: 'Ficha del pelo',
  tituloDiagnosticos: 'Pelo y piel',
  diagnosticos: diagnosticosPelo,
  alergias: alergiasPelo,
  tituloForma: 'Corte habitual',
  formas: cortesBarberia,
  tituloLargo: 'Barba',
  largos: barbasBarberia,
  tituloTonos: 'Números de máquina',
  pistaTonos: 'Separados por comas: 1 en los lados, 3 arriba…',
  textoConsentimiento:
      'Doy mi consentimiento para que mi barbero guarde en GlamGo información sobre mi pelo, mi piel y mis '
      'alergias con el único fin de prestarme el servicio de forma segura. Puedo retirar este consentimiento '
      'en cualquier momento y pedir que se borren mis datos.',
  versionConsentimiento: 'v1-2026-11-barberia',
);

/// Nombre legible de un código de diagnóstico o alergia (o el texto tal cual si es libre).
String etiquetaDiagnostico(String c) => diagnosticosComunes[c] ?? diagnosticosPelo[c] ?? c;
String etiquetaAlergia(String c) => alergiasComunes[c] ?? alergiasPelo[c] ?? c;
