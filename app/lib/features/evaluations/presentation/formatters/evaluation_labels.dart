import '../../domain/entities/evaluation.dart';
import '../../domain/entities/evaluation_draft.dart';

extension EyeLabel on OjoEvaluado {
  String get label =>
      this == OjoEvaluado.derecho ? 'Ojo derecho' : 'Ojo izquierdo';
}

extension EvaluationLabels on Evaluation {
  String get statusLabel => switch (status) {
    EvaluationStatus.draft => 'Imágenes pendientes de almacenamiento',
    EvaluationStatus.pendingAnalysis => 'Pendiente de análisis',
    EvaluationStatus.notGradable => 'No graduable',
    EvaluationStatus.completed => 'Evaluación completada',
  };
  String get fechaLabel =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
}
