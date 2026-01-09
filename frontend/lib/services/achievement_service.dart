import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AchievementService {
  static const String baseUrl = 'http://localhost:3000/api/v1';

  Future<Achievement> create(Achievement achievement, List<int> researcherIds) async {
    final body = achievement.toJson();
    body['researcher_ids'] = researcherIds;

    final response = await http.post(
      Uri.parse('$baseUrl/achievements'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement': body}),
    );
    
    if (response.statusCode == 201) {
      return Achievement.fromJson(json.decode(response.body));
    } else {
      final error = json.decode(response.body);
      throw Exception(error['errors']?.join(', ') ?? 'Failed to create achievement');
    }
  }

  Future<Achievement> update(int id, Achievement achievement, List<int> researcherIds) async {
    final body = achievement.toJson();
    body['researcher_ids'] = researcherIds;

    final response = await http.put(
      Uri.parse('$baseUrl/achievements/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement': body}),
    );

    if (response.statusCode == 200) {
      return Achievement.fromJson(json.decode(response.body));
    } else {
      final error = json.decode(response.body);
      throw Exception(error['errors']?.join(', ') ?? 'Failed to update achievement');
    }
  }

  Future<void> delete(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/achievements/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete achievement');
    }
  }

  Future<Map<String, dynamic>> importAchievements({String? filePath, List<int>? bytes, String? fileName}) async {
    return _importMultipart('$baseUrl/achievements/import', filePath: filePath, bytes: bytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> importResearchers({String? filePath, List<int>? bytes, String? fileName}) async {
    return _importMultipart('$baseUrl/researchers/import', filePath: filePath, bytes: bytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> _importMultipart(String url, {String? filePath, List<int>? bytes, String? fileName}) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));
    
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    } else if (bytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    } else {
      throw Exception('Не удалось прочитать файл');
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      final message = error['errors'] ?? error['message'] ?? 'Failed to import';
      throw Exception(message);
    }
  }
}


