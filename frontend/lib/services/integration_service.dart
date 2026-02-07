import 'dart:convert';
import 'package:http/http.dart' as http;

class IntegrationService {
  static const String baseUrl = 'http://localhost:3000/api/v1';

  Future<List<dynamic>> syncPreview({String provider = 'orcid'}) async {
    final response = await http.get(Uri.parse('$baseUrl/integrations/sync_preview?provider=$provider'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['results'];
    } else {
      throw Exception('Failed to get sync preview');
    }
  }

  Future<Map<String, dynamic>> saveAchievements(List<dynamic> achievements) async {
    final response = await http.post(
      Uri.parse('$baseUrl/integrations/save_achievements'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievements': achievements}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to save achievements');
    }
  }
}

