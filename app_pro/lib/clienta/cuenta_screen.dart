import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/selector_idioma.dart';
import 'acceso_clienta.dart';
import 'clienta_repo.dart';
import '../i18n.dart';

class CuentaScreen extends StatefulWidget {
  const CuentaScreen({super.key, required this.repo});

  final ClientaRepo repo;

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  /// En la web, GlamGo Pro está en /pro/ del mismo sitio.
  Future<void> _abrirPro() async {
    final url = kIsWeb ? Uri.parse('${Uri.base.origin}/pro/') : Uri.parse('https://glamgo-es.netlify.app/pro/');
    await launchUrl(url, webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Perfil'), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!repo.conSesion)
            FormAcceso(repo: repo, enHoja: false, alEntrar: () => setState(() {}))
          else ...[
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: NailsyColors.superficie,
                child: Icon(Icons.person, color: NailsyColors.oro),
              ),
              title: Text(repo.nombreUsuaria ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(tr('Cuenta de GlamGo')),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: NailsyColors.rojo),
              title: Text(tr('Cerrar sesión')),
              onTap: () async {
                await repo.salir();
                if (mounted) setState(() {});
              },
            ),
          ],
          const SizedBox(height: 16),
          // Idioma de la app: español, inglés o alemán.
          Material(
            color: NailsyColors.superficie,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: NailsyColors.borde),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.language, color: NailsyColors.oro),
              title: Text(tr('Idioma'), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(idiomaActual.value.nombre),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => mostrarSelectorIdioma(context),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NailsyColors.superficie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NailsyColors.oro.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('¿Eres profesional de la belleza?'),
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  tr('Gestiona tu agenda, tus clientes y aparece en el buscador con GlamGo Pro.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NailsyColors.textoSecundario, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _abrirPro,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NailsyColors.oro,
                    side: const BorderSide(color: NailsyColors.oro),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(tr('Entrar en GlamGo Pro')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
