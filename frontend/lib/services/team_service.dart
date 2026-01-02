import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class TeamService {
  static const String baseUrl = 'http://localhost:3000/api/v1';

  Future<List<Team>> getAll() async {
    final response = await http.get(Uri.parse('$baseUrl/teams'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Team.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load projects');
    }
  }

  Future<Team> create(Team team) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'team': team.toJson()}),
    );
    if (response.statusCode == 201) {
      return Team.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create project');
    }
  }

  Future<Team> update(int id, Team team) async {
    final response = await http.put(
      Uri.parse('$baseUrl/teams/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'team': team.toJson()}),
    );
    if (response.statusCode == 200) {
      return Team.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update project');
    }
  }

  Future<void> delete(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/teams/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete project');
    }
  }
}

