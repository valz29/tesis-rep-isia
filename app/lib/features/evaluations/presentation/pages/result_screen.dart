import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/session_controller.dart';
import '../../../../shared/widgets/page_body.dart';
import '../../domain/entities/evaluation.dart';
import '../formatters/evaluation_labels.dart';
import '../widgets/patient_summary.dart';

class ResultScreen extends StatefulWidget {
  final Evaluation evaluacion;
  final SessionController sesion;
  final bool desdeHistorial;
  const ResultScreen({
    super.key,
    required this.evaluacion,
    required this.sesion,
    this.desdeHistorial = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Evaluation get evaluacion => widget.evaluacion;
  SessionController get sesion => widget.sesion;
  bool get desdeHistorial => widget.desdeHistorial;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final record = sesion.evaluations.byId(evaluacion.id) ?? evaluacion;
      if (record.imagesStored && record.imagenes.isEmpty) {
        sesion.evaluations.loadImages(record.id);
      }
    });
  }

  Future<void> _guardar(BuildContext context) async {
    final ok = await sesion.evaluations.save(evaluacion);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Datos de evaluación añadidos al historial.'
              : sesion.evaluations.error ?? 'No se pudo guardar la evaluación',
        ),
      ),
    );
  }

  Widget _photo(
    BuildContext context,
    Evaluation record,
    int i, {
    double height = 135,
  }) {
    if (record.imagenes.length <= i) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 40),
        ),
      );
    }
    final bytes = record.imagenes[i].bytes;
    return InkWell(
      onTap: () => AppRoutes.image(context, bytes, 'Imagen ${i + 1}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.contain,
          cacheWidth: 320,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sesion.changes,
    builder: (context, _) {
      final record = sesion.evaluations.byId(evaluacion.id) ?? evaluacion;
      final patient = sesion.patients.byId(record.patientId);
      final saved = sesion.evaluations.isSaved(record.id);
      final result = record.result;
      return Scaffold(
        appBar: AppBar(title: const Text('Resultado')),
        body: PageBody(
          children: [
            Text(
              result == null ? 'Grado —' : 'Grado ${result.gradoICDR}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(record.statusLabel, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (sesion.isAdmin && saved)
              OutlinedButton.icon(
                onPressed: () => AppRoutes.adminEvaluation(context, record),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar evaluación'),
              ),
            if (patient != null)
              PatientSummary(paciente: patient, ojo: record.ojo),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _photo(context, record, 0)),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 10,
                      ),
                      child: Column(
                        children: [
                          const Text('Confianza'),
                          const SizedBox(height: 10),
                          Text(
                            result?.confianza == null
                                ? '—'
                                : '${(result!.confianza! * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (record.imagesStored && record.imagenes.isEmpty) ...[
              if (sesion.evaluations.loadingImagesFor == record.id)
                const LinearProgressIndicator(),
              if (sesion.evaluations.imageError != null)
                Text(sesion.evaluations.imageError!),
              TextButton.icon(
                onPressed: sesion.evaluations.loadingImagesFor != null
                    ? null
                    : () => sesion.evaluations.loadImages(record.id),
                icon: const Icon(Icons.refresh),
                label: const Text('Recuperar imágenes'),
              ),
            ],
            const Text(
              'Las tres imágenes del ojo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          _photo(context, record, i, height: 76),
                          const SizedBox(height: 6),
                          Text(
                            'Imagen ${i + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Descripción',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              record.status == EvaluationStatus.draft
                  ? 'Se conserva la información de la evaluación. Las fotografías aún no están almacenadas en la nube.'
                  : result == null
                  ? 'Sin resultado disponible.'
                  : 'Versión del modelo: ${result.modelVersion}',
            ),
            const SizedBox(height: 20),
            const Text(
              'Recomendación',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text('Sin recomendación disponible.'),
            if (record.observaciones != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Observaciones',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(record.observaciones!),
            ],
            const SizedBox(height: 20),
            Text(
              record.fechaLabel,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: saved || sesion.evaluations.busy
                        ? null
                        : () => _guardar(context),
                    child: Text(saved ? 'Guardado' : 'Guardar'),
                  ),
                ),
                ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppRoutes.newEvaluation(context),
                      child: const Text('Nueva evaluación'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                if (desdeHistorial) {
                  Navigator.pop(context);
                } else {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
              child: Text(
                desdeHistorial ? 'Volver al historial' : 'Volver al inicio',
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}
