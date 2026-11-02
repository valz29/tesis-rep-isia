import 'package:flutter/material.dart';
import 'package:rd_app/app/router/app_routes.dart';
import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

import '../../domain/entities/evaluation_draft.dart';
import '../../domain/entities/evaluation_image.dart';

class PreparationScreen extends StatefulWidget {
  final EvaluationDraft draft;
  final List<EvaluationImage> imagenes;
  final SessionController sesion;
  const PreparationScreen({
    super.key,
    required this.draft,
    required this.imagenes,
    required this.sesion,
  });
  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final controller = widget.sesion.evaluations;
    final result = await controller.prepare(
      widget.draft,
      widget.imagenes,
      widget.sesion.auth.personal?.id ?? '',
    );
    if (!mounted) return;
    if (result != null) {
      AppRoutes.prepared(context, result);
    } else {
      setState(() {
        _loading = false;
        _error = controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preparar evaluación')),
    body: PageBody(
      children: [
        const SizedBox(height: 32),
        const Text(
          'Preparando evaluación',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 36),
        if (_loading) const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 28),
        const Text(
          'Tres imágenes · Una evaluación del ojo',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        for (final label in [
          'Tres imágenes seleccionadas',
          'Ojo confirmado',
          'Evaluación preparada',
        ])
          ListTile(
            leading: const Icon(Icons.radio_button_unchecked),
            title: Text(label),
          ),
        if (_error != null) ...[
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _prepare, child: const Text('Reintentar')),
        ],
      ],
    ),
  );
}
