import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:research_activity_monitoring_system/core/config.dart';

class ReportService {
  static const String baseUrl = AppConfig.reportsV1;

  Future<Map<String, dynamic>> getSelectors() async {
    final response = await http.get(Uri.parse('$baseUrl/selectors'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load report selectors');
    }
  }

  Future<Map<String, dynamic>> generateReport(Map<String, dynamic> params) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(params),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to generate report');
    }
  }

  Future<Map<String, dynamic>> getDashboardData({DateTime? startDate, DateTime? endDate}) async {
    final Map<String, dynamic> params = {
      'report_type': 'dashboard_overview',
      'report_format': 'json',
    };

    if (startDate != null) {
      params['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      params['end_date'] = endDate.toIso8601String().split('T')[0];
    }

    final response = await http.post(
      Uri.parse('$baseUrl/generate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(params),
    );
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      final data = result['data'];
      if (data is String) {
        return json.decode(data);
      }
      return data as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load dashboard data');
    }
  }

  Future<Map<String, dynamic>> getSelectorOptions(String url, {int limit = 10, int offset = 0}) async {
    // URL might be relative like /api/v1/selectors/...
    final fullUrl = url.startsWith('http') ? url : '${AppConfig.apiBase}$url';
    final response = await http.post(
      Uri.parse(fullUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'limit': limit, 'offset': offset}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load selector options');
    }
  }
}


