import 'package:flutter/material.dart';

import '../../domain/entities/evaluation_draft.dart';

import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

class StatisticsScreen extends StatelessWidget {
  final SessionController sesion;
  const StatisticsScreen({super.key, required this.sesion});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sesion.changes,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: PageBody(
        children: [
          const SizedBox(height: 24),
          _dato(
            'Pacientes registrados',
            sesion.patients.patients.length,
            Icons.people_outline,
          ),
          _dato(
            'Evaluaciones guardadas',
            sesion.evaluations.evaluations.length,
            Icons.fact_check_outlined,
          ),
          _dato(
            'Imágenes en evaluaciones',
            sesion.evaluations.imageCount,
            Icons.collections_outlined,
          ),
          const SizedBox(height: 24),
          const Text(
            'Evaluaciones por ojo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          for (final eye in OjoEvaluado.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${eye == OjoEvaluado.derecho ? 'Derecho' : 'Izquierdo'}: ${sesion.evaluations.evaluations.where((e) => e.ojo == eye).length}',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    minHeight: 14,
                    value: sesion.evaluations.evaluations.isEmpty
                        ? 0
                        : sesion.evaluations.evaluations
                                  .where((e) => e.ojo == eye)
                                  .length /
                              sesion.evaluations.evaluations.length,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
  Widget _dato(String label, int value, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(
          '$value',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}
