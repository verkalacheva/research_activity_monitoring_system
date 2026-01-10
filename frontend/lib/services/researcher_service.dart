import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ResearcherService {
  static const String baseUrl = 'http://localhost:3000/api/v1';

  Future<List<Researcher>> getAll() async {
    final response = await http.get(Uri.parse('$baseUrl/researchers/list?limit=1000'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      List itemsJson = jsonResponse['items'];
      return itemsJson.map((data) => Researcher.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load researchers');
    }
  }

  Future<PaginatedResponse<Researcher>> list({int limit = 20, int offset = 0}) async {
    final response = await http.get(Uri.parse('$baseUrl/researchers/list?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final List itemsJson = jsonResponse['items'];
      final items = itemsJson.map((data) => Researcher.fromJson(data)).toList();
      final pagination = PaginationMetadata.fromJson(jsonResponse['pagination']);
      return PaginatedResponse(items: items, pagination: pagination);
    } else {
      throw Exception('Failed to load researchers list');
    }
  }

  Future<Researcher> getById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/researchers/$id'));
    if (response.statusCode == 200) {
      return Researcher.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load researcher profile');
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

