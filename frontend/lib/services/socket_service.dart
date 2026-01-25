import 'package:action_cable/action_cable.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  ActionCable? _cable;
  final String _baseUrl = 'ws://localhost:3000/cable';

  void connect({
    required String channel,
    required Function(Map<String, dynamic>) onMessage,
  }) {
    if (kIsWeb) {
      print('ActionCable is not supported on Web in this version');
      return;
    }
    _cable = ActionCable.connect(
      _baseUrl,
      onConnected: () => print('Connected to ActionCable'),
      onConnectionLost: () => print('Connection lost'),
      onCannotConnect: () => print('Cannot connect'),
    );

    _cable?.subscribe(
      channel,
      onMessage: (dynamic data) {
        if (data is Map) {
          onMessage(Map<String, dynamic>.from(data));
        } else if (data is String) {
          try {
            final decoded = json.decode(data);
            if (decoded is Map) {
              onMessage(Map<String, dynamic>.from(decoded));
            }
          } catch (e) {
            print('Error decoding socket message: $e');
          }
        }
      },
    );
  }

  void disconnect() {
    if (kIsWeb) return;
    _cable?.disconnect();
  }
}

