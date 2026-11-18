import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Domain stays independent and presentation does not access infrastructure',
    () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final imports = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
      final violations = <String>[];
      for (final file in files) {
        for (final match in imports.allMatches(file.readAsStringSync())) {
          final target = match.group(1)!;
          final resolved = target.startsWith('package:rd_app/')
              ? File('lib/${target.substring('package:rd_app/'.length)}')
                    .absolute
                    .uri
                    .normalizePath()
              : file.absolute.uri.resolve(target).normalizePath();
          if (resolved.path.contains('/test/')) {
            violations.add('${file.path} imports test support -> $target');
          }
          if (file.path.contains('/domain/')) {
            final forbidden =
                target.startsWith('package:flutter') ||
                (target.startsWith('dart:') &&
                    ![
                      'dart:typed_data',
                      'dart:collection',
                      'dart:math',
                    ].contains(target)) ||
                (target.startsWith('package:') &&
                    !target.startsWith('package:rd_app/')) ||
                RegExp(r'(^|/)(data|presentation|app)(/|\.)').hasMatch(target);
            if (forbidden) violations.add('${file.path} -> $target');
          }
          if (file.path.contains('/presentation/')) {
            if (target.contains('/data/') ||
                target.startsWith('package:image_picker/') ||
                target.startsWith('package:http/') ||
                target.startsWith('package:supabase_flutter/') ||
                target.startsWith('package:app_links/') ||
                target == 'dart:io') {
              violations.add('${file.path} -> $target');
            }
          }
          if (file.path.contains('/data/') &&
              target.contains('/presentation/')) {
            violations.add('${file.path} -> $target');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
