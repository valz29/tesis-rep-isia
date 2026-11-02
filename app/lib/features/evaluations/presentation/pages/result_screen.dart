import '../formatters/evaluation_labels.dart';

import 'package:rd_app/app/router/app_routes.dart';
import 'package:flutter/material.dart';

import 'package:rd_app/features/evaluations/domain/entities/evaluation.dart';
import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/shared/widgets/page_body.dart';
import 'package:rd_app/features/evaluations/presentation/widgets/patient_summary.dart';

class ResultScreen extends StatelessWidget {
  final Evaluation evaluacion;
  final SessionController sesion;
  final bool desdeHistorial;
  const ResultScreen({
    super.key,
    required this.evaluacion,
    required this.sesion,
    this.desdeHistorial = false,
  });

  void _nueva(BuildContext context) {
    AppRoutes.newEvaluation(context);
  }

  Future<void> _guardar(BuildContext context) async {
    final controller = sesion.evaluations;
    final ok = await controller.save(evaluacion);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Evaluación añadida al historial.'
              : controller.error ?? 'No se pudo guardar la evaluación',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sesion.evaluations,
    builder: (context, _) {
      final guardada = sesion.evaluations.isSaved(evaluacion.id);
      return Scaffold(
        appBar: AppBar(title: const Text('Resultado')),
        body: PageBody(
          children: [
            const Text(
              'Grado —',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Pendiente de análisis', textAlign: TextAlign.center),
            const SizedBox(height: 20),

            const SizedBox(height: 20),
            PatientSummary(
              paciente: sesion.patients.byId(evaluacion.patientId)!,
              ojo: evaluacion.ojo,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => AppRoutes.image(
                      context,
                      evaluacion.imagenes.first.bytes,
                      'Imagen 1',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        evaluacion.imagenes.first.bytes,
                        height: 135,
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 10,
                      ),
                      child: Column(
                        children: [
                          Text('Confianza', textAlign: TextAlign.center),
                          SizedBox(height: 10),
                          Text(
                            '—',
                            style: TextStyle(
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
            const Text(
              'Las tres imágenes del ojo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (int i = 0; i < 3; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => AppRoutes.image(
                              context,
                              evaluacion.imagenes[i].bytes,
                              'Imagen ${i + 1}',
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                evaluacion.imagenes[i].bytes,
                                height: 76,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                cacheWidth: 180,
                              ),
                            ),
                          ),
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
            const Text('Sin resultado disponible.'),
            const SizedBox(height: 20),
            const Text(
              'Recomendación',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text('Sin recomendación disponible.'),
            if (evaluacion.observaciones != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Observaciones',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(evaluacion.observaciones!),
            ],
            const SizedBox(height: 20),
            Text(
              evaluacion.fechaLabel,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: guardada || sesion.evaluations.busy
                        ? null
                        : () => _guardar(context),
                    child: Text(guardada ? 'Guardado' : 'Guardar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _nueva(context),
                    child: const Text('Nueva evaluación'),
                  ),
                ),
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
