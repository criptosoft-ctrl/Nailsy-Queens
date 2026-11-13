import 'package:flutter/material.dart';

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
          const SizedBox(height: 24),
          const Text(
            '¿Eres manicurista? Usa Nailsy Pro para gestionar tu agenda y aparecer en el buscador.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NailsyColors.textoSecundario, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
