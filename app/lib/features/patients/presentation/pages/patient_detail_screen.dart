import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/session_controller.dart';
import '../../../../shared/widgets/page_body.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  final SessionController session;
  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.session,
  });
  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  SessionController get session => widget.session;
  String get patientId => widget.patientId;
  bool _busy = false;

  Future<void> _setActive(bool active) async {
    final form = GlobalKey<FormState>();
    String reason = '';
    final answer = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Reactivar paciente' : 'Desactivar paciente'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                active
                    ? 'El paciente volverá a estar disponible para su profesional responsable.'
                    : 'Se conservarán sus evaluaciones e imágenes. El paciente aparecerá en Desactivados y no admitirá nuevas evaluaciones.',
              ),
              if (!active) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('patient-deactivation-reason'),
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de desactivación',
                  ),
                  onChanged: (value) => reason = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Indica el motivo'
                      : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, reason.trim());
              }
            },
            child: Text(active ? 'Reactivar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (answer == null || !mounted) return;
    setState(() => _busy = true);
    final saved = await session.admin.setPatientActive(
      patientId,
      active,
      answer,
    );
    if (!mounted) return;
    String? message;
    if (saved) {
      try {
        await session.patients.load();
        await session.admin.load();
      } catch (_) {
        message =
            'Cambio guardado. Actualiza la lista para consultar el estado.';
      }
    } else {
      message =
          session.admin.error ?? 'No se pudo cambiar el estado del paciente';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

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
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: Text(p.isActive ? 'Activo' : 'Desactivado')),
            ),
            if (!p.isActive)
              field('Motivo de desactivación', p.deactivationReason),
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
              field(
                'Profesional responsable',
                p.ownerName ?? p.ownerId ?? 'Sin profesional asignado',
              ),
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
              if (session.canEvaluate(p))
                OutlinedButton.icon(
                  onPressed: () => AppRoutes.eye(context, p),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Nueva evaluación'),
                ),
            ],
            if (session.isAdmin) ...[
              const SizedBox(height: 20),
              if (!p.isActive && p.ownerId == null)
                const Text(
                  'Asigna un profesional antes de reactivar este paciente.',
                ),
              OutlinedButton.icon(
                key: const Key('patient-activity'),
                onPressed: _busy || (!p.isActive && p.ownerId == null)
                    ? null
                    : () => _setActive(!p.isActive),
                icon: Icon(
                  p.isActive
                      ? Icons.person_off_outlined
                      : Icons.person_add_alt_1_outlined,
                ),
                label: Text(
                  _busy
                      ? 'Guardando...'
                      : p.isActive
                      ? 'Desactivar paciente'
                      : 'Reactivar paciente',
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
