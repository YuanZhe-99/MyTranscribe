# lib/shared/services/auto_sync_service.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `library;` | MyTranscribe's auto-sync trigger service, a facade over the shared |
| `AutoSyncService._();` | Prevent direct instantiation and expose only the singleton. |
| `DateTime? get lastSuccessAt => _scheduler.lastSuccessAt;` | Return the last successful sync time recorded by this service. |
| `DateTime? get lastFailureAt => _scheduler.lastFailureAt;` | Return the last failed sync time recorded by this service. |
| `String? get lastError => _scheduler.lastError;` | Return the most recent sync failure message. |
| `bool get hasPendingConflicts => _scheduler.hasPendingConflicts;` | Return whether auto-sync found conflicts needing manual resolution. |
| `void addOnLocalDataChanged(void Function() cb) =>` | Register a callback invoked when auto-sync updates local data. |
| `void removeOnLocalDataChanged(void Function() cb) =>` | Remove a previously registered callback. |
| `void addOnStatusChanged(VoidCallback cb) => _scheduler.addOnStatusChanged(cb);` | Register a callback invoked when sync status changes. |
| `void removeOnStatusChanged(VoidCallback cb) =>` | Remove a previously registered sync-status callback. |
| `void recordSyncResult(SyncResult result) => _scheduler.recordSyncResult(` | Record a sync result triggered outside the auto-sync loop. |
| `void notifyLocalDataChangedIfNeeded() =>` | Notify UI reload listeners after a manual sync or force |
| `void notifyLocalDataChangedNow() => _scheduler.notifyLocalDataChangedNow();` | Notify UI reload listeners unconditionally after local data |
| `void recordFinalizeResult(bool ok) => _scheduler.recordFinalizeResult(ok);` | Record a conflict-finalization result. |
| `void start() => _scheduler.start();` | Begin observing the app lifecycle and start the sync timers. |
| `void stop() => _scheduler.stop();` | Stop the timers and stop observing the app lifecycle. |
| `void notifySaved() => _scheduler.notifySaved();` | Called by storage save methods to schedule a debounced sync. |
| `void requestSyncNow() => _scheduler.requestSyncNow();` | Trigger a sync as soon as possible without waiting for the |
