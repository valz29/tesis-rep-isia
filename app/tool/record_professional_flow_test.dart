// Video authoring harness. It renders production widgets with local fixtures;
// it never connects to Supabase, Render, R2, a camera or an email account.
// Run explicitly with: flutter test tool/record_professional_flow_test.dart
//   --dart-define=FLOW_FONT_DIR=<Flutter>/bin/cache/artifacts/material_fonts
//   --dart-define=FLOW_OUTPUT_DIR=/tmp/retinazo-professional-flow
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:rd_app/app/app.dart';
import 'package:rd_app/app/dependencies.dart';
import 'package:rd_app/core/app_failure.dart';
import 'package:rd_app/features/auth/domain/staff_member.dart';
import 'package:rd_app/features/evaluations/domain/evaluation.dart';
import 'package:rd_app/features/evaluations/domain/evaluation_image.dart';
import 'package:rd_app/features/evaluations/presentation/capture_screen.dart';
import 'package:rd_app/features/evaluations/presentation/history_screen.dart';
import 'package:rd_app/features/evaluations/presentation/image_viewer_screen.dart';
import 'package:rd_app/features/evaluations/presentation/result_screen.dart';
import 'package:rd_app/features/evaluations/presentation/review_screen.dart';
import 'package:rd_app/features/evaluations/presentation/single_image_preview_screen.dart';
import 'package:rd_app/features/home/presentation/home_screen.dart';
import 'package:rd_app/features/patients/domain/patient.dart';
import 'package:rd_app/shared/retinazo_logo.dart';

import '../test/support/fakes/in_memory_admin_repository.dart';
import '../test/support/fakes/in_memory_evaluation_repository.dart';
import '../test/support/fakes/in_memory_patient_repository.dart';
import '../test/support/fakes/preview_auth_repository.dart';
import '../test/support/fixtures.dart';

const _output = String.fromEnvironment(
  'FLOW_OUTPUT_DIR',
  defaultValue: '/tmp/retinazo-professional-flow',
);
const _record = bool.fromEnvironment('FLOW_RECORD', defaultValue: true);
const _stageKey = Key('professional-video-stage');
const _email = 'elena.torres@example.com';
const _password = 'Retina2026!';

class _VideoAuth extends PreviewAuthRepository {
  bool confirmed = false;
  @override
  Future<StaffMember> signIn(String email, String password) async {
    if (!confirmed) throw const AppFailure('Confirma primero tu correo');
    return StaffMember(id: email, usuario: email, nombre: 'Dra. Elena Torres');
  }
}

class _VideoEvaluations extends InMemoryEvaluationRepository {
  @override
  Future<Evaluation> save(Evaluation e) async {
    // A readable local stand-in for the remote save, disclosed in the captions.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    return super.save(
      Evaluation(
        id: e.id,
        patientId: e.patientId,
        ojo: e.ojo,
        imagenes: e.imagenes,
        fecha: e.fecha,
        professionalId: e.professionalId,
        observaciones: e.observaciones,
        status: EvaluationStatus.pendingAnalysis,
      ),
    );
  }
}

