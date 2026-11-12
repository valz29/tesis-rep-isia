import 'package:flutter/material.dart';

import '../../domain/entities/evaluation.dart';
import '../../domain/entities/evaluation_image.dart';
import '../controllers/evaluations_controller.dart';

/// Loads previews for visible history rows without opening their detail page.
class EvaluationThumbnail extends StatefulWidget {
  final Evaluation evaluation;
  final EvaluationsController controller;

  const EvaluationThumbnail({
    super.key,
    required this.evaluation,
    required this.controller,
  });

  @override
  State<EvaluationThumbnail> createState() => _EvaluationThumbnailState();
}

class _EvaluationThumbnailState extends State<EvaluationThumbnail> {
  late Future<EvaluationImage?> _preview = _load();

  Future<EvaluationImage?> _load() =>
      widget.controller.loadThumbnail(widget.evaluation.id);

  @override
  void didUpdateWidget(EvaluationThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evaluation != widget.evaluation ||
        oldWidget.controller != widget.controller) {
      _preview = _load();
    }
  }

  void _retry() => setState(() {
    _preview = _load();
  });

  @override
  Widget build(BuildContext context) {
    final local = widget.evaluation.imagenes.firstOrNull;
    return SizedBox(
      width: 56,
      height: 56,
      child: local != null
          ? _image(local)
          : !widget.evaluation.imagesStored
          ? const Tooltip(
              message: 'Las imágenes todavía están pendientes de carga',
              child: Icon(Icons.cloud_upload_outlined),
            )
          : FutureBuilder<EvaluationImage?>(
              future: _preview,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.data == null) {
                  return IconButton(
                    tooltip: 'Reintentar miniatura',
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                  );
                }
                return _image(snapshot.data!);
              },
            ),
    );
  }

  Widget _image(EvaluationImage image) => ClipRRect(
    borderRadius: BorderRadius.circular(7),
    child: Image.memory(
      image.bytes,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      cacheWidth: 128,
      errorBuilder: (_, error, stack) => IconButton(
        tooltip: 'Reintentar miniatura',
        onPressed: _retry,
        icon: const Icon(Icons.refresh),
      ),
    ),
  );
}
