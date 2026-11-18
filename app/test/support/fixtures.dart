import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rd_app/app/app_scope.dart';
import 'package:rd_app/app/dependencies.dart';
import 'package:rd_app/core/app_theme.dart';
import 'package:rd_app/features/evaluations/domain/evaluation_image.dart';
import 'package:rd_app/features/evaluations/domain/evaluation_repository.dart';
import 'package:rd_app/features/evaluations/domain/image_acquisition_repository.dart';
import 'package:rd_app/features/patients/domain/patient.dart';

import 'fakes/in_memory_admin_repository.dart';
import 'fakes/in_memory_evaluation_repository.dart';
import 'fakes/in_memory_patient_repository.dart';
import 'fakes/preview_auth_repository.dart';

AppDependencies memoryDependencies() => AppDependencies(
  authRepository: PreviewAuthRepository(),
  patientRepository: InMemoryPatientRepository(),
  evaluationRepository: InMemoryEvaluationRepository(),
  imageRepository: TestImageRepository(),
  adminRepository: InMemoryAdminRepository(),
);

final patient = Patient(
  id: 'patient-1',
  ownerId: 'demo@example.com',
  dni: '12345678',
  nombres: 'Paciente',
  apellidos: 'Ejemplo',
  fechaNacimiento: DateTime(1980, 1, 1),
  sexo: Sexo.femenino,
);

class TestImageRepository implements ImageAcquisitionRepository {
  EvaluationImage? next;
  @override
  Future<EvaluationImage?> pick(ImageOrigin origin) async => next;
}

Uint8List photo(int n) => Uint8List.fromList([
  ...base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAD0lEQVR4nGNgaGgAIQgFABoOBAH77Fo+AAAAAElFTkSuQmCC',
  ),
  n,
]);
Future<AppDependencies> createDependencies({
  bool seedPatient = false,
  ImageAcquisitionRepository? images,
  EvaluationRepository? evaluations,
}) async {
  final patients = InMemoryPatientRepository();
  if (seedPatient) await patients.save(patient);
  final dependencies = AppDependencies(
    authRepository: PreviewAuthRepository(),
    adminRepository: InMemoryAdminRepository(),
    patientRepository: patients,
    evaluationRepository: evaluations ?? InMemoryEvaluationRepository(),
    imageRepository: images ?? TestImageRepository(),
  );
  await dependencies.session.auth.login('demo@example.com', 'demo');
  await dependencies.session.patients.load();
  return dependencies;
}

Widget harness(AppDependencies dependencies, Widget home, {Key? key}) =>
    AppScope(
      session: dependencies.session,
      child: MaterialApp(key: key, theme: AppTheme.light(), home: home),
    );
