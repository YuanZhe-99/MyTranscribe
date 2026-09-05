/// Purpose: Configure the user's WebDAV server and run syncs by hand.
/// Inputs: The stored `webdav_config.json` through `WebDAVService`, the
/// content catalog for conflict labels.
/// Returns: A full-screen page; hosted in the settings detail pane on a wide
/// window.
/// Side effects: Reads and writes the WebDAV configuration, performs network
/// requests, holds the sync wake lock while a request runs.
/// Notes: Ported from MyAnime!!!!!'s page of the same name so the two apps'
/// sync UI behaves identically. The password is stored in plain text in the
/// app directory, as in the sibling apps; that is stated in the privacy policy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapps_data/myapps_data.dart'
    show SyncPhase, SyncProgress, SyncWakeLock, WebDAVConfig;

import '../../app/data_modules.dart';

import '../../features/providers/models/transcribe_settings.dart';
import '../../l10n/app_localizations.dart';
import '../services/auto_sync_service.dart';
import '../services/webdav_service.dart';
import '../widgets/settings_conflict_dialog.dart';

class WebDAVConfigPage extends ConsumerStatefulWidget {
  /// Purpose: Create a WebDAV config page instance.
  /// Inputs: None.
  /// Returns: A new `WebDAVConfigPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const WebDAVConfigPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<WebDAVConfigPage> createState() => _WebDAVConfigPageState();
}

