/// A failure safe to display to the user; adapters translate technical errors.
class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
  @override
  String toString() => message;
}
