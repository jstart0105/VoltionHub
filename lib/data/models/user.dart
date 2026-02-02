class User {
  final int id;
  final String name;
  final String email;
  final String? password;
  final String? role;
  // CAMPOS ADICIONADOS
  final String? designation; // Cargo
  final int? branchId;
  final int? teamId;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password,
    this.role,
    // CAMPOS ADICIONADOS
    this.designation,
    this.branchId,
    this.teamId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id']?.toString() ?? '') 
          ?? (throw FormatException('Missing or invalid ID for User: ${json['id']}')),
      name: json['name'],
      email: json['email'],
      password: json['password'],
      role: json['role'],
      // CAMPOS ADICIONADOS
      designation: json['designation'],
      branchId: json['branch_id'],
      teamId: json['team_id'],
    );
  }

  // MÉTODO ADICIONADO (para PUT /users/:id)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'designation': designation,
      'branch_id': branchId,
      'team_id': teamId,
      // Não inclua a senha no toJson por segurança, a menos que seja para criar/resetar
    };
  }
}
