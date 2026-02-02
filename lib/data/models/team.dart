import 'user.dart'; // Alterado de employee.dart para user.dart

class Team {
  final int id;
  String name;
  final int branchId;
  final User? responsible;
  List<User> members; // Alterado de Employee para User

  Team({
    required this.id,
    required this.name,
    required this.branchId,
    this.responsible,
    required this.members,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    var membersList = json['members'] as List? ?? [];
    // Alterado de Employee para User
    List<User> userMembers = membersList.map((i) => User.fromJson(i)).toList();

    return Team(
      id: json['id'],
      name: json['name'],
      branchId: json['branch_id'],
      responsible: json['responsible'] != null ? User.fromJson(json['responsible']) : null,
      members: userMembers, // Alterado para userMembers
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'branch_id': branchId,
      'responsible_id': responsible?.id,
      // Alterado para chamar toJson() em User
      'members': members.map((u) => u.toJson()).toList(),
    };
  }
}
