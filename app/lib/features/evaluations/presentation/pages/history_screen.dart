import '../formatters/evaluation_labels.dart';

import 'package:rd_app/app/router/app_routes.dart';
import 'package:flutter/material.dart';

import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

class HistoryScreen extends StatelessWidget {
  final SessionController sesion;
  const HistoryScreen({super.key, required this.sesion});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sesion.changes,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: PageBody(
        children: [
          const SizedBox(height: 20),
          if (sesion.evaluations.evaluations.isEmpty)
            const Padding(
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
            ),
          for (final e in sesion.evaluations.evaluations)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: e.imagenes.isEmpty
                      ? const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.image_not_supported_outlined),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.memory(
                            e.imagenes.first.bytes,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            cacheWidth: 128,
                          ),
                        ),
                  title: Text(
                    sesion.patients.byId(e.patientId)?.nombreCompleto ??
                        'Paciente',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${e.fechaLabel}\n${e.ojo.label} · ${e.imageCount} imágenes\n${e.statusLabel}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => AppRoutes.result(context, e),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => AppRoutes.patients(context, paraEvaluar: true),
            child: const Text('Nueva evaluación'),
          ),
        ],
      ),
    ),
  );
}
