import 'package:flutter/material.dart';
import 'widgets/team_member_card.dart'; // Alterado de member_card.dart
// import 'widgets/member_form_dialog.dart'; // Removido
import '/core/services/api/api_service.dart';
import '/data/models/user.dart'; // Alterado de employee.dart
import '/data/models/team.dart';

class TeamDetailsScreen extends StatefulWidget {
  final Team team;

  const TeamDetailsScreen({super.key, required this.team});

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final ApiService _apiService = ApiService();
  late List<User> _members; // Alterado de Employee
  late Future<Team> _teamFuture;

  @override
  void initState() {
    super.initState();
    _members = widget.team.members;
    // Inicializa o _teamFuture para recarregar dados se necessário
    _teamFuture = Future.value(widget.team);
  }

  // Alterado para remover usuário do time (setar team_id = null)
  void _removeMemberFromTeam(User member) async {
    try {
      // Chama a API para atualizar o usuário, setando team_id para null
      await _apiService.updateUser(
        member.id,
        teamId: null, // Define o team_id como nulo
        // Mantém os outros dados do usuário
        name: member.name,
        email: member.email,
        role: member.role,
        designation: member.designation,
        branchId: member.branchId,
      );
      
      // Atualiza a UI removendo o membro da lista local
      setState(() {
        _members.removeWhere((m) => m.id == member.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} removido(a) da equipe.'), backgroundColor: Colors.green),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao remover membro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.name),
        actions: [
          // Botão de adicionar membro foi REMOVIDO
        ],
      ),
      // Usando FutureBuilder para garantir que os dados sejam recarregados
      body: FutureBuilder<Team>(
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }

          // Usa a lista _members que é atualizada pelo _refreshTeamData
          if (_members.isEmpty) {
            return const Center(child: Text("Nenhum membro nesta equipe."));
          }

          return ListView.builder(
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              return TeamMemberCard( // Alterado de MemberCard
                member: member,
                // onEdit: () {}, // Removido
                onDelete: () => _removeMemberFromTeam(member), // Alterado
              );
            },
          );
        }
      ),
    );
  }
}
