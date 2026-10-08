import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapps_ai_online_ui/myapps_ai_online_ui.dart';
import 'package:myapps_ui/myapps_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../services/online_sources_controller.dart';
import '../services/settings_repository.dart';
import 'source_management_page.dart';

/// Shared online editor with application-owned records and model settings.
class OnlineSourcesPage extends ConsumerStatefulWidget {
  /// Purpose: Create source page. Inputs: None. Returns: Page.
  /// Side effects: None. Notes: Model capability editing stays application-owned.
  const OnlineSourcesPage({super.key});

  /// Purpose: Create state. Inputs: None. Returns: State.
  /// Side effects: None. Notes: Owns controller.
  @override
  ConsumerState<OnlineSourcesPage> createState() => _OnlineSourcesPageState();
}

class _OnlineSourcesPageState extends ConsumerState<OnlineSourcesPage> {
  TranscribeOnlineSources? _controller;
  Future<void>? _loading;

  /// Purpose: Initialize localized controller. Inputs: None. Returns: None.
  /// Side effects: Reads settings. Notes: Once per page lifetime.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = TranscribeOnlineSources(
      ref.read(settingsRepositoryProvider),
      AppLocalizations.of(context)!.onlinePrivacyBody(''),
      onSaved: () {
        if (mounted) ref.refresh(settingsLibraryProvider);
      },
    );
    _loading = _controller!.reload();
  }

  /// Purpose: Release controller. Inputs: None. Returns: None.
  /// Side effects: Removes listeners. Notes: Does not alter stored records.
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Purpose: Render shared source UI. Inputs: context. Returns: Page.
  /// Side effects: Explicit editor actions only. Notes: Injects MyApps-UI fields.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return MyAppsOnlineSourcesPage(
          title: l.libraryTitle,
          editorTitle: l.libraryName,
          controller: _controller!,
          labels: transcribeOnlineLabels(l),
          fields: MyAppsOnlineFieldBuilders(
            endpoint: (context, controller, error) => MyAppsEndpointField(
              controller: controller,
              label: l.libraryBaseUrl,
              invalidText: l.settingsWebDAVConnectionFailed,
              errorText: error,
            ),
            secret: (context, controller, hasKey, clear) => MyAppsSecretField(
              controller: controller,
              label: l.libraryApiKey,
              hasSavedValue: hasKey,
              onClear: clear,
              showTooltip: l.commonEdit,
              hideTooltip: l.commonClose,
              clearTooltip: l.libraryApiKeyClear,
            ),
            connectionTest: (context, state, message, test) =>
                MyAppsConnectionTestRow(
                  title: l.settingsWebDAVTestConnection,
                  testLabel: l.settingsWebDAVTestConnection,
                  status: MyAppsConnectionTestStatus.values.byName(state.name),
                  message: message,
                  onTest: test,
                ),
          ),
          header: ListTile(
            title: Text(l.onlineSourceModelSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SourceManagementPage(onlineOnly: true),
                ),
              );
              if (!mounted) return;
              await _controller!.reload();
              ref.refresh(settingsLibraryProvider);
            },
          ),
        );
      },
    );
  }
}

/// Purpose: Build shared online-source labels. Inputs: localizations.
/// Returns: Labels. Side effects: None. Notes: Also used by the privacy dialog.
MyAppsOnlineLabels transcribeOnlineLabels(
  AppLocalizations l,
) => MyAppsOnlineLabels(
  empty: l.libraryEmptyBody,
  add: l.libraryAddSource,
  templateName: (template) => template.name,
  status: (provider, gaps) =>
      gaps.isEmpty ? l.localStateReady : l.libraryApiKeyNote,
  remove: l.delete,
  removeTitle: (_) => l.delete,
  removeBody: l.onlineSourceRemoveNotice,
  removeConfirm: l.delete,
  cancel: l.cancel,
  name: l.libraryName,
  model: l.libraryTitle,
  save: l.save,
  saveFailed: l.settingsWebDAVConnectionFailed,
  invalidEndpoint: l.settingsWebDAVConnectionFailed,
  testResult: (report) => report.status.name == 'available'
      ? l.localStateReady
      : l.settingsWebDAVConnectionFailed,
  privacyTitle: l.onlinePrivacyTitle,
  privacyIntro: (host, _) => host,
  dataItem: (item) => item.description ?? '',
  keySync: (_) => l.webdavPrivacySecrets,
  onlyWhenSelected: l.onlinePrivacySelectedOnly,
  privacyConfirm: l.webdavPrivacyConfirm,
  addSourceTitle: l.aiOnlineAddTitle,
  searchHint: l.aiOnlineSearch,
  endpointLabel: l.aiOnlineEndpointChoice,
  customEndpoint: l.aiOnlineCustomEndpoint,
  docs: l.aiOnlineDocs,
  models: l.aiOnlineModels,
  noModels: l.aiOnlineNoModels,
  fetchModels: l.aiOnlineFetchModels,
  fetchFailed: l.aiOnlineFetchFailed,
  fromCatalog: l.aiOnlineFromCatalog,
  addModelId: l.aiOnlineAddModelId,
  modelIdHint: l.aiOnlineModelIdHint,
  alias: l.aiOnlineAlias,
  aliasHint: l.aiOnlineAliasHint,
  originalId: l.aiOnlineOriginalId,
  showAllModels: l.aiOnlineShowAll,
  contextTokens: (tokens) => l.aiOnlineContext(
    tokens >= 1000000
        ? '${(tokens / 1000000).toStringAsFixed(tokens % 1000000 == 0 ? 0 : 1)}M'
        : '${(tokens / 1000).round()}K',
  ),
  selectModels: l.aiOnlineSelectModels,
  done: l.aiOnlineDone,
  removeModel: l.aiOnlineRemoveModel,
  localServer: l.aiOnlineLocalServer,
);
