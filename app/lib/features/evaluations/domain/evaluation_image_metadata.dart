/// Persistent metadata; storage is confirmed only by the trusted image service.
class EvaluationImageMetadata {
  final int position;
  final String sha256;
  final String contentType;
  final int byteSize;
  final bool uploaded;
  const EvaluationImageMetadata({
    required this.position,
    required this.sha256,
    required this.contentType,
    required this.byteSize,
    this.uploaded = false,
  });
}