class _Scene {
  const _Scene(this.title, this.detail, {this.card, this.started = true});
  final String title;
  final String detail;
  final String? card;
  final bool started;
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.dependencies,
    required this.scene,
    required this.touch,
  });
  final AppDependencies dependencies;
  final ValueNotifier<_Scene> scene;
  final ValueNotifier<Offset?> touch;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: _stageKey,
      child: ValueListenableBuilder<_Scene>(
        valueListenable: scene,
        builder: (context, scene, _) => ColoredBox(
          color: const Color(0xFF092F35),
          child: Column(
            children: [
              SizedBox(
                height: 844,
                child: Stack(
                  children: [
                    if (scene.started) RetinazoApp(dependencies: dependencies),
                    if (scene.card != null)
                      Positioned.fill(
                        child: ColoredBox(
                          color: const Color(0xFF0F6B6B),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const RetinazoLogo(size: 180),
                                const SizedBox(height: 28),
                                const Text(
                                  'Retinazo',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  scene.card!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 20,
                                    height: 1.55,
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<Offset?>(
                          valueListenable: touch,
                          builder: (_, position, _) =>
                              CustomPaint(painter: _TouchPainter(position)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scene.title,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Expanded(
                          child: Text(
                            scene.detail,
                            maxLines: 3,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Color(0xFFD6ECE7),
                            ),
                          ),
                        ),
                        const Text(
                          'DATOS FICTICIOS  ·  RECORRIDO LOCAL',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: .8,
                            color: Color(0xFF99C9BE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TouchPainter extends CustomPainter {
  const _TouchPainter(this.position);
  final Offset? position;
  @override
  void paint(Canvas canvas, Size size) {
    if (position == null) return;
    canvas.drawCircle(position!, 18, Paint()..color = const Color(0x55F3B948));
    canvas.drawCircle(
      position!,
      18,
      Paint()
        ..color = const Color(0xFFF3B948)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(position!, 3, Paint()..color = const Color(0xFF805800));
  }

  @override
  bool shouldRepaint(_TouchPainter oldDelegate) =>
      position != oldDelegate.position;
}

class _Recorder {
  _Recorder(this.tester, this.scene, this.touch);
  final WidgetTester tester;
  final ValueNotifier<_Scene> scene;
  final ValueNotifier<Offset?> touch;
  final entries = <String>[];
  final chapters = <String>[];
  var frame = 0;
  double seconds = 0;

  Future<void> capture(double duration) async {
    if (!_record) {
      seconds += duration;
      return;
    }
    final index = frame++;
    final name = 'frame-${index.toString().padLeft(5, '0')}.png';
    const resume = int.fromEnvironment('FLOW_RESUME_FRAME');
    if (index == 0 || index >= resume) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_stageKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File('$_output/$name').writeAsBytes(bytes!.buffer.asUint8List());
      });
    } else if (!File('$_output/$name').existsSync()) {
      throw StateError('Cannot resume: missing frame $name');
    }
    entries.add("file '$name'\nduration ${duration.toStringAsFixed(4)}\n");
    seconds += duration;
    if (frame % 50 == 0) {
      await tester.runAsync(
        () =>
            File('$_output/capture.journal.ffconcat')
                .writeAsString('ffconcat version 1.0\n${entries.join()}'),
      );
    }
  }

  void chapter(
    String title,
    String detail, {
    String? card,
    bool started = true,
  }) {
    final time = Duration(milliseconds: (seconds * 1000).round());
    chapters.add(
      '${time.inMinutes.toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}  $title\n$detail',
    );
    scene.value = _Scene(title, detail, card: card, started: started);
    // Progress is printed per scene, never once per rendered frame.
    debugPrint('VIDEO ${chapters.last}');
  }

  Future<void> animate(int milliseconds) async {
    if (!_record) {
      await tester.pump();
      await tester.pump(Duration(milliseconds: milliseconds));
      seconds += milliseconds / 1000;
      return;
    }
    for (var t = 0; t < milliseconds; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      await capture(.05);
    }
  }

  Future<void> hold(double duration) async {
    await tester.pump();
    await capture(duration);
    await tester.pump(Duration(milliseconds: (duration * 1000).round()));
  }

  Future<void> reveal(Finder finder) async {
    expect(finder, findsWidgets);
    final bounds = tester.getRect(finder.first);
    if (bounds.top >= 0 && bounds.bottom <= 844) {
      await tester.pump();
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        tester.element(finder.first),
        duration: const Duration(milliseconds: 400),
        alignment: .48,
      ),
    );
    await animate(450);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tap(Finder finder, {double after = .5}) async {
    await reveal(finder);
    touch.value = tester.getCenter(finder.first);
    await hold(.18);
    await tester.tap(finder.first);
    await animate(250);
    touch.value = null;
    await animate(250);
    await hold(after);
  }

  Future<void> type(Finder finder, String text) async {
    await reveal(finder);
    await tester.showKeyboard(finder.first);
    for (var part = 1; part <= 3; part++) {
      await tester.enterText(
        finder.first,
        text.substring(0, (text.length * part / 3).ceil()),
      );
      await hold(.18);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await hold(.3);
  }

  Future<void> back() async {
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).last);
    if (scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else {
      await tester.pageBack();
    }
    await animate(450);
    await hold(.5);
  }

  Future<void> finish() async {
    if (!_record) return;
    final last = 'frame-${(frame - 1).toString().padLeft(5, '0')}.png';
    await tester.runAsync(() async {
      await File('$_output/frames.ffconcat').writeAsString(
        'ffconcat version 1.0\n${entries.join()}file \'$last\'\n',
      );
      await File('$_output/guion.txt').writeAsString(
        'RETINAZO · FLUJO DEL PROFESIONAL\n\n'
        'Pantallas reales de Flutter 1.3.5. Datos ficticios e imágenes ilustrativas.\n'
        'Correo, selección del dispositivo y guardado remoto representados con repositorios locales.\n'
        'No se contacta a Supabase, Render ni R2. No hay inferencia de IA.\n\n'
        '${chapters.join('\n\n')}\n\nDuración: ${seconds.toStringAsFixed(1)} s\n',
      );
    });
  }
}

Future<EvaluationImage> _sample(int index) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFF10191A), BlendMode.src);
  const center = Offset(400, 390);
  canvas.drawCircle(
    center,
    344,
    Paint()
      ..shader = ui.Gradient.radial(
        center,
        344,
        const [Color(0xFFD58547), Color(0xFFAC542D), Color(0xFF5C281D)],
        const [0, .7, 1],
      ),
  );
  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: center, radius: 342)),
  );
  canvas.translate((index - 2) * 16, (index - 2) * 10);
  const disc = Offset(570, 390);
  canvas.drawCircle(
    disc,
    47,
    Paint()
      ..shader = ui.Gradient.radial(disc, 47, const [
        Color(0xFFF9CE85),
        Color(0xFFDA9F60),
      ]),
  );
  for (var branch = 0; branch < 8; branch++) {
    final angle = -math.pi + branch * math.pi / 4;
    final end = Offset(
      400 + math.cos(angle) * 300,
      390 + math.sin(angle) * 300,
    );
    final path = Path()
      ..moveTo(disc.dx, disc.dy)
      ..cubicTo(
        470,
        390 + math.sin(angle) * 110,
        end.dx + 50,
        end.dy - 30,
        end.dx,
        end.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF823B2C)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5,
    );
    final fine = Path()
      ..moveTo(460, 390 + math.sin(angle) * 100)
      ..quadraticBezierTo(end.dx, end.dy - 70, end.dx - 60, end.dy - 100);
    canvas.drawPath(
      fine,
      Paint()
        ..color = const Color(0xFF994835)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
  canvas.restore();
  final label = TextPainter(
    text: TextSpan(
      text: 'MUESTRA VISUAL $index · NO CLÍNICA',
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 22,
        color: Color(0xFFD7E8E2),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 760);
  label.paint(canvas, Offset((800 - label.width) / 2, 758));
  final picture = recorder.endRecording();
  final image = await picture.toImage(800, 800);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return EvaluationImage(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    const fonts = String.fromEnvironment('FLOW_FONT_DIR');
    if (fonts.isEmpty) {
      throw StateError('Provide FLOW_FONT_DIR for real font rendering.');
    }
    for (final family in ['Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final file
          in family == 'Roboto'
              ? ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']
              : ['MaterialIcons-Regular.otf']) {
        loader.addFont(
          File('$fonts/$file').readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });

  testWidgets('Record the complete professional walkthrough', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 980);
    addTearDown(tester.view.reset);
    final auth = _VideoAuth();
    final images = TestImageRepository();
    final dependencies = AppDependencies(
      authRepository: auth,
      patientRepository: InMemoryPatientRepository(),
      evaluationRepository: _VideoEvaluations(),
      imageRepository: images,
      adminRepository: InMemoryAdminRepository(),
      now: () => DateTime(2026, 11, 18, 10, 30),
      initialStatus: EvaluationStatus.draft,
    );
    addTearDown(dependencies.dispose);
    final scene = ValueNotifier(
      const _Scene(
        'Recorrido del profesional',
        'Pantallas actuales · Sin acciones administrativas.',
        started: false,
        card: 'Flujo completo del profesional\n\nCuenta · Pacientes · Tres imágenes\nHistorial · Estadísticas\n\nDatos ficticios y muestras ilustrativas.\nCorreo y guardado en nube representados.',
      ),
    );
    final touch = ValueNotifier<Offset?>(null);
    addTearDown(scene.dispose);
    addTearDown(touch.dispose);
    await tester.runAsync(() => Directory(_output).create(recursive: true));
    final samples = <EvaluationImage>[];
    for (var n = 1; n <= 3; n++) {
      samples.add((await tester.runAsync(() => _sample(n)))!);
    }
    final r = _Recorder(tester, scene, touch);
    await tester.pumpWidget(
      _Stage(dependencies: dependencies, scene: scene, touch: touch),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/retinazo-eye.png'),
        tester.element(find.byType(_Stage)),
      ),
    );
    await tester.pump();
    await r.hold(8);
    if (const bool.fromEnvironment('FLOW_INTRO_ONLY')) {
      await r.finish();
      return;
    }
    r.chapter(
      '01 · Cuenta y acceso',
      'La bienvenida ofrece iniciar sesión o crear una cuenta de profesional.',
    );
    await r.animate(2200);
    await r.hold(3);
    await r.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
    await r.type(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Dra. Elena Torres',
    );
    await r.type(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      _email,
    );
    await r.type(find.byType(TextFormField).at(2), _password);
    await r.type(find.byType(TextFormField).at(3), _password);
    await r.hold(2);
    await r.tap(find.widgetWithText(FilledButton, 'Registrarse'), after: 4);
    expect(
      find.text('Confirma tu correo para activar tu cuenta.'),
      findsOneWidget,
    );
    r.chapter(
      '01 · Confirmación de correo',
      'La cuenta debe verificar su correo antes de entrar. El envío y el enlace se representan en este video.',
      card: 'Confirmación de correo\n\nEn el uso real, se abre el enlace de Supabase desde el mismo teléfono.\n\nEste recorrido continúa con una cuenta ficticia confirmada.',
    );
    await r.hold(7);
    auth.confirmed = true;
    r.chapter(
      '01 · Inicio de sesión',
      'Con el correo confirmado se accede al espacio del profesional.',
    );
    await r.tap(find.text('Ya confirmé mi correo · Iniciar sesión'));
    await r.animate(1600);
    r.chapter(
      '02 · Recuperar acceso',
      'Si olvidó la contraseña, puede solicitar un enlace de recuperación.',
    );
    await r.tap(find.text('¿Olvidaste tu contraseña?'));
    await r.type(find.byType(TextFormField), _email);
    await r.tap(find.widgetWithText(FilledButton, 'Continuar'), after: 3);
    await r.tap(find.text('Volver al ingreso'));
    await r.type(find.byType(TextFormField).last, _password);
    await r.tap(find.widgetWithText(FilledButton, 'Ingresar'), after: 3);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(dependencies.session.isAdmin, isFalse);
    r.chapter(
      '03 · Inicio y menú',
      'El profesional dispone de pacientes, captura de imágenes, historial y estadísticas.',
    );
    await r.hold(3);
    await r.tap(find.byTooltip('Open navigation menu'), after: 3);
    await r.back();
    await r.tap(find.byKey(const Key('menu-0')), after: 2);
    expect(find.text('Todavía no hay pacientes'), findsOneWidget);
    r.chapter(
      '04 · Registrar paciente',
      'El botón + abre el formulario. El paciente queda asociado al profesional de la sesión.',
    );
    await r.tap(find.byTooltip('Registrar paciente'));
    await r.type(find.byKey(const Key('patient-name')), 'María Elena');
    await r.type(find.byKey(const Key('patient-surname')), 'Rojas Pérez');
    await r.tap(
      find.widgetWithText(TextFormField, 'Fecha de nacimiento'),
      after: 2,
    );
    await r.tap(find.text('15').last);
    await r.tap(find.text('OK'));
    await r.type(find.byKey(const Key('patient-dni')), '00000001');
    await r.tap(find.byType(DropdownButtonFormField<Sexo>));
    await r.tap(find.text('Femenino').last);
    await r.type(
      find.widgetWithText(TextFormField, 'Teléfono (opcional)'),
      '999000001',
    );
    await r.type(
      find.widgetWithText(TextFormField, 'Dirección (opcional)'),
      'Dirección de ejemplo',
    );
    await r.type(
      find.widgetWithText(TextFormField, 'Historia clínica (opcional)'),
      'HC-001 · Registro ficticio',
    );
    await r.hold(2);
    await r.tap(find.widgetWithText(FilledButton, 'Guardar'), after: 3);
    expect(dependencies.session.patients.patients, hasLength(1));
    r.chapter(
      '04 · Buscar y consultar',
      'La lista permite localizar al paciente por nombre o DNI y abrir su expediente.',
    );
    await r.type(find.byType(TextField), '00000001');
    await r.hold(2);
    await r.tap(find.text('María Elena Rojas Pérez'), after: 3);
    r.chapter(
      '04 · Editar paciente',
      'Se conservan la identidad y el responsable. Aquí se actualiza un dato de contacto.',
    );
    await r.tap(find.text('Editar paciente'));
    await r.type(
      find.widgetWithText(TextFormField, 'Teléfono (opcional)'),
      '999000002',
    );
    await r.tap(find.widgetWithText(FilledButton, 'Guardar'), after: 2);
    expect(dependencies.session.patients.patients.single.telefono, '999000002');
    await r.reveal(find.text('Teléfono'));
    await r.hold(3);
    await r.back();
    await r.back();
    r.chapter(
      '05 · Nueva evaluación',
      'Desde Capturar imágenes se eligen el paciente, el ojo y las observaciones.',
    );
    await r.tap(find.byKey(const Key('menu-1')), after: 2);
    await r.tap(find.text('María Elena Rojas Pérez'));
    await r.tap(find.text('Ojo derecho'));
    await r.type(
      find.widgetWithText(TextField, 'Observaciones (opcional)'),
      'Registro visual de ejemplo del ojo derecho.',
    );
    await r.tap(find.widgetWithText(FilledButton, 'Continuar'), after: 3);
    expect(find.byType(CaptureScreen), findsOneWidget);
    r.chapter(
      '05 · Cargar tres imágenes',
      'Se aceptan tres tomas diferentes del mismo ojo. Las muestras de este video son ilustraciones.',
    );
    await r.hold(3);
    for (var n = 0; n < 3; n++) {
      images.next = samples[n];
      if (n == 0) {
        await r.tap(find.byKey(const Key('image-slot-0')), after: 2);
        await r.tap(find.text('Elegir de la galería'));
      } else {
        await r.tap(find.text('Seleccionar de galería'));
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await r.animate(500);
      expect(find.byType(SingleImagePreviewScreen), findsOneWidget);
      r.chapter(
        '05 · Revisar imagen ${n + 1} de 3',
        'Se revisa cada imagen antes de aceptarla. La selección del dispositivo está representada con muestras locales.',
      );
      await r.hold(3);
      await r.tap(find.text('Usar imagen'));
      await r.reveal(find.text('${n + 1} de 3 imágenes seleccionadas'));
      await r.hold(2);
    }
    r.chapter(
      '06 · Confirmar las tres tomas',
      'Con las tres imágenes completas se habilita la revisión conjunta.',
    );
    await r.tap(find.byKey(const Key('review-images')));
    expect(find.byType(ReviewScreen), findsOneWidget);
    await r.hold(3);
    await r.reveal(find.byType(CheckboxListTile));
    await r.hold(3);
    await r.tap(find.byType(CheckboxListTile));
    await r.tap(find.byKey(const Key('show-evaluation')), after: 3);
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Imágenes pendientes de almacenamiento'), findsOneWidget);
    r.chapter(
      '06 · Preparar y guardar',
      'La evaluación aún no tiene grado ni confianza: la integración del modelo de IA está pendiente.',
    );
    await r.hold(4);
    await r.reveal(find.text('Sin recomendación disponible.'));
    await r.hold(3);
    r.chapter(
      '06 · Guardado y retorno al inicio',
      'Al terminar de guardar se vuelve al inicio. En este video el guardado se representa de forma local.',
    );
    await r.tap(find.widgetWithText(FilledButton, 'Guardar'), after: .1);
    await r.animate(1800);
    await r.hold(3);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(dependencies.session.evaluations.evaluations, hasLength(1));
    r.chapter(
      '07 · Historial de evaluaciones',
      'La evaluación aparece con miniatura, fecha, ojo y tres imágenes; sigue pendiente de análisis.',
    );
    await r.tap(find.byKey(const Key('menu-2')), after: 4);
    expect(find.byType(HistoryScreen), findsOneWidget);
    await r.tap(find.text('María Elena Rojas Pérez'), after: 4);
    expect(find.text('Pendiente de análisis'), findsOneWidget);
    r.chapter(
      '07 · Consultar imágenes',
      'El detalle conserva las tres imágenes y permite abrirlas en un visor con ampliación.',
    );
    final photo = find
        .ancestor(of: find.byType(Image).at(2), matching: find.byType(InkWell))
        .first;
    await r.tap(photo, after: 4);
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final a = await tester.startGesture(
      center - const Offset(45, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(45, 0),
      pointer: 2,
    );
    await a.moveTo(center - const Offset(100, 0));
    await b.moveTo(center + const Offset(100, 0));
    await r.animate(500);
    await a.up();
    await b.up();
    await r.hold(3);
    await r.back();
    await r.tap(find.text('Volver al historial'));
    await r.back();
    r.chapter(
      '08 · Estadísticas',
      'El resumen muestra un paciente, una evaluación guardada y tres imágenes del ojo derecho.',
    );
    await r.tap(find.byKey(const Key('menu-3')), after: 6);
    expect(find.text('Evaluaciones guardadas'), findsOneWidget);
    await r.back();
    r.chapter(
      '09 · Cerrar sesión',
      'El menú permite salir de la cuenta. La aplicación regresa a la bienvenida.',
    );
    await r.tap(find.byTooltip('Open navigation menu'), after: 2);
    await r.tap(find.text('Cerrar sesión'), after: 2);
    await r.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await r.animate(1800);
    await r.hold(3);
    expect(find.byType(HomeScreen), findsNothing);
    r.chapter(
      'Recorrido completado',
      'Solo funciones del profesional. Sin panel ni acciones administrativas.',
      card: 'Flujo del profesional completado\n\nCuenta y acceso\nRegistro y edición del paciente\nTres imágenes de un mismo ojo\nGuardado, historial y estadísticas\n\nModelo de IA pendiente de integración.',
    );
    await r.hold(8);
    expect(tester.takeException(), isNull);
    await r.finish();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
