/// Прерывание ожидания синхронизации (пользователь нажал «Стоп»).
class SyncPreviewAborted implements Exception {
  @override
  String toString() => 'sync_aborted';
}
