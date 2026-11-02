String? validarCorreo(String? valor) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(valor?.trim() ?? '')
    ? null
    : 'Ingresa un correo electrónico válido';
