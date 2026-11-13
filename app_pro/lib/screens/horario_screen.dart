import 'package:flutter/material.dart';

import '../data/agenda_repo.dart';
import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Horario de trabajo semanal: de aquí salen los huecos que pueden reservar las clientas.
class HorarioScreen extends StatefulWidget {
  const HorarioScreen({super.key, required this.repo});

  final AgendaRepo repo;

  @override
  State<HorarioScreen> createState() => _HorarioScreenState();
}

class _Dia {
  _Dia({required this.activo, required this.inicio, required this.fin, this.pausa = false, int? pausaIni, int? pausaFin})
      : pausaIni = pausaIni ?? 14 * 60,
        pausaFin = pausaFin ?? 15 * 60;
  bool activo;
  int inicio;
  int fin;
  bool pausa;
  int pausaIni;
  int pausaFin;
}

class _HorarioScreenState extends State<HorarioScreen> {
  final _dias = List.generate(7, (i) => _Dia(activo: i < 5, inicio: 9 * 60, fin: 19 * 60));
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final franjas = await widget.repo.horario();
      if (!mounted) return;
      if (franjas.isNotEmpty) {
        for (var d = 1; d <= 7; d++) {
          final del = franjas.where((f) => f.dia == d).toList()..sort((a, b) => a.inicioMin.compareTo(b.inicioMin));
          final dia = _dias[d - 1];
          dia.activo = del.isNotEmpty;
          if (del.isNotEmpty) {
            dia.inicio = del.first.inicioMin;
            dia.fin = del.last.finMin;
            dia.pausa = del.length > 1;
            if (dia.pausa) {
              dia.pausaIni = del.first.finMin;
              dia.pausaFin = del[1].inicioMin;
            }
          }
        }
      }
      setState(() => _cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  Future<void> _elegir(int actual, ValueChanged<int> onElegido) async {
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: actual ~/ 60, minute: actual % 60),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (h != null) setState(() => onElegido(h.hour * 60 + h.minute));
  }

  List<FranjaHorario>? _franjas() {
    final res = <FranjaHorario>[];
    for (var i = 0; i < 7; i++) {
      final d = _dias[i];
      if (!d.activo) continue;
      if (d.fin <= d.inicio) return null;
      if (d.pausa) {
        if (!(d.inicio < d.pausaIni && d.pausaIni < d.pausaFin && d.pausaFin < d.fin)) return null;
        res.add(FranjaHorario(dia: i + 1, inicioMin: d.inicio, finMin: d.pausaIni));
        res.add(FranjaHorario(dia: i + 1, inicioMin: d.pausaFin, finMin: d.fin));
      } else {
        res.add(FranjaHorario(dia: i + 1, inicioMin: d.inicio, finMin: d.fin));
      }
    }
    return res;
  }

  Future<void> _guardar() async {
    final franjas = _franjas();
    if (franjas == null) {
      aviso(context, 'Revisa las horas: el fin debe ser posterior al inicio y la pausa debe quedar dentro.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.repo.guardarHorario(franjas);
      if (!mounted) return;
      aviso(context, 'Horario guardado');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      aviso(context, mensajeError(e));
    }
  }

  Widget _boton(String texto, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(72, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: const BorderSide(color: NailsyColors.borde),
        ),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final t = FranjaHorario.aTexto;
    return Scaffold(
      appBar: AppBar(title: const Text('Horario de trabajo')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Las clientas solo pueden reservar dentro de este horario y en los huecos que no tengas ocupados.',
                    style: TextStyle(color: NailsyColors.textoSecundario),
                  ),
                ),
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Tarjeta(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(diasSemana[i], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                              Text(_dias[i].activo ? 'Abierto' : 'Cerrado',
                                  style: TextStyle(color: _dias[i].activo ? NailsyColors.verde : NailsyColors.gris)),
                              Switch(value: _dias[i].activo, onChanged: (v) => setState(() => _dias[i].activo = v)),
                            ],
                          ),
                          if (_dias[i].activo) ...[
                            Row(
                              children: [
                                _boton(t(_dias[i].inicio), () => _elegir(_dias[i].inicio, (m) => _dias[i].inicio = m)),
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('a')),
                                _boton(t(_dias[i].fin), () => _elegir(_dias[i].fin, (m) => _dias[i].fin = m)),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => setState(() => _dias[i].pausa = !_dias[i].pausa),
                                  child: Text(_dias[i].pausa ? 'Quitar pausa' : '+ Pausa'),
                                ),
                              ],
                            ),
                            if (_dias[i].pausa)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Text('Pausa', style: TextStyle(color: NailsyColors.textoSecundario)),
                                    const SizedBox(width: 10),
                                    _boton(t(_dias[i].pausaIni),
                                        () => _elegir(_dias[i].pausaIni, (m) => _dias[i].pausaIni = m)),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('a')),
                                    _boton(t(_dias[i].pausaFin),
                                        () => _elegir(_dias[i].pausaFin, (m) => _dias[i].pausaFin = m)),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _cargando
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Guardar horario'),
                ),
              ),
            ),
    );
  }
}
