import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:research_activity_monitoring_system/core/config.dart';
import 'action_cable_wire.dart';
import 'api_client.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  var _subscribed = false;
  String? _identifier;
  final String _baseUrl = '${AppConfig.wsBase}/cable';

  Future<void> connect({
    required String channel,
    required void Function(Map<String, dynamic>) onMessage,
  }) async {
    disconnect();
    _identifier = ActionCableWire.encodeChannelId(channel, <String, dynamic>{});
    _subscribed = false;
    final uri = await ApiClient.cableWebSocketUri(_baseUrl);
    if (!uri.queryParameters.containsKey('token')) return;

    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      (dynamic frame) {
        final decoded = ActionCableWire.decodeFrame(frame);
        if (decoded == null) return;
        if (decoded['type'] != null) {
          switch (decoded['type']?.toString()) {
            case 'welcome':
              if (!_subscribed && _identifier != null) {
                _subscribed = true;
                _channel!.sink.add(jsonEncode(<String, dynamic>{
                  'identifier': _identifier,
                  'command': 'subscribe',
                }));
              }
              break;
            case 'ping':
            case 'confirm_subscription':
              break;
            default:
              break;
          }
        } else if (decoded['identifier'] != null && decoded.containsKey('message')) {
          final raw = decoded['message'];
          if (raw is Map) {
            onMessage(Map<String, dynamic>.from(raw));
          } else if (raw is String) {
            try {
              final inner = jsonDecode(raw);
              if (inner is Map) {
                onMessage(Map<String, dynamic>.from(inner));
              }
            } catch (_) {}
          }
        }
      },
      onError: (Object e, StackTrace _) {
        // ignore: avoid_print
        print('WebSocket error: $e');
      },
    );
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _identifier = null;
    _subscribed = false;
  }
}
