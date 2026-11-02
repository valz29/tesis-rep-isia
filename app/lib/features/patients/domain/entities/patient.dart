enum Sexo { femenino, masculino }

/// Patient identity. Eye and visit observations belong to an evaluation.
class Patient {
  final String id;
  final String dni;
  final String nombres;
  final String apellidos;
  final DateTime fechaNacimiento;
  final Sexo sexo;
  final String? telefono;
  final String? direccion;
  final String? historiaClinica;

  const Patient({
    required this.id,
    required this.dni,
    required this.nombres,
    required this.apellidos,
    required this.fechaNacimiento,
    required this.sexo,
    this.telefono,
    this.direccion,
    this.historiaClinica,
  });
  String get nombreCompleto => '$nombres $apellidos';
  int ageAt(DateTime date) {
    var age = date.year - fechaNacimiento.year;
    if (date.isBefore(
      DateTime(date.year, fechaNacimiento.month, fechaNacimiento.day),
    )) {
      age--;
    }
    return age;
  }
}
