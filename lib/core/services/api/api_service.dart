import 'dart:convert';
import 'package:http/http.dart' as http;
import '/data/models/branch.dart';
import '/data/models/team.dart';
import '/data/models/transformer_metric.dart';
import '/data/models/user.dart';

class ApiService {
  // final String baseUrl = 'http://172.16.1.216:3000';
  final String baseUrl = 'http://192.168.100.171:3000';

  // --- User Methods ---
  Future<List<User>> getUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => User.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<List<User>> getUsersForBranch(int branchId) async {
    final response = await http.get(Uri.parse('$baseUrl/branches/$branchId/users'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => User.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load users for branch $branchId');
    }
  }

  Future<User> updateUser(int id, {
    String? name,
    String? email,
    String? role,
    String? designation,
    int? branchId,
    int? teamId,
  }) async {
    final currentUserData = await http.get(Uri.parse('$baseUrl/users/$id'));
    if (currentUserData.statusCode != 200) {
       throw Exception('Failed to fetch user for update');
    }
    final userMap = json.decode(currentUserData.body);

    final body = {
      'name': name ?? userMap['name'],
      'email': email ?? userMap['email'],
      'role': role ?? userMap['role'],
      'designation': designation ?? userMap['designation'],
      'branch_id': branchId ?? userMap['branch_id'],
      'team_id': teamId,
    };
    
    body.removeWhere((key, value) => value == null && key != 'team_id');

    final response = await http.put(
      Uri.parse('$baseUrl/users/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update user');
    }
  }


  // --- Branch Methods ---
  Future<List<Branch>> getBranches() async {
    final response = await http.get(Uri.parse('$baseUrl/branches'));
    if (response.statusCode == 200) {
      final decodedBody = json.decode(response.body);
      
      if (decodedBody is List) {
        return decodedBody.map((item) => Branch.fromJson(item)).toList();
      } 
      else if (decodedBody is Map<String, dynamic>) {
        if (decodedBody.containsKey('branches') && decodedBody['branches'] is List) {
          return (decodedBody['branches'] as List)
              .map((item) => Branch.fromJson(item))
              .toList();
        } else if (decodedBody.containsKey('data') && decodedBody['data'] is List) {
          return (decodedBody['data'] as List)
              .map((item) => Branch.fromJson(item))
              .toList();
        }
      }
      throw Exception('Failed to load branches: Unexpected JSON format');

    } else {
      throw Exception('Failed to load branches with status code: ${response.statusCode}');
    }
  }

  Future<Branch> addBranch(String name, String address) async {
    final response = await http.post(
      Uri.parse('$baseUrl/branches'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'address': address}),
    );
    if (response.statusCode == 201) {
      return Branch.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add branch');
    }
  }

  Future<Branch> updateBranch(int id, String name, String address) async {
    final response = await http.put(
      Uri.parse('$baseUrl/branches/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'address': address}),
    );
    if (response.statusCode == 200) {
      return Branch.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update branch');
    }
  }

  Future<void> deleteBranch(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/branches/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete branch');
    }
  }
  
  // --- Team Methods ---
  Future<Team> addTeam(String name, int branchId, int? responsibleId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'branch_id': branchId, 'responsible_id': responsibleId}),
    );
    if (response.statusCode == 201) {
      return Team.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add team');
    }
  }

  Future<Team> updateTeam(int teamId, String name, int? responsibleId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/teams/$teamId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'responsible_id': responsibleId}),
    );
    if (response.statusCode == 200) {
      return Team.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update team');
    }
  }

  Future<List<Team>> getTeamsForBranch(int branchId) async {
    final response = await http.get(Uri.parse('$baseUrl/branches/$branchId/teams'));
      if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => Team.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load teams for branch');
    }
  }

  Future<List<Team>> getTeams() async {
    final response = await http.get(Uri.parse('$baseUrl/teams'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => Team.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load teams');
    }
  }

  Future<void> deleteTeam(int teamId) async {
    final response = await http.delete(Uri.parse('$baseUrl/teams/$teamId'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete team');
    }
  }

  // --- Transformers Methods ---

  // ----- Transformer Metrics Methods -----

  Future<List<TransformerMetric>> getTransformerMetrics(
    String transformerId, {
    DateTime? start,
    DateTime? end,
  }) async {
    var uri = Uri.parse('$baseUrl/transformers/$transformerId/metrics');
    
    final Map<String, String> queryParameters = {};
    if (start != null) {
      queryParameters['start'] = start.toIso8601String();
    }
    if (end != null) {
      queryParameters['end'] = end.toIso8601String();
    }

    if (queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    final response = await http.get(uri);
    
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => TransformerMetric.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load metrics for transformer $transformerId');
    }
  }

  Future<TransformerMetric> addMetric(TransformerMetric metric) async {
    final response = await http.post(
      Uri.parse('$baseUrl/metrics'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(metric.toJson()),
    );
    
    if (response.statusCode == 201) {
      return TransformerMetric.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add metric');
    }
  }

  // ----- Transformer Metrics Methods -----
}
