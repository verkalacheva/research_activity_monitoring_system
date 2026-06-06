import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'action_cable_wire.dart';
import 'api_client.dart';
import 'sync_preview_exceptions.dart';

/// Подмножество Action Cable для канала `IntegrationSyncJobChannel`.
/// Использует [WebSocketChannel] (VM + web), без `dart:io`-only клиента.
class IntegrationSyncJobSocket {
  IntegrationSyncJobSocket._();

  /// [wsUrl] — полный WebSocket URL (как правило apiBase → ws/wss + путь `/cable`).
  static Future<List<dynamic>> waitForCompletion({
    required String wsUrl,
    required String jobId,
    required Duration timeout,
    bool Function()? shouldAbort,
  }) async {
    final completer = Completer<List<dynamic>>();
    WebSocketChannel? ch;
    StreamSubscription<dynamic>? sub;
    var subscribed = false;

    final identifier =
        ActionCableWire.encodeChannelId('IntegrationSyncJobChannel', <String, dynamic>{'job_id': jobId});

    void finishError(Object e) {
      if (!completer.isCompleted) {
        completer.completeError(e is Exception ? e : Exception(e.toString()));
      }
    }

    void finishOk(List<dynamic> results) {
      if (!completer.isCompleted) {
        completer.complete(results);
      }
    }

    void handleChannelMessage(dynamic rawMessage) {
      if (completer.isCompleted) return;
      if (shouldAbort != null && shouldAbort()) {
        finishError(SyncPreviewAborted());
        return;
      }
      final map = _normalizeMessage(rawMessage);
      if (map == null) return;
      final status = map['status']?.toString();
      if (status == 'complete') {
        final results = map['results'];
        finishOk(results is List ? List<dynamic>.from(results) : <dynamic>[]);
        return;
      }
      if (status == 'cancelled') {
        finishOk([]);
        return;
      }
      if (status == 'failed') {
        final err = map['error']?.toString() ?? 'Неизвестная ошибка';
        final isRateLimit = map['rate_limit'] == true;
        finishError(Exception(isRateLimit ? 'rate_limit:$err' : err));
        return;
      }
      if (status != null && status != 'queued' && status != 'running') {
        finishError(Exception('Неизвестный статус задачи: $status'));
      }
    }

    Future<void> cleanup() async {
      await sub?.cancel();
      sub = null;
      try {
        await ch?.sink.close();
      } catch (_) {}
      ch = null;
    }

    final cableUri = await ApiClient.cableWebSocketUri(wsUrl);
    if (!cableUri.queryParameters.containsKey('token')) {
      finishError(Exception('Action Cable: не авторизован'));
      return completer.future;
    }
    ch = WebSocketChannel.connect(cableUri);
    sub = ch!.stream.listen(
      (dynamic frame) {
        if (completer.isCompleted) return;
        if (shouldAbort != null && shouldAbort()) {
          finishError(SyncPreviewAborted());
          unawaited(cleanup());
          return;
        }
        final decoded = ActionCableWire.decodeFrame(frame);
        if (decoded == null) return;
        if (decoded['type'] != null) {
          final t = decoded['type']?.toString();
          switch (t) {
            case 'welcome':
              if (!subscribed) {
                subscribed = true;
                ch!.sink.add(jsonEncode(<String, dynamic>{
                  'identifier': identifier,
                  'command': 'subscribe',
                }));
              }
              break;
            case 'ping':
              break;
            case 'confirm_subscription':
              break;
            case 'reject_subscription':
              finishError(Exception('Подписка на канал задачи отклонена'));
              break;
            case 'disconnect':
              if (!completer.isCompleted) {
                final reason = decoded['reason']?.toString();
                if (reason == 'unauthorized') {
                  finishError(Exception('Action Cable: не авторизован'));
                }
              }
              break;
            default:
              break;
          }
        } else if (decoded['identifier'] != null && decoded.containsKey('message')) {
          handleChannelMessage(decoded['message']);
        }
      },
      onError: (Object e, StackTrace _) {
        finishError(e);
        unawaited(cleanup());
      },
      onDone: () {
        if (!completer.isCompleted) {
          finishError(Exception('WebSocket закрыт до завершения задачи'));
        }
      },
      cancelOnError: false,
    );

    try {
      final out = await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('integration_sync_job socket >${timeout.inSeconds}s');
        },
      );
      return out;
    } on TimeoutException {
      rethrow;
    } finally {
      await cleanup();
    }
  }

  static Map<String, dynamic>? _normalizeMessage(dynamic message) {
    if (message is Map) {
      final m = Map<String, dynamic>.from(message);
      final inner = m['message'];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }
      return m;
    }
    return null;
  }
}
