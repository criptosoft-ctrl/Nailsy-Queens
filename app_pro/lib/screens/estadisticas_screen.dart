import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/agenda_repo.dart';
import '../models/cita.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Cifras del mes calculadas a partir de las citas.
class ResumenMes {
  ResumenMes(List<Cita> citas, DateTime ahora)
      : completadas = citas.where((c) => c.estado == EstadoCita.completada).toList(),
        noShows = citas.where((c) => c.estado == EstadoCita.noShow).length,
        canceladas = citas.where((c) => c.estado == EstadoCita.cancelada).length,
        pendientes = citas.where((c) => c.activa && c.estado != EstadoCita.completada && c.inicio.isAfter(ahora)).toList(),
        total = citas.length;

  final List<Cita> completadas;
  final List<Cita> pendientes;
  final int noShows;
  final int canceladas;
  final int total;

  double get ingresos => completadas.fold(0, (s, c) => s + c.precio);
  double get previsto => pendientes.fold(0, (s, c) => s + c.precio);
  double get ticketMedio => completadas.isEmpty ? 0 : ingresos / completadas.length;
  int get clientas => completadas.map((c) => c.clientaId ?? c.clientaNombre).toSet().length;

  /// % de citas a las que la clienta no vino (sobre las que ya pasaron).
  double get tasaAusencias {
    final pasadas = completadas.length + noShows;
    return pasadas == 0 ? 0 : noShows / pasadas;
  }

  /// Ingresos por semana del mes (semana 1 = días 1-7…).
  List<double> get porSemana {
    final r = List<double>.filled(5, 0);
    for (final c in completadas) {
      r[((c.inicio.day - 1) ~/ 7).clamp(0, 4)] += c.precio;
    }
    return r;
  }

  /// Servicios más hechos: (nombre, veces, ingresos).
  List<(String, int, double)> get topServicios {
    final m = <String, (int, double)>{};
    for (final c in completadas) {
      final a = m[c.servicioNombre] ?? (0, 0.0);
      m[c.servicioNombre] = (a.$1 + 1, a.$2 + c.precio);
    }
    final l = [for (final e in m.entries) (e.key, e.value.$1, e.value.$2)]..sort((a, b) => b.$3.compareTo(a.$3));
    return l.take(5).toList();
  }
}

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key, required this.repo, this.ahora});

  final AgendaRepo repo;
  final DateTime Function()? ahora;

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  late DateTime _mes;
  ResumenMes? _r;
  bool _cargando = true;

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final a = _ahora;
    _mes = DateTime(a.year, a.month);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final citas = await widget.repo.citasEntre(_mes, DateTime(_mes.year, _mes.month + 1));
      if (!mounted) return;
      setState(() {
        _r = ResumenMes(citas, _ahora);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  void _mover(int meses) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + meses));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final nombreMes = DateFormat('MMMM yyyy', 'es').format(_mes);
    final r = _r;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            const Text('Estadísticas', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(tooltip: 'Mes anterior', onPressed: () => _mover(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text('${nombreMes[0].toUpperCase()}${nombreMes.substring(1)}',
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                IconButton(tooltip: 'Mes siguiente', onPressed: () => _mover(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 8),
            if (_cargando || r == null)
              const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
            else ...[
              // ---- Ingresos ----
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A1E3A), NailsyColors.superficie],
                  ),
                  border: Border.all(color: NailsyColors.rosa.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ingresos cobrados', style: TextStyle(color: NailsyColors.textoSecundario)),
                    const SizedBox(height: 4),
                    Text(precio(r.ingresos), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
                    if (r.previsto > 0)
                      Text('+ ${precio(r.previsto)} previstos en citas próximas',
                          style: const TextStyle(color: NailsyColors.rosaSuave, fontSize: 13.5)),
                    const SizedBox(height: 18),
                    _Barras(valores: r.porSemana),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ---- Cifras ----
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.9,
                children: [
                  _Cifra('Citas hechas', '${r.completadas.length}', Icons.check_circle_outline, NailsyColors.verde),
                  _Cifra('Ticket medio', precio(r.ticketMedio.roundToDouble()), Icons.sell_outlined, NailsyColors.rosa),
                  _Cifra('Clientas atendidas', '${r.clientas}', Icons.people_outline, NailsyColors.rosaSuave),
                  _Cifra('Ausencias', '${r.noShows} · ${(r.tasaAusencias * 100).round()} %', Icons.person_off_outlined,
                      r.noShows == 0 ? NailsyColors.verde : NailsyColors.rojo),
                ],
              ),
              const TituloSeccion('Servicios más hechos'),
              if (r.topServicios.isEmpty)
                const Tarjeta(
                    child: Text('Aún no hay citas completadas este mes.',
                        style: TextStyle(color: NailsyColors.textoSecundario)))
              else
                for (final (nombre, veces, euros) in r.topServicios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Tarjeta(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('$veces ${veces == 1 ? 'vez' : 'veces'}',
                                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(precio(euros), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor, this.icono, this.color);

  final String etiqueta;
  final String valor;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NailsyColors.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NailsyColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Barras extends StatelessWidget {
  const _Barras({required this.valores});

  final List<double> valores;

  @override
  Widget build(BuildContext context) {
    final maximo = valores.fold<double>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < valores.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (valores[i] > 0)
                      Text(precio(valores[i]),
                          style: const TextStyle(fontSize: 11, color: NailsyColors.textoSecundario)),
                    const SizedBox(height: 4),
                    Container(
                      height: maximo == 0 ? 4 : 4 + 70 * (valores[i] / maximo),
                      decoration: BoxDecoration(
                        color: valores[i] == maximo && maximo > 0 ? NailsyColors.rosa : NailsyColors.rosa.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Sem ${i + 1}', style: const TextStyle(fontSize: 11, color: NailsyColors.textoSecundario)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
