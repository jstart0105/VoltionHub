import 'package:flutter/material.dart';
import 'team_details_screen.dart';
import 'widgets/team_card.dart';
import 'widgets/team_form_dialog.dart';
import '/core/services/api/api_service.dart';
import '/data/models/team.dart';
import '/ui/widgets/textfield.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Team>> _teamsFuture;
  List<Team> _allTeams = [];
  List<Team> _filteredTeams = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _searchController.addListener(_filterTeams);
  }

  void _loadTeams() {
    setState(() {
      _teamsFuture = _apiService.getTeams();
       _teamsFuture.then((teams) {
        setState(() {
          _allTeams = teams;
          _filteredTeams = teams;
        });
      });
    });
  }

  void _filterTeams() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeams = _allTeams.where((team) {
        return team.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _showTeamForm({Team? team}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: TeamFormBottomSheet(
          team: team,
          branchId: 1, // Você talvez queira buscar a branch do usuário logado
          apiService: _apiService,
          onSave: _loadTeams,
        ),
      ),
    );
  }

   void _deleteTeam(int teamId) async {
    try {
      await _apiService.deleteTeam(teamId);
      _loadTeams();
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipe deletada com sucesso!'), backgroundColor: Colors.green),
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao deletar equipe: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToTeamDetails(Team team) async {
    // A navegação agora espera um 'true' para recarregar
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailsScreen(team: team),
      ),
    );

    // Se o TeamDetailsScreen retornar true (ex: após remover um membro),
    // recarregamos a lista de equipes para atualizar a contagem de membros.
    if (result == true) {
      _loadTeams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Equipes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showTeamForm(),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomTextField(
                controller: _searchController,
                labelText: 'Procurar Equipes',
                icon: Icons.search,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Team>>(
                future: _teamsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhuma equipe encontrada.'));
                  }

                  return ListView.builder(
                    itemCount: _filteredTeams.length,
                    itemBuilder: (context, index) {
                      final team = _filteredTeams[index];
                      return TeamCard(
                        team: team,
                        onTap: () => _navigateToTeamDetails(team), // Atualizado
                        onEdit: () => _showTeamForm(team: team),
                        onDelete: () => _deleteTeam(team.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
