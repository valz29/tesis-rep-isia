import 'package:flutter/material.dart';
import 'package:rd_app/core/theme/app_theme.dart';
import 'package:rd_app/features/patients/domain/entities/patient.dart';

import '../../domain/entities/evaluation_draft.dart';
import '../formatters/evaluation_labels.dart';

class PatientSummary extends StatelessWidget {
  final Patient paciente;
  final OjoEvaluado? ojo;

  const PatientSummary({super.key, required this.paciente, this.ojo});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borde),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.primaryContainer,
            child: Icon(Icons.person, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paciente.nombreCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.tinta,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'DNI ${paciente.dni}  •  ${paciente.ageAt(DateTime.now())} años${ojo == null ? '' : '  •  ${ojo!.label}'}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
