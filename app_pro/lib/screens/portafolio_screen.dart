import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/agenda_repo.dart';
import '../models/publico.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Galería de trabajos: lo primero que ven las clientas en el buscador.
class PortafolioScreen extends StatefulWidget {
  const PortafolioScreen({super.key, required this.repo});

  final AgendaRepo repo;

  @override
  State<PortafolioScreen> createState() => _PortafolioScreenState();
}

class _PortafolioScreenState extends State<PortafolioScreen> {
  List<FotoPortafolio> _fotos = [];
  bool _cargando = true;
  int _subiendo = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final f = await widget.repo.fotos();
      if (!mounted) return;
      setState(() {
        _fotos = f;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      aviso(context, mensajeError(e));
    }
  }

  Future<void> _anadir(ImageSource origen) async {
    final picker = ImagePicker();
    final imagenes = origen == ImageSource.camera
        ? [if (await picker.pickImage(source: origen, maxWidth: 1600, imageQuality: 85) case final f?) f]
        : await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85, limit: 10);
    if (imagenes.isEmpty) return;
    setState(() => _subiendo += imagenes.length);
    for (final img in imagenes) {
      try {
        final bytes = await img.readAsBytes();
        final ext = img.name.contains('.') ? img.name.split('.').last : 'jpg';
        await widget.repo.subirFoto(bytes, extension: ext, mime: img.mimeType);
      } catch (e) {
        if (mounted) aviso(context, 'No se pudo subir una foto. ${mensajeError(e)}');
      } finally {
        if (mounted) setState(() => _subiendo--);
      }
    }
    await _cargar();
  }

  Future<void> _elegirOrigen() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Hacer foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen != null) await _anadir(origen);
  }

  Future<void> _opciones(FotoPortafolio f) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NailsyColors.superficie,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(f.publica ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              title: Text(f.publica ? 'Ocultar a las clientas' : 'Mostrar a las clientas'),
              onTap: () => Navigator.pop(ctx, 'visibilidad'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: NailsyColors.rojo),
              title: const Text('Eliminar foto', style: TextStyle(color: NailsyColors.rojo)),
              onTap: () => Navigator.pop(ctx, 'borrar'),
            ),
          ],
        ),
      ),
    );
    if (accion == null) return;
    try {
      if (accion == 'visibilidad') {
        await widget.repo.cambiarVisibilidadFoto(f.id, !f.publica);
      } else {
        await widget.repo.borrarFoto(f);
      }
      await _cargar();
    } catch (e) {
      if (mounted) aviso(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portafolio', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-portafolio',
        tooltip: 'Añadir fotos',
        onPressed: _subiendo > 0 ? null : _elegirOrigen,
        child: _subiendo > 0
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Icon(Icons.add_a_photo_outlined),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _fotos.isEmpty
                  ? ListView(children: [
                      EstadoVacio(
                        icono: Icons.photo_library_outlined,
                        texto: 'Sube fotos de tus mejores trabajos.\nEs lo primero que verán las clientas.',
                        accion: FilledButton.icon(
                          onPressed: _elegirOrigen,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Subir fotos'),
                        ),
                      ),
                    ])
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                      itemCount: _fotos.length,
                      itemBuilder: (_, i) {
                        final f = _fotos[i];
                        return GestureDetector(
                          onTap: () => _opciones(f),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                FotoRemota(url: widget.repo.urlFoto(f.ruta)),
                                if (!f.publica)
                                  Container(
                                    color: Colors.black54,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
