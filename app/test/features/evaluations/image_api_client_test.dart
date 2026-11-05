import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rd_app/core/errors/app_failure.dart';
import 'package:rd_app/features/evaluations/data/repositories/image_api_client.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_image.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_image_metadata.dart';

import '../../support/fixtures.dart';

const id = '30000000-0000-0000-0000-000000000001';
void main() {
  test(
    'Authenticated image API uploads exactly three files to FastAPI',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.host, 'images.example.invalid');
        expect(request.headers['Authorization'], 'Bearer synthetic-user-token');
        expect(
          RegExp('name="files"')
              .allMatches(latin1.decode(request.bodyBytes))
              .length,
          3,
        );
        return http.Response('', 204);
      });
      addTearDown(client.close);
      await ImageApiClient(
        Uri.parse('https://images.example.invalid'),
        () => 'synthetic-user-token',
        transport: client,
      ).upload(id, [for (var n = 1; n <= 3; n++) EvaluationImage(photo(n))]);
    },
  );
  test('Download authorizes with Supabase session but never forwards it to R2', () async {
    final images = [for (var n = 1; n <= 3; n++) photo(n)];
    final metadata = [
      for (var i = 0; i < 3; i++)
        EvaluationImageMetadata(
          position: i + 1,
          sha256: sha256.convert(images[i]).toString(),
          contentType: 'image/png',
          byteSize: images[i].length,
          uploaded: true,
        ),
    ];
    final client = MockClient((request) async {
      if (request.url.host == 'images.example.invalid') {
        expect(request.headers['Authorization'], 'Bearer synthetic-user-token');
        return http.Response(
          jsonEncode({
            'images': [
              for (var i = 0; i < 3; i++)
                {
                  'position': i + 1,
                  'url':
                      'https://account.r2.cloudflarestorage.com/image-$i?signature=test',
                },
            ],
          }),
          200,
        );
      }
      expect(request.headers.containsKey('Authorization'), isFalse);
      final i = int.parse(request.url.path.split('-').last);
      return http.Response.bytes(images[i], 200);
    });
    addTearDown(client.close);
    final result = await ImageApiClient(
      Uri.parse('https://images.example.invalid'),
      () => 'synthetic-user-token',
      transport: client,
    ).download(id, metadata);
    expect(result.length, 3);
    expect(result[0].bytes, images[0]);
  });
  test('Missing session prevents even the first upload request', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('', 204);
    });
    addTearDown(client.close);
    await expectLater(
      ImageApiClient(
        Uri.parse('https://images.example.invalid'),
        () => null,
        transport: client,
      ).upload(id, [EvaluationImage(photo(1))]),
      throwsA(isA<AppFailure>()),
    );
    expect(called, isFalse);
  });
  test('Tampered cloud bytes cannot become an evaluation image', () async {
    final metadata = [
      for (var i = 0; i < 3; i++)
        EvaluationImageMetadata(
          position: i + 1,
          sha256: sha256.convert(photo(i + 1)).toString(),
          contentType: 'image/png',
          byteSize: photo(i + 1).length,
          uploaded: true,
        ),
    ];
    final client = MockClient((request) async {
      if (request.url.host == 'images.example.invalid') {
        return http.Response(
          jsonEncode({
            'images': [
              for (var i = 0; i < 3; i++)
                {
                  'position': i + 1,
                  'url':
                      'https://account.r2.cloudflarestorage.com/image-$i?signature=test',
                },
            ],
          }),
          200,
        );
      }
      return http.Response.bytes(photo(7), 200);
    });
    addTearDown(client.close);
    await expectLater(
      ImageApiClient(
        Uri.parse('https://images.example.invalid'),
        () => 'synthetic',
        transport: client,
      ).download(id, metadata),
      throwsA(isA<AppFailure>()),
    );
  });
}
