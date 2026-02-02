// import 'dart:convert'; // Não é mais necessário
// import '/data/models/user.dart'; // Não é mais necessário

class Branch {
  final int id;
  final String name;
  final String address;
  // final List<User> subAdmins; // Removido
  final int transformersNeedingMaintenance;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    // required this.subAdmins, // Removido
    required this.transformersNeedingMaintenance,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    // Lógica de 'sub_admins' totalmente removida
    return Branch(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      // subAdmins: subAdminUsers, // Removido
      transformersNeedingMaintenance: int.parse(json['transformers_needing_maintenance']?.toString() ?? '0'),
    );
  }
}
