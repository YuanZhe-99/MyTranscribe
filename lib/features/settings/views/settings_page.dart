/// Purpose: The settings tab — appearance, transcription defaults, data, and
/// what the app is.
/// Inputs: `appSettingsProvider` for the device-local preferences, and the
/// storage hub for everything written straight to `storage_config.json`.
/// Returns: A shell page; on a wide window it hosts its own detail pane.
/// Side effects: Writes preferences, and opens pages that perform network and
/// file I/O.
/// Notes: The list/detail split follows MyNihongo!!!!!'s settings page so the
/// two apps' settings behave the same way: on a wide window the sub-page is
/// hosted in a pane, on a narrow one it is pushed as a route, and the same
/// widget serves both.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../../../shared/services/import_export_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/platform_capabilities.dart';
import '../../media/widgets/media_tools_tile.dart';
import '../../../shared/views/webdav_config_page.dart';
import 'backup_page.dart';
import 'license_page.dart';
import 'privacy_policy_page.dart';

/// Which sub-page the detail pane is showing.
enum _SettingsDetail { webdav, backup, mediaTools, privacy, license }

class SettingsPage extends ConsumerStatefulWidget {
  /// Purpose: Create a settings page instance.
  /// Inputs: None.
  /// Returns: A new `SettingsPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const SettingsPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// The sub-page shown in the detail pane, or null for the empty state.
  ///
  /// Kept when the window narrows, so folding a device and unfolding it again
  /// comes back to the same sub-page.
  _SettingsDetail? _detail;

  /// Whether this build is currently rendering two panes.
  bool _twoPane = false;

  /// The app version, once `PackageInfo` has answered.
  String _version = '';

