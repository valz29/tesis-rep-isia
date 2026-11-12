import 'package:flutter/material.dart';
import 'package:rd_app/app/router/app_routes.dart';
import 'package:rd_app/app/session_controller.dart';

import '../../domain/entities/evaluation.dart';
import '../formatters/evaluation_labels.dart';
import '../widgets/evaluation_thumbnail.dart';

class HistoryScreen extends StatelessWidget {
  final SessionController sesion;
  const HistoryScreen({super.key, required this.sesion});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sesion.changes,
    builder: (context, _) {
      final records = sesion.evaluations.evaluations;
      final rowCount = records.isEmpty ? 1 : records.length;
      return Scaffold(
        appBar: AppBar(title: const Text('Historial')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                itemCount: rowCount + (sesion.isAdmin ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == rowCount) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: FilledButton(
                        onPressed: () =>
                            AppRoutes.patients(context, paraEvaluar: true),
                        child: const Text('Nueva evaluación'),
                      ),
                    );
                  }
                  if (records.isEmpty) return const _EmptyHistory();
                  return _record(context, records[index]);
                },
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _record(BuildContext context, Evaluation evaluation) => Padding(
    key: ValueKey(evaluation.id),
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: EvaluationThumbnail(
          key: ValueKey('thumbnail-${evaluation.id}'),
          evaluation: evaluation,
          controller: sesion.evaluations,
        ),
        title: Text(
          sesion.patients.byId(evaluation.patientId)?.nombreCompleto ??
              'Paciente',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${evaluation.fechaLabel}\n${evaluation.ojo.label} · '
          '${evaluation.imageCount} imágenes\n${evaluation.statusLabel}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => AppRoutes.result(context, evaluation),
      ),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        Icon(Icons.history, size: 56),
        SizedBox(height: 16),
        Text('Todavía no hay evaluaciones'),
        SizedBox(height: 8),
        Text(
          'Guarda una evaluación para verla aquí.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