class _WebDAVConfigPageState extends ConsumerState<WebDAVConfigPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _pathController = TextEditingController(
    text: transcribeDefaultRemotePath,
  );
  bool _loading = true;
  bool _testing = false;
  bool _syncing = false;
  bool _isConfigured = false;
  bool _autoSync = false;

  /// Purpose: Subscribe to sync status and start the configuration read.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers a service listener; reads the stored config.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnStatusChanged(_refreshSyncStatus);
    _loadConfig();
  }

  /// Purpose: Refresh this page when background sync status changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _refreshSyncStatus() {
    if (mounted) setState(() {});
  }

  /// Purpose: Fill the form from the stored configuration.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads local storage; rebuilds.
  /// Notes: Internal helper used within this file only. An absent config
  /// leaves the default remote path in place.
  Future<void> _loadConfig() async {
    final config = await WebDAVService.loadConfig();
    if (config != null) {
      _urlController.text = config.serverUrl;
      _userController.text = config.username;
      _passController.text = config.password;
      _pathController.text = config.remotePath;
      _isConfigured = config.isConfigured;
      _autoSync = config.autoSync;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Purpose: Release listeners and controllers.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes owned resources.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    AutoSyncService.instance.removeOnStatusChanged(_refreshSyncStatus);
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  /// Purpose: Build a config from what the form currently holds.
  /// Inputs: The four controllers and `_autoSync`.
  /// Returns: `WebDAVConfig`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Every field is
  /// trimmed, because a trailing space in a URL breaks path joining.
  WebDAVConfig get _currentConfig => WebDAVConfig(
    serverUrl: _urlController.text.trim(),
    username: _userController.text.trim(),
    password: _passController.text.trim(),
    remotePath: _pathController.text.trim(),
    autoSync: _autoSync,
  );

  /// Purpose: Persist the form and start a sync when auto-sync is on.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes `webdav_config.json`; may request a sync.
  /// Notes: Internal helper used within this file only.
  Future<void> _saveConfig() async {
    final config = _currentConfig;
    await WebDAVService.saveConfig(config);
    if (config.isConfigured && config.autoSync) {
      AutoSyncService.instance.requestSyncNow();
    }
    setState(() => _isConfigured = config.isConfigured);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsWebDAVConfigSaved,
          ),
        ),
      );
    }
  }

  /// Purpose: Check that the server answers with these credentials.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Performs a network request; shows a snackbar.
  /// Notes: Internal helper used within this file only.
  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final ok = await WebDAVService.testConnection(_currentConfig);
    if (mounted) {
      setState(() => _testing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.settingsWebDAVConnectionSuccess
                : AppLocalizations.of(context)!.settingsWebDAVConnectionFailed,
          ),
        ),
      );
    }
  }

  /// Purpose: Run a two-way sync now.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Network and file I/O; holds the sync wake lock; may open
  /// the conflict dialogs.
  /// Notes: Internal helper used within this file only. The wake lock and the
  /// `_syncing` busy flag are both reset in `finally` so a thrown request
  /// cannot leak them.
  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    await SyncWakeLock.acquire();
    SyncResult result;
    try {
      result = await WebDAVService.sync(_currentConfig);
    } finally {
      await SyncWakeLock.release();
      if (mounted) setState(() => _syncing = false);
    }
    if (!mounted) return;
    AutoSyncService.instance.recordSyncResult(result);
    AutoSyncService.instance.notifyLocalDataChangedIfNeeded();

    if (result.hasConflicts) {
      await _resolveConflicts(result);
      return;
    }

    await _showSyncResult(result);
  }

  /// Purpose: Present a non-conflict sync or force result to the user.
  /// Inputs: `result`.
  /// Returns: None.
  /// Side effects: Shows a dialog for failures and warnings, a snackbar for a
  /// clean success.
  /// Notes: Internal helper used within this file only.
  Future<void> _showSyncResult(SyncResult result) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (!result.success) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsWebDAVSyncFailed),
          content: SingleChildScrollView(
            child: SelectableText(result.error ?? '-'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    if (result.warnings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsWebDAVSyncSuccess),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.settingsWebDAVSyncWarnings(result.warnings.length)),
                const SizedBox(height: 8),
                ...result.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(w, style: Theme.of(ctx).textTheme.bodySmall),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsWebDAVSyncSuccess)));
  }

  /// Purpose: Confirm and run a force upload (local overwrites remote).
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Overwrites remote data after confirmation; holds the wake
  /// lock while the upload runs.
  /// Notes: Internal helper used within this file only.
  Future<void> _forceUpload() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmForceAction(
      title: l10n.settingsWebDAVForceUploadConfirmTitle,
      body: l10n.settingsWebDAVForceUploadConfirmBody,
      confirmLabel: l10n.settingsWebDAVForceUpload,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _syncing = true);
    await SyncWakeLock.acquire();
    SyncResult result;
    try {
      result = await WebDAVService.forceUpload(_currentConfig);
    } finally {
      await SyncWakeLock.release();
      if (mounted) setState(() => _syncing = false);
    }
    if (!mounted) return;
    AutoSyncService.instance.recordSyncResult(result);
    AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
    await _showSyncResult(result);
  }

  /// Purpose: Confirm and run a force download (remote overwrites local).
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Overwrites local data after confirmation; holds the wake
  /// lock while the download runs.
  /// Notes: Internal helper used within this file only.
  Future<void> _forceDownload() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmForceAction(
      title: l10n.settingsWebDAVForceDownloadConfirmTitle,
      body: l10n.settingsWebDAVForceDownloadConfirmBody,
      confirmLabel: l10n.settingsWebDAVForceDownload,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _syncing = true);
    await SyncWakeLock.acquire();
    SyncResult result;
    try {
      result = await WebDAVService.forceDownload(_currentConfig);
    } finally {
      await SyncWakeLock.release();
      if (mounted) setState(() => _syncing = false);
    }
    if (!mounted) return;
    AutoSyncService.instance.recordSyncResult(result);
    AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
    await _showSyncResult(result);
  }

  /// Purpose: Ask the user to confirm a destructive force upload or download.
  /// Inputs: `title`, `body`, `confirmLabel`.
  /// Returns: `Future<bool?>` — true when confirmed.
  /// Side effects: Opens a modal dialog.
  /// Notes: Internal helper used within this file only.
  Future<bool?> _confirmForceAction({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Purpose: Map a sync progress snapshot to a localized status line.
  /// Inputs: `l10n`, `progress`.
  /// Returns: `String`; empty when nothing is running.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The shared engine's
  /// image phases cannot occur here — study records carry no images — but the
  /// switch stays exhaustive, so they fall through to the data-phase strings
  /// rather than to an unreachable branch that a package update could reach.
  String _progressText(AppLocalizations l10n, SyncProgress progress) {
    switch (progress.phase) {
      case SyncPhase.connecting:
        return l10n.syncPhaseConnecting;
      case SyncPhase.downloadingData:
      case SyncPhase.downloadingImages:
        return l10n.syncPhaseDownloadingData(
          progress.detail ?? '',
          progress.current,
          progress.total,
        );
      case SyncPhase.merging:
        return l10n.syncPhaseMerging(progress.detail ?? '');
      case SyncPhase.uploadingData:
      case SyncPhase.uploadingImages:
        return l10n.syncPhaseUploadingData(progress.detail ?? '');
      case SyncPhase.idle:
      case SyncPhase.done:
      case SyncPhase.error:
        return '';
    }
  }

  /// Purpose: Ask the user to resolve each pending conflict, then upload.
  /// Inputs: `result` — the conflicting sync result carrying the pending merge.
  /// Returns: None.
  /// Side effects: Shows one dialog per conflict; on full resolution finalizes
  /// the sync under the wake lock and records the outcome.
  /// Notes: Internal helper used within this file only. Dismissing any dialog
  /// aborts the whole resolution: nothing is uploaded, the conflict stays
  /// pending in the visible status, and no record is silently kept.
  Future<void> _resolveConflicts(SyncResult result) async {
    final pending = result.pending!;
    final resolutions = <String, SettingsRecord>{};

    for (final conflict in pending.allConflicts) {
      if (!mounted) return;
      final chosen = await showSettingsConflictDialog(context, conflict);
      if (chosen == null) {
        // User backed out — abort without uploading; conflict stays pending.
        AutoSyncService.instance.recordSyncResult(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.settingsWebDAVSyncFailed,
              ),
            ),
          );
        }
        return;
      }
      resolutions[conflict.id] = chosen;
    }

    await SyncWakeLock.acquire();
    bool ok;
    try {
      ok = await WebDAVService.finalizePendingSync(
        _currentConfig,
        pending,
        resolutions,
      );
    } finally {
      await SyncWakeLock.release();
    }
    AutoSyncService.instance.recordFinalizeResult(ok);
    AutoSyncService.instance.notifyLocalDataChangedIfNeeded();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.settingsWebDAVSyncSuccess
                : AppLocalizations.of(context)!.settingsWebDAVSyncFailed,
          ),
        ),
      );
    }
  }

  /// Purpose: Forget the stored server and clear the form.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Deletes `webdav_config.json`.
  /// Notes: Internal helper used within this file only. Local progress is left
  /// alone; only the connection is dropped.
  Future<void> _disconnect() async {
    await WebDAVService.deleteConfig();
    _urlController.clear();
    _userController.clear();
    _passController.clear();
    _pathController.text = transcribeDefaultRemotePath;
    setState(() {
      _isConfigured = false;
      _autoSync = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsWebDAVConfigRemoved,
          ),
        ),
      );
    }
  }

  /// Purpose: Prefill the form with Nextcloud's URL shape.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Rebuilds with the placeholder values.
  /// Notes: Internal helper used within this file only.
  void _fillNextcloud() {
    _urlController.text =
        'https://your-nextcloud-host/remote.php/dav/files/USERNAME';
    _pathController.text = transcribeDefaultRemotePath;
    setState(() {});
  }

  /// Purpose: Build a short sync health summary for display.
  /// Inputs: `l10n`.
  /// Returns: `String?` — null when there is nothing to report yet.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String? _syncStatusText(AppLocalizations l10n) {
    final service = AutoSyncService.instance;
    if (service.lastError != null) {
      return service.hasPendingConflicts
          ? '${l10n.settingsWebDAVAutoSyncConflict}: ${service.lastError}'
          : '${l10n.settingsWebDAVAutoSyncFailed}: ${service.lastError}';
    }
    if (service.lastSuccessAt != null) {
      return '${l10n.settingsWebDAVLastSuccess}: ${service.lastSuccessAt!.toLocal()}';
    }
    return null;
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often. The page
  /// is a single column at every size; the settings page decides whether it is
  /// pushed or hosted in a pane.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final syncStatus = _syncStatusText(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsWebDAVSync), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fillNextcloud,
                      icon: const Icon(Icons.cloud, size: 18),
                      label: Text(l10n.settingsWebDAVNextcloud),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVServerURL,
                    hintText: 'https://example.com/remote.php/dav/files/user',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVUsername,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVPassword,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVRemotePath,
                    hintText: transcribeDefaultRemotePath,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveConfig,
                        child: Text(l10n.save),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.settingsWebDAVTestConnection),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isConfigured) ...[
                  if (syncStatus != null) ...[
                    Card(
                      color: AutoSyncService.instance.lastError == null
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          syncStatus,
                          style: TextStyle(
                            color: AutoSyncService.instance.lastError == null
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ValueListenableBuilder<SyncProgress>(
                    valueListenable: WebDAVService.progress,
                    builder: (context, progress, _) {
                      if (!progress.isRunning) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(value: progress.fraction),
                          const SizedBox(height: 8),
                          Text(
                            _progressText(l10n, progress),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                  FilledButton.icon(
                    onPressed: _syncing ? null : () => _syncNow(),
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      _syncing
                          ? l10n.settingsWebDAVSyncing
                          : l10n.settingsWebDAVSyncNow,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _syncing ? null : _forceUpload,
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(l10n.settingsWebDAVForceUpload),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _syncing ? null : _forceDownload,
                          icon: const Icon(Icons.download, size: 18),
                          label: Text(l10n.settingsWebDAVForceDownload),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsWebDAVAutoSync),
                    subtitle: Text(l10n.settingsWebDAVAutoSyncDesc),
                    value: _autoSync,
                    onChanged: (v) {
                      setState(() => _autoSync = v);
                      _saveConfig();
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.link_off),
                    label: Text(l10n.settingsWebDAVDisconnect),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
