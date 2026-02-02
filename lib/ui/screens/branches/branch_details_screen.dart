import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '/core/services/api/api_service.dart';
import '/data/models/branch.dart';
import '/data/models/team.dart';
import '/data/models/user.dart'; // Adicionado

class BranchDetailsScreen extends StatefulWidget {
  final Branch branch;

  const BranchDetailsScreen({super.key, required this.branch});

  @override
  State<BranchDetailsScreen> createState() => _BranchDetailsScreenState();
}

class _BranchDetailsScreenState extends State<BranchDetailsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Team>> _teamsFuture;
  late Future<List<User>> _usersFuture; // Adicionado

  @override
  void initState() {
    super.initState();
    _teamsFuture = _apiService.getTeamsForBranch(widget.branch.id);
    _usersFuture = _apiService.getUsersForBranch(widget.branch.id); // Adicionado
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.branch.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context, 'Estatísticas'),
          _buildStatisticCard(
              'Precisando de Manutenção', '${widget.branch.transformersNeedingMaintenance}'),
          const Gap(24),

          _buildSectionTitle(context, 'Usuários da Filial'), // Alterado de Sub-Admins
          // Substituído por um FutureBuilder
          FutureBuilder<List<User>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nenhum usuário encontrado nesta filial.'));
              }

              final users = snapshot.data!;
              return Column(
                children: users.map((user) => Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    leading: Icon(user.role == 'sub_admin' ? Icons.admin_panel_settings : Icons.person_outline),
                    title: Text(user.name),
                    subtitle: Text(user.designation ?? user.email), // Mostra o cargo ou o email
                    trailing: Text(
                      user.role == 'sub_admin' ? 'Sub-Admin' : (user.role ?? 'Funcionário'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontStyle: FontStyle.italic
                      ),
                    ),
                  ),
                )).toList(),
              );
            },
          ),
          const Gap(24),

          _buildSectionTitle(context, 'Equipes'),
          FutureBuilder<List<Team>>(
            future: _teamsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nenhuma equipe encontrada nesta filial.'));
              }

              final teams = snapshot.data!;
              return Column(
                children: teams.map((team) => Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    leading: const Icon(Icons.group),
                    title: Text(team.name),
                    subtitle: Text('${team.members.length} membros'), // Isto agora usa a lista de Users
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatisticCard(String title, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
