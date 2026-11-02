enum OjoEvaluado { derecho, izquierdo }

/// One patient, one eye and one visit. Capture fields remain unspecified until
/// the clinical acquisition protocol is agreed; no retinal coverage is assumed.
class EvaluationDraft {
  final String patientId;
  final OjoEvaluado ojo;
  final String? observaciones;
  const EvaluationDraft({
    required this.patientId,
    required this.ojo,
    this.observaciones,
  });
}
