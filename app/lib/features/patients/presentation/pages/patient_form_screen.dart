import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/core/theme/app_theme.dart';
import 'package:rd_app/features/patients/domain/entities/patient.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

import '../../../admin/domain/entities/admin_account.dart';
import '../../../admin/presentation/widgets/professional_picker.dart';

class PatientFormScreen extends StatefulWidget {
  final SessionController sesion;
  final Patient? existing;
  const PatientFormScreen({super.key, required this.sesion, this.existing});
  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _form = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _dni = TextEditingController();
  final _fecha = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _historia = TextEditingController();
  DateTime? _nacimiento;
  Sexo? _sexo;
  AdminAccount? _owner;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p == null) return;
    _nombres.text = p.nombres;
    _apellidos.text = p.apellidos;
    _dni.text = p.dni;
    _nacimiento = p.fechaNacimiento;
    _sexo = p.sexo;
    _fecha.text =
        '${p.fechaNacimiento.day.toString().padLeft(2, '0')}/${p.fechaNacimiento.month.toString().padLeft(2, '0')}/${p.fechaNacimiento.year}';
    _telefono.text = p.telefono ?? '';
    _direccion.text = p.direccion ?? '';
    _historia.text = p.historiaClinica ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _nombres,
      _apellidos,
      _dni,
      _fecha,
      _telefono,
      _direccion,
      _historia,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(hoy.year - 50),
      firstDate: DateTime(1900),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
    );
    if (date == null || !mounted) return;
    setState(() {
      _nacimiento = date;
      _fecha.text =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (widget.existing != null && !widget.sesion.canEdit(widget.existing!)) {
      return;
    }
    String? opcional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final controller = widget.sesion.patients;
    final p = await controller.register(
      existing: widget.existing,
      ownerId:
          _owner?.id ??
          (widget.sesion.isAdmin ? null : widget.sesion.auth.personal?.id),
      dni: _dni.text,
      nombres: _nombres.text.trim(),
      apellidos: _apellidos.text.trim(),
      fechaNacimiento: _nacimiento!,
      sexo: _sexo!,
      telefono: opcional(_telefono),
      direccion: opcional(_direccion),
      historiaClinica: opcional(_historia),
    );
    if (!mounted) return;
    if (p != null) {
      Navigator.pop(context, p);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.error ?? 'No se pudo guardar el paciente'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.sesion.patients,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Nuevo paciente' : 'Editar paciente',
        ),
      ),
      body: PageBody(
        children: [
          Form(
            key: _form,
            child: Column(
              children: [
                if (widget.sesion.isAdmin && widget.existing == null) ...[
                  FormField<AdminAccount>(
                    key: const Key('patient-owner'),
                    validator: (_) => _owner == null
                        ? 'Selecciona un profesional responsable'
                        : null,
                    builder: (state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.assignment_ind_outlined),
                          title: const Text('Profesional responsable'),
                          subtitle: Text(
                            _owner?.name ?? 'Seleccionar profesional',
                          ),
                          trailing: const Icon(Icons.expand_more),
                          onTap: () async {
                            final owner = await chooseProfessional(
                              context,
                              widget.sesion.admin,
                            );
                            if (!mounted || owner == null) return;
                            setState(() => _owner = owner);
                            state.didChange(owner);
                          },
                        ),
                        if (state.hasError)
                          Text(
                            state.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  key: const Key('patient-name'),
                  controller: _nombres,
                  decoration: AppTheme.campo(
                    'Nombres',
                    icono: Icons.person_outline,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Ingresa los nombres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('patient-surname'),
                  controller: _apellidos,
                  decoration: AppTheme.campo(
                    'Apellidos',
                    icono: Icons.person_outline,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Ingresa los apellidos'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fecha,
                  readOnly: true,
                  onTap: _elegirFecha,
                  decoration: AppTheme.campo(
                    'Fecha de nacimiento',
                    icono: Icons.calendar_today_outlined,
                  ),
                  validator: (_) => _nacimiento == null
                      ? 'Selecciona la fecha de nacimiento'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('patient-dni'),
                  controller: _dni,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: AppTheme.campo(
                    'DNI',
                    icono: Icons.badge_outlined,
                  ),
                  validator: (v) =>
                      v?.length != 8 ? 'El DNI debe tener 8 dígitos' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Sexo>(
                  decoration: AppTheme.campo(
                    'Sexo',
                    icono: Icons.person_outline,
                  ),
                  initialValue: _sexo,
                  items: const [
                    DropdownMenuItem(
                      value: Sexo.femenino,
                      child: Text('Femenino'),
                    ),
                    DropdownMenuItem(
                      value: Sexo.masculino,
                      child: Text('Masculino'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _sexo = v),
                  validator: (v) => v == null ? 'Selecciona el sexo' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: AppTheme.campo(
                    'Teléfono (opcional)',
                    icono: Icons.phone_outlined,
                  ),
                  validator: (v) => v != null && v.isNotEmpty && v.length != 9
                      ? 'El teléfono debe tener 9 dígitos'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _direccion,
                  decoration: AppTheme.campo(
                    'Dirección (opcional)',
                    icono: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _historia,
                  maxLines: 3,
                  minLines: 1,
                  decoration: AppTheme.campo(
                    'Historia clínica (opcional)',
                    icono: Icons.description_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.sesion.patients.busy ? null : _guardar,
            child: const Text('Guardar'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
