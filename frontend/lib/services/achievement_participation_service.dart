import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AchievementParticipationService {
  static const String baseUrl = 'http://localhost:3000/api/v1';

  Future<List<AchievementParticipation>> getAll() async {
    final response = await http.get(Uri.parse('$baseUrl/achievement_participations'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => AchievementParticipation.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load participation types');
    }
  }

  Future<AchievementParticipation> create(AchievementParticipation participation) async {
    final response = await http.post(
      Uri.parse('$baseUrl/achievement_participations'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement_participation': participation.toJson()}),
    );
    if (response.statusCode == 201) {
      return AchievementParticipation.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create participation type');
    }
  }

  Future<AchievementParticipation> update(int id, AchievementParticipation participation) async {
    final response = await http.put(
      Uri.parse('$baseUrl/achievement_participations/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement_participation': participation.toJson()}),
    );
    if (response.statusCode == 200) {
      return AchievementParticipation.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update participation type');
    }
  }

  Future<void> delete(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/achievement_participations/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete participation type');
    }
  }
}

