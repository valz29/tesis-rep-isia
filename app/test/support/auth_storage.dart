import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryAuthStorage extends GotrueAsyncStorage {
  final Map<String, String> _values = {};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
