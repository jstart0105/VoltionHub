import 'package:flutter/material.dart';
import '/data/models/user.dart'; // Alterado de employee.dart

class TeamMemberCard extends StatelessWidget {
  final User member; // Alterado de Employee
  // final VoidCallback onEdit; // Removido
  final VoidCallback onDelete;

  const TeamMemberCard({
    super.key,
    required this.member,
    // required this.onEdit, // Removido
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(member.name),
        // Atualizado para mostrar cargo (designation) ou role
        subtitle: Text(member.designation ?? member.role ?? 'Cargo não definido'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /* Removido
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            */
            IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.redAccent),
              tooltip: "Remover da equipe",
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
