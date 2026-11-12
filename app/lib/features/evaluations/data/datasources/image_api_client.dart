import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/evaluation_image.dart';
import '../../domain/entities/evaluation_image_metadata.dart';

/// FastAPI authorizes R2 access. R2 and server credentials never enter this client.
class ImageApiClient {
  final Uri baseUrl;
  final String? Function() accessToken;
  final http.Client? transport;
  ImageApiClient(this.baseUrl, this.accessToken, {this.transport});
  Map<String, String> _headers() {
    final token = accessToken();
    if (token == null || token.isEmpty) {
      throw const AppFailure(
        'Inicia sesión para guardar o consultar las imágenes',
      );
    }
    return {'Authorization': 'Bearer $token'};
  }

  Uri _path(String id) {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) {
      throw const AppFailure('Identificador de evaluación no válido');
    }
    return baseUrl.resolve('/v1/evaluations/$id/images');
  }

  Future<void> upload(String id, List<EvaluationImage> images) async {
    final client = transport ?? http.Client();
    try {
      final request = http.MultipartRequest('PUT', _path(id));
      request.headers.addAll(_headers());
      for (var i = 0; i < images.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            images[i].bytes,
            filename: 'image-${i + 1}.bin',
          ),
        );
      }
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 3));
      await response.stream.drain<void>().timeout(const Duration(seconds: 30));
      if (response.statusCode != 204) _fail(response.statusCode);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'El borrador quedó guardado, pero las fotos no se pudieron subir. Reintenta Guardar',
      );
    } finally {
      if (transport == null) client.close();
    }
  }

  Never _fail(int status) => throw AppFailure(switch (status) {
    401 ||
    403 => 'Tu cuenta no tiene acceso a estas imágenes. Comprueba tu sesión',
    404 => 'La evaluación ya no está disponible',
    409 => 'El borrador cambió. Actualiza el historial antes de reintentar',
    413 => 'Una imagen supera el tamaño permitido por el servidor',
    422 => 'Se requieren tres imágenes válidas JPEG o PNG',
    _ => 'El servicio de imágenes no está disponible. Reintenta más tarde',
  });

  Future<List<EvaluationImage>> download(
    String id,
    List<EvaluationImageMetadata> metadata,
  ) async {
    final client = transport ?? http.Client();
    try {
      final response = await client
          .get(_path(id), headers: _headers())
          .timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) _fail(response.statusCode);
      final rows =
          (jsonDecode(response.body) as Map<String, dynamic>)['images'] as List;
      final expected = metadata.where((m) => m.uploaded).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      rows.sort(
        (a, b) => (a['position'] as num).compareTo(b['position'] as num),
      );
      if (expected.length != 3 || rows.length != 3) {
        throw const AppFailure(
          'Todavía no están confirmadas las tres imágenes',
        );
      }
      final images = <EvaluationImage>[];
      for (var i = 0; i < 3; i++) {
        final row = rows[i] as Map<String, dynamic>;
        final uri = Uri.parse(row['url'] as String);
        if (row['position'] != expected[i].position ||
            uri.scheme != 'https' ||
            !uri.host.endsWith('.r2.cloudflarestorage.com') ||
            uri.userInfo.isNotEmpty ||
            uri.fragment.isNotEmpty) {
          throw const AppFailure('La referencia de imagen no es válida');
        }
        // Never forward the Supabase bearer token to the R2 signed URL.
        final file = await client
            .send(http.Request('GET', uri))
            .timeout(const Duration(seconds: 30));
        if (file.statusCode != 200) {
          await file.stream.drain<void>().timeout(const Duration(seconds: 30));
          throw const AppFailure(
            'El enlace de la imagen venció o la descarga falló. Reintenta',
          );
        }
        final bytes = <int>[];
        await for (final chunk in file.stream.timeout(
          const Duration(seconds: 30),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > expected[i].byteSize) {
            throw const AppFailure(
              'El archivo recibido supera el tamaño registrado',
            );
          }
        }
        if (bytes.length != expected[i].byteSize ||
            sha256.convert(bytes).toString() != expected[i].sha256) {
          throw const AppFailure(
            'La imagen recibida no coincide con el registro',
          );
        }
        images.add(EvaluationImage(Uint8List.fromList(bytes)));
      }
      return images;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'No se pudieron recuperar las imágenes. Revisa tu conexión',
      );
    } finally {
      if (transport == null) client.close();
    }
  }
}
