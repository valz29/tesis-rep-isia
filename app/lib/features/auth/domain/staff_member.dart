enum AccountRole { professional, admin }

class StaffMember {
  final String id;
  final String usuario;
  final String nombre;
  final AccountRole role;
  const StaffMember({
    required this.id,
    required this.usuario,
    required this.nombre,
    this.role = AccountRole.professional,
  });
  bool get isAdmin => role == AccountRole.admin;
}
