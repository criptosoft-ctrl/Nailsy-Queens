import 'package:flutter/material.dart';

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
  ),
  Sector(
    id: 'barberia',
    nombre: 'Barbería',
    marca: 'Barbershop',
    descripcion: 'Cortes, degradados y barba',
    icono: Icons.content_cut,
    profesional: 'barbero',
    activo: false,
  ),
  Sector(
    id: 'peluqueria',
    nombre: 'Peluquería',
    marca: 'Peluquería',
    descripcion: 'Corte, color, peinados y tratamientos',
    icono: Icons.face_retouching_natural,
    profesional: 'peluquera',
    activo: false,
  ),
  Sector(
    id: 'estetica',
    nombre: 'Estética',
    marca: 'Estética',
    descripcion: 'Cejas, pestañas, depilación y faciales',
    icono: Icons.spa_outlined,
    profesional: 'esteticista',
    activo: false,
  ),
];

Sector sectorPorId(String? id) => sectores.firstWhere((s) => s.id == id, orElse: () => sectores.first);
