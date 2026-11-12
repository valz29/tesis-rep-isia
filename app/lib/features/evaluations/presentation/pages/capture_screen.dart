import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rd_app/app/router/app_routes.dart';
import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/core/theme/app_theme.dart';
import 'package:rd_app/features/evaluations/presentation/widgets/patient_summary.dart';
import 'package:rd_app/features/patients/domain/entities/patient.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

import '../../domain/entities/evaluation_draft.dart';
import '../../domain/repositories/image_acquisition_repository.dart';
import '../controllers/capture_controller.dart';

class CaptureScreen extends StatefulWidget {
  final Patient paciente;
  final SessionController sesion;
  final EvaluationDraft draft;
  const CaptureScreen({
    super.key,
    required this.paciente,
    required this.sesion,
    required this.draft,
  });
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late final CaptureController _capture = widget.sesion
      .createCaptureController();
  List<Uint8List?> get _imagenes =>
      _capture.slots.map((i) => i?.bytes).toList();
  bool get _ocupado => _capture.busy;
  int get _cantidad => _capture.count;

  @override
  void initState() {
    super.initState();
    _capture.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _capture.removeListener(_changed);
    _capture.dispose();
    super.dispose();
  }

  Future<void> _elegir(int indice, ImageOrigin origen) async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await _capture.choose(indice, origen, (image) async {
      if (!mounted) return false;
      return await AppRoutes.preview(context, image, indice + 1) ?? false;
    });
    if (mounted && _capture.error != null) _aviso(_capture.error!);
  }

  void _aviso(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _origen(int indice) async {
    final origen = await showModalBottomSheet<ImageOrigin>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageOrigin.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageOrigin.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (origen != null && mounted) await _elegir(indice, origen);
  }

  void _revisar() {
    if (_cantidad != 3 || _ocupado) return;
    AppRoutes.review(context, widget.paciente, widget.draft, _capture.images);
  }

  void _siguiente(ImageOrigin origen) {
    final indice = _imagenes.indexWhere((imagen) => imagen == null);
    if (indice >= 0) {
      _elegir(indice, origen);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Capturar imágenes')),
    body: PageBody(
      children: [
        PatientSummary(paciente: widget.paciente, ojo: widget.draft.ojo),
        const SizedBox(height: 20),
        _fuente(
          Icons.camera_alt,
          'Tomar foto',
          '(con adaptador)',
          ImageOrigin.camera,
        ),
        const SizedBox(height: 12),
        _fuente(
          Icons.photo_library_outlined,
          'Seleccionar de galería',
          'Añadir una imagen',
          ImageOrigin.gallery,
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Recomendaciones:\n• Usa el adaptador óptico para las capturas.\n• Revisa el enfoque y la iluminación.\n• Las tres tomas deben ser del mismo ojo.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '$_cantidad de 3 imágenes seleccionadas',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _cantidad / 3, minHeight: 5),
        const SizedBox(height: 16),
        for (int i = 0; i < 3; i++) _tarjeta(i),
        if (_ocupado)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('review-images'),
          onPressed: _cantidad == 3 && !_ocupado ? _revisar : null,
          child: const Text('Revisar las tres imágenes'),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );

  Widget _fuente(
    IconData icon,
    String title,
    String subtitle,
    ImageOrigin source,
  ) => OutlinedButton(
    onPressed: _ocupado || _cantidad == 3 ? null : () => _siguiente(source),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );

  Widget _tarjeta(int indice) {
    final imagen = _imagenes[indice];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  imagen == null
                      ? Icons.add_photo_alternate_outlined
                      : Icons.check_circle_outline,
                  color: AppTheme.primario,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Imagen ${indice + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (imagen != null)
                  IconButton(
                    tooltip: 'Quitar imagen ${indice + 1}',
                    onPressed: _ocupado ? null : () => _capture.remove(indice),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (imagen != null) ...[
              InkWell(
                onTap: () =>
                    AppRoutes.image(context, imagen, 'Imagen ${indice + 1}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    imagen,
                    height: 150,
                    fit: BoxFit.contain,
                    cacheWidth: 640,
                    errorBuilder: (_, error, stack) => const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'No se puede mostrar esta imagen. Reemplázala.',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toca la foto para ampliarla',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              key: Key('image-slot-$indice'),
              onPressed: _ocupado ? null : () => _origen(indice),
              icon: Icon(imagen == null ? Icons.add : Icons.swap_horiz),
              label: Text(
                imagen == null
                    ? 'Añadir imagen ${indice + 1}'
                    : 'Reemplazar imagen ${indice + 1}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
