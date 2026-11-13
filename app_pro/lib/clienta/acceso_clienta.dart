import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/comunes.dart';
import 'clienta_repo.dart';

/// Hoja para entrar o crear cuenta de clienta. Devuelve `true` si queda la sesión iniciada.
Future<bool> pedirAcceso(BuildContext context, ClientaRepo repo, {String? motivo}) async {
  if (repo.conSesion) return true;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NailsyColors.superficie,
    showDragHandle: true,
    builder: (_) => FormAcceso(repo: repo, motivo: motivo),
  );
  return ok == true;
}

class FormAcceso extends StatefulWidget {
  const FormAcceso({super.key, required this.repo, this.motivo, this.enHoja = true, this.alEntrar});

  final ClientaRepo repo;
  final String? motivo;
  final bool enHoja;

  /// Se llama al quedar la sesión iniciada (útil cuando no va en una hoja).
  final VoidCallback? alEntrar;

  @override
  State<FormAcceso> createState() => _FormAccesoState();
}

class _FormAccesoState extends State<FormAcceso> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registro = true;
  bool _cargando = false;
  bool _esperandoEmail = false;

  @override
  void dispose() {
    for (final c in [_nombre, _telefono, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      if (_registro) {
        final dentro = await widget.repo.registrarse(
          nombre: _nombre.text,
          email: _email.text,
          password: _password.text,
          telefono: _telefono.text,
        );
        if (!dentro) {
          setState(() {
            _esperandoEmail = true;
            _cargando = false;
          });
          return;
        }
      } else {
        await widget.repo.entrar(_email.text, _password.text);
      }
      widget.alEntrar?.call();
      if (mounted && widget.enHoja) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvide() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      aviso(context, 'Escribe tu email y vuelve a pulsar "¿Olvidaste tu contraseña?".');
      return;
    }
    setState(() => _cargando = true);
    try {
      await widget.repo.recuperarContrasena(email);
      if (mounted) aviso(context, 'Te hemos enviado un enlace a $email. Ábrelo en este mismo móvil o navegador.');
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_esperandoEmail) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 56, color: NailsyColors.rosa),
            const SizedBox(height: 12),
            const Text('Revisa tu email', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Te hemos enviado un enlace a ${_email.text.trim()} para confirmar tu cuenta. '
              'Después vuelve aquí y entra con tu email y contraseña.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: NailsyColors.textoSecundario),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {
                _esperandoEmail = false;
                _registro = false;
              }),
              child: const Text('Ya lo he confirmado, entrar'),
            ),
          ],
        ),
      );
    }
    return Padding(
      // En hoja inferior hay que dejar sitio al teclado; en pantalla completa ya lo hace el Scaffold.
      padding: EdgeInsets.fromLTRB(20, 0, 20, (widget.enHoja ? MediaQuery.viewInsetsOf(context).bottom : 0) + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_registro ? 'Crea tu cuenta' : 'Entra en tu cuenta',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              if (widget.motivo != null) ...[
                const SizedBox(height: 4),
                Text(widget.motivo!, style: const TextStyle(color: NailsyColors.textoSecundario)),
              ],
              const SizedBox(height: 16),
              if (_registro) ...[
                TextFormField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombre y apellido'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono (para avisarte de tu cita)'),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email no válido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Contraseña'),
                validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _cargando ? null : _enviar,
                child: _cargando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(_registro ? 'Crear cuenta' : 'Entrar'),
              ),
              if (!_registro)
                TextButton(
                  onPressed: _cargando ? null : _olvide,
                  child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: NailsyColors.textoSecundario)),
                ),
              TextButton(
                onPressed: _cargando ? null : () => setState(() => _registro = !_registro),
                child: Text(_registro ? '¿Ya tienes cuenta? Entra' : '¿No tienes cuenta? Créala',
                    style: const TextStyle(color: NailsyColors.rosaSuave)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
