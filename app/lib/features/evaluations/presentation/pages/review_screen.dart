import 'package:flutter/material.dart';
import 'package:rd_app/app/router/app_routes.dart';
import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/features/evaluations/presentation/widgets/patient_summary.dart';
import 'package:rd_app/features/patients/domain/entities/patient.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

import '../../domain/entities/evaluation_draft.dart';
import '../../domain/entities/evaluation_image.dart';
import '../formatters/evaluation_labels.dart';

class ReviewScreen extends StatefulWidget {
  final Patient paciente;
  final SessionController sesion;
  final List<EvaluationImage> imagenes;
  final EvaluationDraft draft;
  const ReviewScreen({
    super.key,
    required this.paciente,
    required this.sesion,
    required this.imagenes,
    required this.draft,
  });
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _confirmado = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vista previa y confirmación')),
    body: PageBody(
      children: [
        PatientSummary(paciente: widget.paciente, ojo: widget.draft.ojo),
        const SizedBox(height: 24),
        const Text(
          'Revisa las tres imágenes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < widget.imagenes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      'Imagen ${i + 1} de 3',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => AppRoutes.image(
                        context,
                        widget.imagenes[i].bytes,
                        'Imagen ${i + 1}',
                      ),
                      child: Image.memory(
                        widget.imagenes[i].bytes,
                        height: 150,
                        fit: BoxFit.contain,
                        cacheWidth: 640,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            'Confirmo que las tres imágenes son del ${widget.draft.ojo.label.toLowerCase()} del mismo paciente.',
          ),
          value: _confirmado,
          onChanged: (v) => setState(() => _confirmado = v ?? false),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cambiar imágenes'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('show-evaluation'),
          onPressed: !_confirmado
              ? null
              : () => AppRoutes.prepare(context, widget.draft, widget.imagenes),
          child: const Text('Continuar'),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
