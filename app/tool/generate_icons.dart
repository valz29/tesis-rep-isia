import 'dart:convert';
import 'dart:io';

/// Regenerates the existing AppIcon resources without changing Xcode settings.
Future<void> main() async {
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  final originalProject = project.existsSync()
      ? project.readAsBytesSync()
      : null;
  try {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'flutter_launcher_icons',
    ], mode: ProcessStartMode.inheritStdio);
    exitCode = await process.exitCode;
    if (exitCode != 0) return;
    final catalog = File(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
    );
    if (catalog.existsSync()) {
      final contents = jsonDecode(catalog.readAsStringSync());
      catalog.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(contents)}\n',
      );
    }
  } finally {
    // Version 0.14.4 also rewrites an unrelated boolean ASSETCATALOG setting.
    // The AppIcon set is already configured; only its resources need updating.
    if (originalProject != null) project.writeAsBytesSync(originalProject);
  }
}
