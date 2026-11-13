import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/agenda_repo.dart';
import '../models/catalogo.dart';
import '../models/clienta.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'clientas_screen.dart';

/// Crear una cita: clienta → servicio → añadidos → día y hora.
/// La duración y el precio se calculan solos (el precio se puede retocar).
/// Devuelve `true` si se ha guardado.
class NuevaCitaScreen extends StatefulWidget {
  const NuevaCitaScreen({super.key, required this.repo, required this.dia});

  final AgendaRepo repo;
  final DateTime dia;

  @override
  State<NuevaCitaScreen> createState() => _NuevaCitaScreenState();
}

class _NuevaCitaScreenState extends State<NuevaCitaScreen> {
  List<Clienta> _clientas = [];
  List<Servicio> _servicios = [];
  List<Anadido> _anadidos = [];
  bool _cargando = true;
  bool _guardando = false;

  Clienta? _clienta;
  Servicio? _servicio;
  final Map<String, int> _cantidades = {};
  late DateTime _fecha = widget.dia;
  TimeOfDay? _hora;
  final _precioManual = TextEditingController();
  bool _precioEditado = false;
  final _notas = TextEditingController();

  Presupuesto get _presupuesto => Presupuesto.calcular(_servicio, _anadidos, _cantidades);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _precioManual.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final c = await widget.repo.clientas();
      final s = await widget.repo.servicios();
      final a = await widget.repo.anadidos();
      if (!mounted) return;
      setState(() {
        _clientas = c;
        _servicios = s;
        _anadidos = a;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  void _recalcularPrecio() {
    if (!_precioEditado) {
      final p = _presupuesto.precio;
      _precioManual.text = p == p.roundToDouble() ? p.toInt().toString() : p.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  Future<void> _elegirClienta() async {
    final elegida = await showModalBottomSheet<Clienta>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      builder: (_) => _SelectorClienta(clientas: _clientas),
    );
    if (elegida == null || !mounted) return;
    if (elegida.id == null) {
      // "Nueva clienta"
      final nueva = await editarClienta(context, widget.repo);
      if (nueva == null || !mounted) return;
      setState(() {
        _clientas = [..._clientas, nueva];
        _clienta = nueva;
      });
    } else {
      setState(() => _clienta = elegida);
    }
  }

  Future<void> _elegirFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _elegirHora() async {
    final h = await elegirHoraRueda(context, inicial: _hora, titulo: 'Hora de la cita');
    if (h != null) setState(() => _hora = h);
  }

  Future<void> _guardar() async {
    final faltan = [
      if (_clienta == null) 'la clienta',
      if (_servicio == null) 'el servicio',
      if (_hora == null) 'la hora',
    ];
    if (faltan.isNotEmpty) {
      aviso(context, 'Falta elegir ${faltan.join(', ')}.');
      return;
    }
    final precioFinal = leerNumero(_precioManual.text);
    if (precioFinal == null || precioFinal < 0) {
      aviso(context, 'El precio no es válido.');
      return;
    }
    setState(() => _guardando = true);
    final inicio = DateTime(_fecha.year, _fecha.month, _fecha.day, _hora!.hour, _hora!.minute);
    try {
      await widget.repo.crearCita(NuevaCita(
        clientaId: _clienta!.id!,
        servicio: _servicio!,
        inicio: inicio,
        duracionMin: _presupuesto.duracionMin,
        precio: precioFinal,
        anadidos: Map.of(_cantidades),
        notas: _notas.text,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      aviso(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _presupuesto;
    final fin = _hora == null
        ? null
        : DateTime(_fecha.year, _fecha.month, _fecha.day, _hora!.hour, _hora!.minute).add(Duration(minutes: p.duracionMin));

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva cita', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
              children: [
                // ---- Clienta ----
                const TituloSeccion('Clienta'),
                Tarjeta(
                  onTap: _elegirClienta,
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: NailsyColors.rosaSuave),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_clienta?.nombre ?? 'Elegir clienta',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _clienta == null ? NailsyColors.textoSecundario : null)),
                      ),
                      const Icon(Icons.chevron_right, color: NailsyColors.gris),
                    ],
                  ),
                ),
                if (_clienta?.tieneAlergias ?? false) ...[
                  const SizedBox(height: 8),
                  AvisoAlergia(alergias: _clienta!.alergias.map(etiquetaAlergia).toList()),
                ],

                // ---- Servicio ----
                const TituloSeccion('Servicio'),
                if (_servicios.isEmpty)
                  const Tarjeta(
                    child: Text('Primero añade tus servicios en la pestaña Tarifario.',
                        style: TextStyle(color: NailsyColors.textoSecundario)),
                  ),
                for (final s in _servicios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Opcion(
                      seleccionada: _servicio?.id == s.id,
                      titulo: s.nombre,
                      subtitulo: formatoDuracion(s.duracionMin),
                      precio: precio(s.precio),
                      onTap: () => setState(() {
                        _servicio = s;
                        _recalcularPrecio();
                      }),
                    ),
                  ),

                // ---- Añadidos ----
                if (_anadidos.isNotEmpty) ...[
                  const TituloSeccion('Nail Art y extras'),
                  for (final a in _anadidos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FilaAnadido(
                        anadido: a,
                        cantidad: _cantidades[a.id] ?? 0,
                        onCambio: (n) => setState(() {
                          _cantidades[a.id!] = n;
                          _recalcularPrecio();
                        }),
                      ),
                    ),
                ],

                // ---- Día y hora ----
                const TituloSeccion('Día y hora'),
                Row(
                  children: [
                    Expanded(
                      child: Tarjeta(
                        onTap: _elegirFecha,
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined, color: NailsyColors.rosaSuave),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(DateFormat('EEE d MMM', 'es').format(_fecha),
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Tarjeta(
                        onTap: _elegirHora,
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, color: NailsyColors.rosaSuave),
                            const SizedBox(width: 10),
                            Text(
                              _hora == null
                                  ? 'Hora'
                                  : '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _hora == null ? NailsyColors.textoSecundario : null),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // ---- Notas ----
                const TituloSeccion('Notas'),
                TextField(
                  controller: _notas,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Diseño que quiere, referencias… (opcional)'),
                ),
              ],
            ),
      bottomNavigationBar: _cargando
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: NailsyColors.superficie,
                  border: Border(top: BorderSide(color: NailsyColors.borde)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.duracionMin == 0 ? 'Duración —' : 'Duración ${formatoDuracion(p.duracionMin)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (fin != null && p.duracionMin > 0)
                                Text('Termina a las ${DateFormat('HH:mm').format(fin)}',
                                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            key: const Key('precio-total'),
                            controller: _precioManual,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(suffixText: '€', isDense: true, labelText: 'Precio'),
                            onChanged: (_) => _precioEditado = true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Guardar cita'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.seleccionada,
    required this.titulo,
    required this.subtitulo,
    required this.precio,
    required this.onTap,
  });

  final bool seleccionada;
  final String titulo;
  final String subtitulo;
  final String precio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionada ? NailsyColors.rosa.withValues(alpha: 0.15) : NailsyColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: seleccionada ? NailsyColors.rosa : Colors.transparent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(seleccionada ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: seleccionada ? NailsyColors.rosa : NailsyColors.gris),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(subtitulo, style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
                  ],
                ),
              ),
              Text(precio, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaAnadido extends StatelessWidget {
  const _FilaAnadido({required this.anadido, required this.cantidad, required this.onCambio});

  final Anadido anadido;
  final int cantidad;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final a = anadido;
    final activo = cantidad > 0;
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('+${precio(a.precio)}${a.porUna ? ' por uña' : ''} · +${formatoDuracion(a.duracionMin)}',
                    style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13)),
              ],
            ),
          ),
          if (!a.porUna)
            Switch(value: activo, onChanged: (v) => onCambio(v ? 1 : 0))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Menos uñas',
                  onPressed: cantidad > 0 ? () => onCambio(cantidad - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 26,
                  child: Text('$cantidad',
                      textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                IconButton(
                  tooltip: 'Más uñas',
                  onPressed: cantidad < 20 ? () => onCambio(cantidad + 1) : null,
                  icon: const Icon(Icons.add_circle_outline, color: NailsyColors.rosa),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SelectorClienta extends StatefulWidget {
  const _SelectorClienta({required this.clientas});
  final List<Clienta> clientas;

  @override
  State<_SelectorClienta> createState() => _SelectorClientaState();
}

class _SelectorClientaState extends State<_SelectorClienta> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final lista = widget.clientas.where((c) => c.nombre.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Buscar clienta', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1, color: NailsyColors.rosa),
              title: const Text('Nueva clienta', style: TextStyle(color: NailsyColors.rosa, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(context, const Clienta(nombre: '')),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final c in lista)
                    ListTile(
                      title: Text(c.nombre),
                      subtitle: c.tieneAlergias
                          ? Text('Alergia: ${c.alergias.map(etiquetaAlergia).join(', ')}',
                              style: const TextStyle(color: NailsyColors.rojo))
                          : (c.telefono == null ? null : Text(c.telefono!)),
                      onTap: () => Navigator.pop(context, c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