  /// Purpose: Start the asynchronous reads the page needs.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads the package info.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// Purpose: Read the app version for the About section.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads package info; sets state.
  /// Notes: Internal helper used within this file only. Never hand-written:
  /// `AGENTS.md` lists the version locations, and this display is not one of
  /// them because it reads `PackageInfo.fromPlatform()`.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {
      // Leave it blank; the rest of the page works without it.
    }
  }

  /// Purpose: Open a sub-page, in the detail pane or as a pushed route.
  /// Inputs: `detail`.
  /// Returns: None.
  /// Side effects: Sets state or pushes a route.
  /// Notes: Internal helper used within this file only. The pushed route uses
  /// the root navigator so the sub-page covers the navigation bar, which is
  /// what makes it feel like a page rather than a tab.
  void _open(_SettingsDetail detail) {
    if (_twoPane) {
      setState(() => _detail = detail);
      return;
    }
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => _detailPage(detail)));
  }

  /// Purpose: Build the widget for one sub-page.
  /// Inputs: `detail`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The same widget serves
  /// both the pushed route and the detail pane, so the two can never drift.
  Widget _detailPage(_SettingsDetail detail) => switch (detail) {
    _SettingsDetail.webdav => const WebDAVConfigPage(),
    _SettingsDetail.backup => const BackupPage(),
    _SettingsDetail.mediaTools => const MediaToolsPage(),
    _SettingsDetail.privacy => const PrivacyPolicyPage(),
    _SettingsDetail.license => const AppLicensePage(),
  };

  /// Purpose: Write the sources and models to a ZIP file the user chooses.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Opens a directory picker and writes a file.
  /// Notes: Internal helper used within this file only.
  Future<void> _exportZip() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    final path = await ImportExportService.exportZIP(dir);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(path ?? l10n.backupFailed)));
  }

  /// Purpose: Replace the sources and models from a ZIP file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Opens a file picker and overwrites the settings file.
  /// Notes: Internal helper used within this file only. Confirmed first: an
  /// import replaces what is there. The engine validates the whole archive
  /// before it writes anything, so a rejected file leaves the settings intact.
  Future<void> _importZip() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importData),
        content: Text(l10n.backupRestoreConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ImportExportService.importZIP(path);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.backupRestored : l10n.backupRestoreFailed),
      ),
    );
  }

  /// Purpose: Build the settings tab.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often. The gate
  /// reads the whole screen while the pane widths read the content box, which
  /// is the asymmetry `doc/en-us/adaptive-layout.md` explains.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    _twoPane = canSplitLayout(screen.width, screen.height);

    final list = _buildSettingsList(l10n);
    if (!_twoPane) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settingsTitle)),
        body: list,
      );
    }

    final contentWidth = shellContentWidth(screen.width);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Row(
        children: [
          SizedBox(width: settingsLeftPaneWidth(contentWidth), child: list),
          const VerticalDivider(width: 1),
          Expanded(child: _buildDetailPane(l10n)),
        ],
      ),
    );
  }

  /// Purpose: Build the detail pane beside the settings list.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The sub-page is hosted
  /// in a nested `Navigator` holding one route, which reports `canPop == false`
  /// so the hosted page's app bar grows no back arrow.
  Widget _buildDetailPane(AppLocalizations l10n) {
    final detail = _detail;
    if (detail == null) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsSelectItem,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Navigator(
      key: ValueKey(detail),
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => _detailPage(detail)),
    );
  }

  /// Purpose: Build the scrolling list of settings rows.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildSettingsList(AppLocalizations l10n) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return ListView(
      padding: EdgeInsets.only(
        bottom: shellListBottomInset(MediaQuery.sizeOf(context).width),
      ),
      children: [
        _section(l10n.settingsGeneral, [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settingsTheme),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto, size: 18),
                  label: Text(l10n.settingsThemeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode, size: 18),
                  label: Text(l10n.settingsThemeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode, size: 18),
                  label: Text(l10n.settingsThemeDark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => notifier.setThemeMode(s.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            trailing: DropdownButton<Locale?>(
              value: settings.locale,
              alignment: AlignmentDirectional.centerEnd,
              underline: const SizedBox.shrink(),
              onChanged: notifier.setLocale,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.settingsLanguageSystem),
                ),
                const DropdownMenuItem(
                  value: Locale('en'),
                  child: Text('English'),
                ),
                const DropdownMenuItem(
                  value: Locale('zh'),
                  child: Text('简体中文'),
                ),
                const DropdownMenuItem(
                  value: Locale('zh', 'TW'),
                  child: Text('繁體中文'),
                ),
              ],
            ),
          ),
        ]),
        _section(l10n.settingsTranscription, [
          if (usesExternalFfmpeg)
            MediaToolsTile(
              selected: _twoPane && _detail == _SettingsDetail.mediaTools,
              onTap: () => _open(_SettingsDetail.mediaTools),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.audiotrack_outlined),
            title: Text(l10n.settingsKeepChunks),
            subtitle: Text(l10n.settingsKeepChunksSubtitle),
            value: settings.keepChunkFiles,
            onChanged: notifier.setKeepChunkFiles,
          ),
        ]),
        _section(l10n.settingsData, [
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: Text(l10n.settingsWebDAVSync),
            subtitle: Text(l10n.settingsSyncSubtitle),
            trailing: const Icon(Icons.chevron_right),
            selected: _twoPane && _detail == _SettingsDetail.webdav,
            onTap: () => _open(_SettingsDetail.webdav),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.backupTitle),
            subtitle: Text(l10n.backupSubtitle),
            trailing: const Icon(Icons.chevron_right),
            selected: _twoPane && _detail == _SettingsDetail.backup,
            onTap: () => _open(_SettingsDetail.backup),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.exportData),
            subtitle: Text(l10n.settingsExportSubtitle),
            onTap: _exportZip,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.importData),
            subtitle: Text(l10n.settingsImportSubtitle),
            onTap: _importZip,
          ),
        ]),
        _section(l10n.settingsAbout, [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion),
            trailing: Text(_version),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsPrivacyPolicy),
            trailing: const Icon(Icons.chevron_right),
            selected: _twoPane && _detail == _SettingsDetail.privacy,
            onTap: () => _open(_SettingsDetail.privacy),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.settingsLicense),
            trailing: const Icon(Icons.chevron_right),
            selected: _twoPane && _detail == _SettingsDetail.license,
            onTap: () => _open(_SettingsDetail.license),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.settingsLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'MyTranscribe!!!!!',
              applicationVersion: _version,
            ),
          ),
        ]),
      ],
    );
  }

  /// Purpose: Render one titled group of rows.
  /// Inputs: `title`, `children`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _section(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
