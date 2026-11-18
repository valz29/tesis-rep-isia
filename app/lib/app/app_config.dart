import 'dart:convert';

class AppConfig {
  final String url;
  final String publishableKey;
  final bool googleEnabled;
  final String imageApiUrl;
  const AppConfig({
    required this.url,
    required this.publishableKey,
    this.googleEnabled = false,
    this.imageApiUrl = '',
  });
  static const redirectUrl = 'com.devloop.retinazo://auth-callback/';
  factory AppConfig.fromEnvironment() => const AppConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    googleEnabled: bool.fromEnvironment('GOOGLE_AUTH_ENABLED'),
    imageApiUrl: String.fromEnvironment('IMAGE_API_URL'),
  );
  bool get isValid {
    if (imageApiUrl.isNotEmpty) {
      final api = Uri.tryParse(imageApiUrl);
      if (api == null ||
          api.scheme != 'https' ||
          api.host.isEmpty ||
          api.userInfo.isNotEmpty ||
          api.hasQuery ||
          api.hasFragment ||
          (api.path.isNotEmpty && api.path != '/')) {
        return false;
      }
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    if (publishableKey.startsWith('sb_publishable_')) return true;
    // Only public/anon keys belong in mobile apps. Reject secret/service credentials.
    try {
      final parts = publishableKey.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      return claims['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}
