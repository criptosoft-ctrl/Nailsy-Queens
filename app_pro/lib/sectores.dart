import 'package:flutter/material.dart';

import 'models/catalogo.dart';
import 'models/clienta.dart';
import 'models/publico.dart';
import 'theme.dart';

/// Marca general de la plataforma.
const marcaGlamGo = 'GlamGo';
const marcaGlamGoPro = 'GlamGo Pro';

/// Sectores de GlamGo. El id coincide con la columna `manicuristas.sector` de la base de datos.
class Sector {
  const Sector({
    required this.id,
    required this.nombre,
    required this.marca,
    required this.descripcion,
    required this.lema,
    required this.icono,
    required this.profesional,
    required this.elProfesional,
    required this.activo,
    required this.color,
    required this.sobreColor,
    required this.colorSuave,
    required this.imagen,
    required this.imagenVacio,
    required this.clientes,
    required this.cliente,
    required this.laCliente,
    required this.lasClientes,
    required this.nuevoCliente,
    required this.estilos,
    required this.categorias,
    required this.ficha,
    this.cobroPorUna = false,
  });

  final String id;

  /// Nombre del servicio ("Uñas", "Barbería"…).
  final String nombre;

  /// Nombre de la sección dentro de GlamGo ("Manicura", "Barbería"…).
  final String marca;
  final String descripcion;

  /// Frase bajo el título de la sección ("Manicura y nail art cerca de ti").
  final String lema;
  final IconData icono;

  /// Cómo se llama a la profesional ("manicurista", "barbero"…).
  final String profesional;

  /// Con artículo: "la manicurista", "el barbero"…
  final String elProfesional;

  /// Si ya se puede reservar en esta sección.
  final bool activo;

  /// Color de acento de la sección, el texto que va encima y su versión clara.
  final Color color;
  final Color sobreColor;
  final Color colorSuave;

  /// Foto decorativa de la tarjeta de la portada.
  final String imagen;

  /// Ilustración de "sin resultados" en el buscador.
  final String imagenVacio;

  /// Vocabulario: "Clientas"/"Clientes", "clienta"/"cliente", "la clienta"/"el cliente"…
  final String clientes;
  final String cliente;
  final String laCliente;
  final String lasClientes;
  final String nuevoCliente;

  /// Estilos para filtrar en el buscador y marcar como especialidad.
  final Map<String, String> estilos;

  /// Categorías de servicio del tarifario.
  final Map<String, String> categorias;

  /// Qué guarda la ficha técnica del cliente.
  final FichaSector ficha;

  /// Si los añadidos se pueden cobrar por uña.
  final bool cobroPorUna;

  ThemeData get tema => nailsyTheme(acento: color, sobreAcento: sobreColor, acentoSuave: colorSuave);
}

const sectores = [
  Sector(
    id: 'nails',
    nombre: 'Uñas',
    marca: 'Manicura',
    descripcion: 'Manicura, gel, acrílico y nail art',
    lema: 'Manicura y nail art cerca de ti',
    icono: Icons.front_hand_outlined,
    profesional: 'manicurista',
    elProfesional: 'la manicurista',
    activo: true,
    color: NailsyColors.rosa,
    sobreColor: NailsyColors.sobreRosa,
    colorSuave: NailsyColors.rosaSuave,
    imagen: 'assets/portada/unas.jpg',
    imagenVacio: 'assets/vacio/nails.png',
    clientes: 'Clientas',
    cliente: 'clienta',
    laCliente: 'la clienta',
    lasClientes: 'las clientas',
    nuevoCliente: 'Nueva clienta',
    estilos: estilosBuscables,
    categorias: categorias,
    ficha: fichaUnas,
    cobroPorUna: true,
  ),
  Sector(
    id: 'barberia',
    nombre: 'Barbería',
    marca: 'Barbería',
    descripcion: 'Cortes, degradados y barba',
    lema: 'Cortes y barba cerca de ti',
    icono: Icons.content_cut,
    profesional: 'barbero',
    elProfesional: 'el barbero',
    activo: true,
    color: NailsyColors.azulBarberia,
    sobreColor: NailsyColors.sobreAzulBarberia,
    colorSuave: Color(0xFFA9C4F7),
    imagen: 'assets/portada/barberia.jpg',
    imagenVacio: 'assets/vacio/barberia.png',
    clientes: 'Clientes',
    cliente: 'cliente',
    laCliente: 'el cliente',
    lasClientes: 'los clientes',
    nuevoCliente: 'Nuevo cliente',
    estilos: estilosBarberia,
    categorias: categoriasBarberia,
    ficha: fichaBarberia,
  ),
  Sector(
    id: 'peluqueria',
    nombre: 'Peluquería',
    marca: 'Peluquería',
    descripcion: 'Corte, color y peinados',
    lema: 'Corte, color y peinados cerca de ti',
    icono: Icons.face_3_outlined,
    profesional: 'peluquera',
    elProfesional: 'la peluquera',
    activo: false,
    color: NailsyColors.violetaPeluqueria,
    sobreColor: NailsyColors.sobreVioletaPeluqueria,
    colorSuave: Color(0xFFD0BDF9),
    imagen: 'assets/portada/peluqueria.jpg',
    imagenVacio: 'assets/vacio/peluqueria.png',
    clientes: 'Clientas',
    cliente: 'clienta',
    laCliente: 'la clienta',
    lasClientes: 'las clientas',
    nuevoCliente: 'Nueva clienta',
    estilos: {},
    categorias: {'otro': 'Otro'},
    ficha: fichaBarberia,
  ),
  Sector(
    id: 'estetica',
    nombre: 'Estética',
    marca: 'Estética',
    descripcion: 'Cejas, pestañas, depilación y faciales',
    lema: 'Cejas, pestañas y faciales cerca de ti',
    icono: Icons.spa_outlined,
    profesional: 'esteticista',
    elProfesional: 'la esteticista',
    activo: false,
    color: NailsyColors.salviaEstetica,
    sobreColor: NailsyColors.sobreSalviaEstetica,
    colorSuave: Color(0xFFA8E3CF),
    imagen: 'assets/portada/estetica.jpg',
    imagenVacio: 'assets/vacio/estetica.png',
    clientes: 'Clientas',
    cliente: 'clienta',
    laCliente: 'la clienta',
    lasClientes: 'las clientas',
    nuevoCliente: 'Nueva clienta',
    estilos: {},
    categorias: {'otro': 'Otro'},
    ficha: fichaUnas,
  ),
];

Sector sectorPorId(String? id) => sectores.firstWhere((s) => s.id == id, orElse: () => sectores.first);

/// Sector de la profesional que usa GlamGo Pro (o de la sección abierta en la app de clientes).
class SectorScope extends InheritedWidget {
  const SectorScope({super.key, required this.sector, required super.child});

  final Sector sector;

  static Sector of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SectorScope>()?.sector ?? sectores.first;

  @override
  bool updateShouldNotify(SectorScope oldWidget) => oldWidget.sector.id != sector.id;
}

extension SectorDelContexto on BuildContext {
  Sector get sector => SectorScope.of(this);
}
