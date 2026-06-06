import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import 'token_storage.dart';

typedef UnauthorizedCallback = void Function();

class ApiClient {
  ApiClient._();

  static const _requestTimeout = Duration(seconds: 15);

  /// Called when a protected request gets 401 and token refresh fails.
  static UnauthorizedCallback? onUnauthorized;

  static Future<http.Response> get(Uri uri, {bool auth = true}) {
    return _send(() async => http
        .get(uri, headers: await _headers(auth))
        .timeout(_requestTimeout));
  }

  static Future<http.Response> post(
    Uri uri, {
    Object? body,
    bool auth = true,
  }) {
    return _send(
      () async => http
          .post(uri, headers: await _headers(auth), body: body)
          .timeout(_requestTimeout),
    );
  }

  static Future<http.Response> put(
    Uri uri, {
    Object? body,
    bool auth = true,
  }) {
    return _send(
      () async => http
          .put(uri, headers: await _headers(auth), body: body)
          .timeout(_requestTimeout),
    );
  }

  static Future<http.Response> delete(Uri uri, {bool auth = true}) {
    return _send(() async => http
        .delete(uri, headers: await _headers(auth))
        .timeout(_requestTimeout));
  }

  static Future<Map<String, String>> _headers(bool auth) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache',
    };
    if (!auth) return headers;

    final token = await TokenStorage.accessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Action Cable WebSocket URI with JWT query param (see backend connection.rb).
  static Future<Uri> cableWebSocketUri(String wsUrl) async {
    final uri = Uri.parse(wsUrl);
    final token = await TokenStorage.accessToken();
    if (token == null || token.isEmpty) return uri;

    final params = Map<String, String>.from(uri.queryParameters);
    params['token'] = token;
    return uri.replace(queryParameters: params);
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();
    if (response.statusCode != 401) return response;

    final refreshed = await _refreshAccessToken();
    if (!refreshed) {
      onUnauthorized?.call();
      return response;
    }

    return request();
  }

  static Future<bool> _refreshAccessToken() async {
    final refresh = await TokenStorage.refreshToken();
    if (refresh == null || refresh.isEmpty) return false;

    final response = await http.post(
      Uri.parse('${AppConfig.apiV1}/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh_token': refresh}),
    );

    if (response.statusCode != 200) {
      await TokenStorage.clear();
      return false;
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    await TokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return true;
  }
}
