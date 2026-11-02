import '../../domain/entities/evaluation_draft.dart';

import 'package:rd_app/app/router/app_routes.dart';
import 'package:flutter/material.dart';

import 'package:rd_app/features/patients/domain/entities/patient.dart';
import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/shared/widgets/page_body.dart';
import 'package:rd_app/core/theme/app_theme.dart';

class EyeSelectionScreen extends StatefulWidget {
  final Patient paciente;
  final SessionController sesion;
  const EyeSelectionScreen({
    super.key,
    required this.paciente,
    required this.sesion,
  });
  @override
  State<EyeSelectionScreen> createState() => _EyeSelectionScreenState();
}

class _EyeSelectionScreenState extends State<EyeSelectionScreen> {
  OjoEvaluado? _ojo;
  final _notas = TextEditingController();
  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nueva evaluación')),
    body: PageBody(
      children: [
        const Icon(Icons.person_outline, size: 48),
        const SizedBox(height: 12),
        Text(
          widget.paciente.nombreCompleto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text('DNI ${widget.paciente.dni}', textAlign: TextAlign.center),
        const SizedBox(height: 32),
        const Text(
          'Selecciona el ojo a evaluar',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        for (final eye in OjoEvaluado.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _ojo = eye),
              style: OutlinedButton.styleFrom(
                backgroundColor: _ojo == eye ? AppTheme.superficie : null,
              ),
              icon: Icon(
                _ojo == eye
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              label: Text(
                eye == OjoEvaluado.derecho ? 'Ojo derecho' : 'Ojo izquierdo',
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _notas,
          maxLines: 3,
          decoration: AppTheme.campo('Observaciones (opcional)'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Se requieren tres imágenes diferentes del mismo ojo para esta evaluación.',
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _ojo == null
              ? null
              : () => AppRoutes.capture(
                  context,
                  widget.paciente,
                  EvaluationDraft(
                    patientId: widget.paciente.id,
                    ojo: _ojo!,
                    observaciones: _notas.text.trim().isEmpty
                        ? null
                        : _notas.text.trim(),
                  ),
                ),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
}
