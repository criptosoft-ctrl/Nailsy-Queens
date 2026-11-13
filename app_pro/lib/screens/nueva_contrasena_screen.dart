import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/comunes.dart';

/// Pantalla para elegir contraseña nueva tras pulsar el enlace de recuperación del email.
/// La usan las dos apps.
class NuevaContrasenaScreen extends StatefulWidget {
  const NuevaContrasenaScreen({super.key, required this.guardar, required this.alTerminar});

  final Future<void> Function(String nueva) guardar;
  final VoidCallback alTerminar;

  @override
  State<NuevaContrasenaScreen> createState() => _NuevaContrasenaScreenState();
}

class _NuevaContrasenaScreenState extends State<NuevaContrasenaScreen> {
  final _form = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await widget.guardar(_p1.text);
      if (!mounted) return;
      aviso(context, 'Contraseña cambiada');
      widget.alTerminar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      aviso(context, 'No se pudo cambiar. Pide otro enlace e inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset, size: 56, color: NailsyColors.rosa),
                    const SizedBox(height: 12),
                    const Text('Elige tu nueva contraseña',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _p1,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                      validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _p2,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Repítela'),
                      validator: (v) => v != _p1.text ? 'No coinciden' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Guardar contraseña'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
