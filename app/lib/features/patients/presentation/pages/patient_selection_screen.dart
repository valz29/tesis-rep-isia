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

  void _abrir(Patient p) => AppRoutes.eye(context, p);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.sesion.patients,
    builder: (context, _) {
      final patients = widget.sesion.patients.search(_query);
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
            TextField(
              controller: _search,
              focusNode: _focus,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: AppTheme.campo(
                'Buscar paciente...',
                icono: Icons.search,
              ).copyWith(fillColor: AppTheme.superficie),
            ),
            const SizedBox(height: 20),
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
                      'DNI: ${p.dni}  |  ${p.ageAt(DateTime.now())} años',
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
                          ? 'Todavía no hay pacientes'
                          : 'Sin coincidencias',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Usa el botón + para registrar un paciente.',
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
