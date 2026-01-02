import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ResearcherService {
  static const String baseUrl = 'http://localhost:3000/api/v1';

  Future<List<Researcher>> getAll() async {
    final response = await http.get(Uri.parse('$baseUrl/researchers'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Researcher.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load researchers');
    }
  }

  Future<Researcher> create(Researcher researcher) async {
    final response = await http.post(
      Uri.parse('$baseUrl/researchers'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'researcher': researcher.toJson()}),
    );
    if (response.statusCode == 201) {
      return Researcher.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create researcher');
    }
  }

  Future<Researcher> update(int id, Researcher researcher) async {
    final response = await http.put(
      Uri.parse('$baseUrl/researchers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'researcher': researcher.toJson()}),
    );
    if (response.statusCode == 200) {
      return Researcher.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update researcher');
    }
  }

  Future<void> delete(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/researchers/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete researcher');
    }
  }
}

