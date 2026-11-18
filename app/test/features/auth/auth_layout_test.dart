import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_app/app/app_scope.dart';
import 'package:rd_app/app/dependencies.dart';
import 'package:rd_app/core/app_theme.dart';
import 'package:rd_app/features/auth/presentation/auth_visuals.dart';
import 'package:rd_app/features/auth/presentation/login_screen.dart';
import 'package:rd_app/features/auth/presentation/welcome_screen.dart';

import '../../support/fixtures.dart';

const _previewKey = Key('auth-preview');

Widget _app(
  AppDependencies dependencies, {
  double textScale = 1,
  bool reducedMotion = false,
}) => AppScope(
  session: dependencies.session,
  child: MaterialApp(
    theme: AppTheme.light(),
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reducedMotion,
      ),
      child: RepaintBoundary(key: _previewKey, child: child!),
    ),
    home: const WelcomeScreen(),
  ),
);

// Optional rendered previews use the real widgets, not a separate mockup.
Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('AUTH_PREVIEW_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _advanceEntrance(
  WidgetTester tester,
  Duration duration,
  String name, {
  int firstFrame = 0,
}) async {
  const record = bool.fromEnvironment('AUTH_RECORD_ANIMATION');
  if (!record) {
    await tester.pump(duration);
    return;
  }
  const step = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
    final frame = firstFrame + elapsed.inMilliseconds ~/ step.inMilliseconds;
    await _capture(tester, '$name-${frame.toString().padLeft(3, '0')}');
  }
}

void main() {
  setUpAll(() async {
    const fonts = String.fromEnvironment('AUTH_FONT_DIR');
    if (fonts.isEmpty) return;
    for (final family in ['Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      final files = family == 'Roboto'
          ? ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']
          : ['MaterialIcons-Regular.otf'];
      for (final file in files) {
        loader.addFont(
          File('$fonts/$file').readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });
  testWidgets(
    'Entrance is staggered, finishes and preserves login navigation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final dependencies = memoryDependencies();
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(_app(dependencies));
      await _advanceEntrance(
        tester,
        const Duration(milliseconds: 300),
        'bienvenida',
      );
      final reveal = tester.widget<AuthReveal>(find.byType(AuthReveal).first);
      expect(reveal.animation.value, inExclusiveRange(0, 1));
      await _capture(tester, 'bienvenida-entrada');
      await _advanceEntrance(
        tester,
        const Duration(milliseconds: 1700),
        'bienvenida',
        firstFrame: 6,
      );
      await tester.pumpAndSettle();
      expect(reveal.animation.value, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await _capture(tester, 'bienvenida');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      await _advanceEntrance(
        tester,
        const Duration(milliseconds: 2000),
        'acceso',
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await _capture(tester, 'iniciar-sesion');
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets('Large text and keyboard remain usable at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final dependencies = memoryDependencies();
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(_app(dependencies, textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Reduced motion shows both screens without entrance animation', (
    tester,
  ) async {
    final dependencies = memoryDependencies();
    addTearDown(dependencies.dispose);
    await tester.pumpWidget(_app(dependencies, reducedMotion: true));
    expect(
      tester.widget<AuthReveal>(find.byType(AuthReveal).first).animation.value,
      1,
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    for (final reveal in tester.widgetList<AuthReveal>(
      find.byType(AuthReveal),
    )) {
      expect(reveal.animation.value, 1);
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
