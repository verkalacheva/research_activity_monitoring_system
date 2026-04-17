import 'dart:collection';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;

/// Общие куски протокола Action Cable (JSON по WebSocket).
class ActionCableWire {
  ActionCableWire._();

  /// Как в пакете action_cable: стабильный JSON идентификатора подписки.
  static String encodeChannelId(String channelName, Map<String, dynamic> channelParams) {
    final fullChannelName =
        channelName.endsWith('Channel') ? channelName : '${channelName}Channel';
    final channelId = Map<String, dynamic>.from(channelParams);
    channelId['channel'] ??= fullChannelName;
    return jsonEncode(SplayTreeMap<String, dynamic>.from(channelId));
  }

  static Map<String, dynamic>? decodeFrame(dynamic frame) {
    String? s;
    if (frame is String) {
      s = frame;
    } else if (frame is List<int>) {
      s = utf8.decode(frame);
    }
    if (s == null) return null;
    try {
      final o = jsonDecode(s);
      if (o is Map<String, dynamic>) return o;
      if (o is Map) return Map<String, dynamic>.from(o);
    } catch (_) {}
    return null;
  }
}
