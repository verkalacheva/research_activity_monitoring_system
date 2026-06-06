import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/sync_notification_service.dart';
import '../../data/services/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthNotifier extends ChangeNotifier {
  AuthNotifier({AuthService? authService}) : _authService = authService ?? AuthService();

  final AuthService _authService;

  AuthStatus status = AuthStatus.unknown;
  AuthUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  Future<void> bootstrap() async {
    try {
      final token = await TokenStorage.accessToken();
      if (token == null || token.isEmpty) {
        status = AuthStatus.unauthenticated;
        return;
      }

      user = await _authService.me().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      if (user == null) {
        await TokenStorage.clear();
        status = AuthStatus.unauthenticated;
      } else {
        status = AuthStatus.authenticated;
      }
    } catch (_) {
      await TokenStorage.clear();
      status = AuthStatus.unauthenticated;
      user = null;
    } finally {
      notifyListeners();
      if (isAuthenticated) {
        unawaited(_afterAuthenticated());
      }
    }
  }

  Future<void> login(String email, String password) async {
    user = await _authService.login(email: email, password: password);
    status = AuthStatus.authenticated;
    notifyListeners();
    await _afterAuthenticated();
  }

  Future<void> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? fullName,
  }) async {
    user = await _authService.register(
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      fullName: fullName,
    );
    status = AuthStatus.authenticated;
    notifyListeners();
    await _afterAuthenticated();
  }

  Future<void> logout() async {
    await _authService.logout();
    SyncNotificationService.instance.resetForLogout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void handleSessionExpired() {
    if (!isAuthenticated) return;
    unawaited(TokenStorage.clear());
    SyncNotificationService.instance.resetForLogout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _afterAuthenticated() async {
    await SyncNotificationService.instance.ensureStarted();
  }
}
