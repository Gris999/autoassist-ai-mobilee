class AuthUser {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String celular;
  final String email;
  final bool estado;
  final DateTime? fechaRegistro;
  final List<String> roles;

  const AuthUser({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.celular,
    required this.email,
    required this.estado,
    required this.fechaRegistro,
    required this.roles,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      idUsuario: json['id_usuario'] as int? ?? 0,
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      celular: json['celular'] as String? ?? '',
      email: json['email'] as String? ?? '',
      estado: json['estado'] as bool? ?? false,
      fechaRegistro: DateTime.tryParse(
        json['fecha_registro'] as String? ?? '',
      ),
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .map((role) => role.toString().toUpperCase())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': idUsuario,
      'nombres': nombres,
      'apellidos': apellidos,
      'celular': celular,
      'email': email,
      'estado': estado,
      'fecha_registro': fechaRegistro?.toIso8601String(),
      'roles': roles,
    };
  }

  String get displayName {
    final fullName = '$nombres $apellidos'.trim();
    return fullName.isEmpty ? email : fullName;
  }

  bool hasRole(String role) {
    return roles.contains(role.toUpperCase());
  }
}
