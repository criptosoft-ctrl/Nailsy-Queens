import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'acceso_clienta.dart';
import 'clienta_repo.dart';

class CuentaScreen extends StatefulWidget {
  const CuentaScreen({super.key, required this.repo});

  final ClientaRepo repo;

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  /// En la web, Nailsy Pro está en /pro/ del mismo sitio.
  Future<void> _abrirPro() async {
    final url = kIsWeb ? Uri.parse('${Uri.base.origin}/pro/') : Uri.parse('https://nailsy-queens.netlify.app/pro/');
    await launchUrl(url, webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!repo.conSesion)
            FormAcceso(repo: repo, enHoja: false, alEntrar: () => setState(() {}))
          else ...[
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: NailsyColors.superficie,
                child: Icon(Icons.person, color: NailsyColors.rosa),
              ),
              title: Text(repo.nombreUsuaria ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Cuenta de clienta'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: NailsyColors.rojo),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                await repo.salir();
                if (mounted) setState(() {});
              },
            ),
          ],
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NailsyColors.superficie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NailsyColors.rosa.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('¿Eres manicurista?',
                    textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'Gestiona tu agenda, tus clientas y aparece en el buscador con Nailsy Pro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _abrirPro,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NailsyColors.rosa,
                    side: const BorderSide(color: NailsyColors.rosa),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Entrar en Nailsy Pro'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
