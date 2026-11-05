import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/session_controller.dart';
import '../../../../shared/widgets/page_body.dart';

class PatientDetailScreen extends StatelessWidget {
  final String patientId;
  final SessionController session;
  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.session,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session.patients,
    builder: (context, _) {
      final p = session.patients.byId(patientId);
      if (p == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Paciente')),
          body: const Center(child: Text('El paciente ya no está disponible.')),
        );
      }
      Widget field(String title, String? value) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(
          value == null || value.isEmpty ? 'Sin registrar' : value,
        ),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Datos del paciente')),
        body: PageBody(
          children: [
            const Icon(Icons.person_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              p.nombreCompleto,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            field('DNI', p.dni),
            field(
              'Fecha de nacimiento',
              '${p.fechaNacimiento.day.toString().padLeft(2, '0')}/${p.fechaNacimiento.month.toString().padLeft(2, '0')}/${p.fechaNacimiento.year}',
            ),
            field('Sexo', p.sexo.name == 'femenino' ? 'Femenino' : 'Masculino'),
            field('Teléfono', p.telefono),
            field('Dirección', p.direccion),
            field('Historia clínica', p.historiaClinica),
            if (session.isAdmin)
              field('Profesional responsable', p.ownerName ?? p.ownerId),
            if (session.isAdmin)
              OutlinedButton.icon(
                onPressed: () => AppRoutes.adminReassign(context, p.id),
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('Cambiar responsable'),
              ),
            if (session.canEdit(p)) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => AppRoutes.editPatient(context, p),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar paciente'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => AppRoutes.eye(context, p),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Nueva evaluación'),
              ),
            ],
          ],
        ),
      );
    },
  );
}
