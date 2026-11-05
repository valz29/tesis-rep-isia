import 'package:flutter/material.dart';

import '../../../../app/session_controller.dart';
import '../../../../shared/widgets/page_body.dart';
import '../../../evaluations/domain/entities/evaluation.dart';
import '../../../evaluations/domain/entities/evaluation_draft.dart';

class AdminEvaluationScreen extends StatefulWidget {
  final Evaluation evaluation;
  final SessionController session;
  const AdminEvaluationScreen({
    super.key,
    required this.evaluation,
    required this.session,
  });
  @override
  State<AdminEvaluationScreen> createState() => _AdminEvaluationScreenState();
}

class _AdminEvaluationScreenState extends State<AdminEvaluationScreen> {
  late OjoEvaluado _eye = widget.evaluation.ojo;
  late final _notes = TextEditingController(
    text: widget.evaluation.observaciones ?? '',
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.session.admin.updateEvaluation(
      widget.evaluation.id,
      _eye,
      _notes.text,
    );
    if (!mounted) return;
    if (ok) {
      try {
        await widget.session.evaluations.load();
      } catch (_) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error =
                'Guardado. Actualiza el historial para cargar los cambios.';
          });
        }
        return;
      }
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = widget.session.admin.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.session.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acceso exclusivo de administración')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Editar evaluación')),
      body: PageBody(
        children: [
          const Text(
            'Corrige los datos de la evaluación. Los resultados del modelo y la autoría se conservan.',
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<OjoEvaluado>(
            initialValue: _eye,
            decoration: const InputDecoration(labelText: 'Ojo evaluado'),
            items: const [
              DropdownMenuItem(
                value: OjoEvaluado.derecho,
                child: Text('Ojo derecho'),
              ),
              DropdownMenuItem(
                value: OjoEvaluado.izquierdo,
                child: Text('Ojo izquierdo'),
              ),
            ],
            onChanged:
                _busy || widget.evaluation.status != EvaluationStatus.draft
                ? null
                : (v) => setState(() => _eye = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Observaciones'),
          ),
          if (_error != null) Text(_error!),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Guardando...' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
