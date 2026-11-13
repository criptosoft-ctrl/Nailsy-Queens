import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registro = false;
  bool _cargando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    final auth = Supabase.instance.client.auth;
    try {
      if (_registro) {
        final res = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'nombre': _nombre.text.trim()},
          emailRedirectTo: kIsWeb ? '${Uri.base.origin}/pro/' : null,
        );
        if (res.session == null && mounted) {
          _aviso('Te hemos enviado un email para confirmar la cuenta.');
        }
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
    } on AuthException catch (e) {
      _aviso(_traducir(e.message));
    } catch (_) {
      _aviso('No se pudo conectar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _traducir(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) return 'Email o contraseña incorrectos.';
    if (m.contains('already registered')) return 'Ya existe una cuenta con ese email.';
    if (m.contains('email not confirmed')) return 'Confirma tu email antes de entrar.';
    return msg;
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
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
                    const Text(
                      'Nailsy Queens',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: NailsyColors.rosa),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tu agenda de manicura, sin ausencias',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NailsyColors.textoSecundario),
                    ),
                    const SizedBox(height: 36),
                    if (_registro) ...[
                      TextFormField(
                        controller: _nombre,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Tu nombre'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Email no válido' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _cargando ? null : _enviar,
                      child: _cargando
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(_registro ? 'Crear cuenta' : 'Entrar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _cargando ? null : () => setState(() => _registro = !_registro),
                      child: Text(
                        _registro ? '¿Ya tienes cuenta? Entra' : '¿Eres nueva? Crea tu cuenta',
                        style: const TextStyle(color: NailsyColors.rosaSuave),
                      ),
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
