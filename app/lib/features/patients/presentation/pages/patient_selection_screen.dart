import 'package:rd_app/app/router/app_routes.dart';
import 'package:flutter/material.dart';

import 'package:rd_app/features/patients/domain/entities/patient.dart';
import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/core/theme/app_theme.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

class PatientSelectionScreen extends StatefulWidget {
  final SessionController sesion;
  final bool paraEvaluar;
  const PatientSelectionScreen({
    super.key,
    required this.sesion,
    this.paraEvaluar = false,
  });
  @override
  State<PatientSelectionScreen> createState() => _PatientSelectionScreenState();
}

class _PatientSelectionScreenState extends State<PatientSelectionScreen> {
  String _query = '';
  bool _inactive = false;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _nuevo() async {
    final patient = await AppRoutes.newPatient(context);
    if (!mounted || patient == null) return;
    if (widget.paraEvaluar) {
      _abrir(patient);
    }
  }

  void _abrir(Patient p) {
    if (widget.paraEvaluar) {
      AppRoutes.eye(context, p);
    } else {
      AppRoutes.patientDetails(context, p);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.sesion.patients,
    builder: (context, _) {
      final patients = widget.sesion.patients.search(
        _query,
        inactive: _inactive,
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.paraEvaluar ? 'Seleccionar paciente' : 'Pacientes',
          ),
          actions: [
            IconButton(
              tooltip: 'Buscar paciente',
              onPressed: () => FocusScope.of(context).requestFocus(_focus),
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Registrar paciente',
          onPressed: _nuevo,
          child: const Icon(Icons.add),
        ),
        body: PageBody(
          children: [
            if (widget.sesion.isAdmin && !widget.paraEvaluar) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Activos')),
                  ButtonSegment(value: true, label: Text('Desactivados')),
                ],
                selected: {_inactive},
                onSelectionChanged: (value) =>
                    setState(() => _inactive = value.single),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _search,
              focusNode: _focus,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: AppTheme.campo(
                'Buscar paciente...',
                icono: Icons.search,
              ).copyWith(fillColor: AppTheme.superficie),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                try {
                  await widget.sesion.patients.load();
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.sesion.patients.error ??
                            'No se pudieron actualizar los pacientes',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar pacientes'),
            ),
            const SizedBox(height: 12),
            if (widget.paraEvaluar) ...[
              const Text('Elige un paciente para evaluar uno de sus ojos.'),
              const SizedBox(height: 16),
            ],
            for (final p in patients)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const Icon(Icons.person_outline, size: 32),
                    title: Text(
                      p.nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'DNI: ${p.dni}  |  ${p.ageAt(DateTime.now())} años${widget.sesion.isAdmin ? '\nProfesional: ${p.ownerName ?? p.ownerId ?? 'Sin nombre'}' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _abrir(p),
                  ),
                ),
              ),
            if (patients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.people_outline, size: 52),
                    const SizedBox(height: 16),
                    Text(
                      _query.isEmpty
                          ? (_inactive
                                ? 'No hay pacientes desactivados'
                                : 'Todavía no hay pacientes')
                          : 'Sin coincidencias',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.sesion.isAdmin
                          ? 'Los pacientes registrados por los profesionales aparecerán aquí.'
                          : 'Usa el botón + para registrar un paciente.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            const SizedBox(height: 72),
          ],
        ),
      );
    },
  );
  final _focus = FocusNode();
}
