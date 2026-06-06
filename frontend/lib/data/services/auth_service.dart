import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../models/auth_user.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  static const _base = '${AppConfig.apiV1}/auth';

  Future<AuthUser> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? fullName,
  }) async {
    final response = await ApiClient.post(
      Uri.parse('$_base/register'),
      auth: false,
      body: json.encode({
        'user': {
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        },
      }),
    );
    return _parseAuthResponse(response);
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post(
      Uri.parse('$_base/login'),
      auth: false,
      body: json.encode({
        'user': {'email': email, 'password': password},
      }),
    );
    return _parseAuthResponse(response);
  }

  Future<AuthUser?> me() async {
    final response = await ApiClient.get(Uri.parse('$_base/me'));
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to load profile');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refresh = await TokenStorage.refreshToken();
    if (refresh != null) {
      await ApiClient.post(
        Uri.parse('$_base/logout'),
        body: json.encode({'refresh_token': refresh}),
      );
    }
    await TokenStorage.clear();
  }

  Future<AuthUser> _parseAuthResponse(http.Response response) async {
    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = response.body;
      throw Exception(body.isEmpty ? 'Auth failed' : body);
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    await TokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }
}
