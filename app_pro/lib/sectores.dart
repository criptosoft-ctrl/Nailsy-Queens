import 'package:flutter/material.dart';

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
    required this.icono,
    required this.profesional,
    required this.activo,
    required this.color,
    required this.sobreColor,
    required this.colorSuave,
  });

  final String id;

  /// Nombre del servicio ("Uñas", "Barbería"…).
  final String nombre;

  /// Nombre de la sección dentro de GlamGo ("Nailsy Queens"…).
  final String marca;
  final String descripcion;
  final IconData icono;

  /// Cómo se llama a la profesional ("manicurista", "barbero"…).
  final String profesional;

  /// Si ya se puede reservar en esta sección.
  final bool activo;

  /// Color de acento de la sección, el texto que va encima y su versión clara.
  final Color color;
  final Color sobreColor;
  final Color colorSuave;

  ThemeData get tema => nailsyTheme(acento: color, sobreAcento: sobreColor, acentoSuave: colorSuave);
}

const sectores = [
  Sector(
    id: 'nails',
    nombre: 'Uñas',
    marca: 'Nailsy Queens',
    descripcion: 'Manicura, gel, acrílico y nail art',
    icono: Icons.back_hand_outlined,
    profesional: 'manicurista',
    activo: true,
    color: NailsyColors.rosa,
    sobreColor: NailsyColors.sobreRosa,
    colorSuave: NailsyColors.rosaSuave,
  ),
  Sector(
    id: 'barberia',
    nombre: 'Barbería',
    marca: 'Barbershop',
    descripcion: 'Cortes, degradados y barba',
    icono: Icons.content_cut,
    profesional: 'barbero',
    activo: false,
    color: NailsyColors.azulBarberia,
    sobreColor: NailsyColors.sobreAzulBarberia,
    colorSuave: Color(0xFFA9C4F7),
  ),
  Sector(
    id: 'peluqueria',
    nombre: 'Peluquería',
    marca: 'Peluquería',
    descripcion: 'Corte, color y peinados',
    icono: Icons.face_retouching_natural,
    profesional: 'peluquera',
    activo: false,
    color: NailsyColors.violetaPeluqueria,
    sobreColor: NailsyColors.sobreVioletaPeluqueria,
    colorSuave: Color(0xFFD0BDF9),
  ),
  Sector(
    id: 'estetica',
    nombre: 'Estética',
    marca: 'Estética',
    descripcion: 'Cejas, pestañas, depilación y faciales',
    icono: Icons.spa_outlined,
    profesional: 'esteticista',
    activo: false,
    color: NailsyColors.salviaEstetica,
    sobreColor: NailsyColors.sobreSalviaEstetica,
    colorSuave: Color(0xFFA8E3CF),
  ),
];

Sector sectorPorId(String? id) => sectores.firstWhere((s) => s.id == id, orElse: () => sectores.first);
