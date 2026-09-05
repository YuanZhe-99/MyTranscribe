/// Purpose: The Settings row that says whether the app can split a long
/// recording, and sets it up when it cannot.
/// Inputs: `mediaToolkitStatusProvider`, and the user's choices.
/// Returns: A `ListTile` for the settings list, and its detail page.
/// Side effects: Downloads FFmpeg, writes tool paths, refreshes the status.
/// Returns nothing to the caller beyond the widget.
/// Notes: Shown only where the app uses external executables. On a platform
/// with the libraries built in there is nothing to set up and nothing to
/// choose, so the row would be a question the user cannot act on.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/transcribe_storage.dart';
import '../services/ffmpeg_downloader.dart';
import '../services/media_toolkit.dart';
import '../services/media_toolkit_provider.dart';

/// A settings row showing whether audio tools are ready.
class MediaToolsTile extends ConsumerWidget {
  /// Whether this row is the selected one in a two-pane settings layout.
  final bool selected;

  /// Opens the detail page.
  final VoidCallback onTap;

  /// Purpose: Create the media tools row.
  /// Inputs: [selected], [onTap].
  /// Returns: A new widget.
  /// Side effects: None.
  /// Notes: None.
  const MediaToolsTile({
    super.key,
    required this.selected,
    required this.onTap,
  });

  /// Purpose: Build the row.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the toolkit status.
  /// Notes: While the status is loading the row shows its title and no
  /// subtitle, rather than a spinner: the check is fast, and a row that
  /// changes height as it settles makes the whole list jump.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final status = ref.watch(mediaToolkitStatusProvider);
    final ready = status.value?.available ?? false;

    return ListTile(
      leading: Icon(
        ready ? Icons.check_circle_outline : Icons.build_outlined,
        color: ready ? null : Theme.of(context).colorScheme.error,
      ),
      title: Text(l10n.settingsMediaTools),
      subtitle: status.value != null
          ? Text(
              ready
                  ? l10n.settingsMediaToolsSubtitleReady
                  : l10n.settingsMediaToolsSubtitleMissing,
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      selected: selected,
      onTap: onTap,
    );
  }
}

/// The detail page for setting up audio tools.
class MediaToolsPage extends ConsumerStatefulWidget {
  /// Purpose: Create the media tools page.
  /// Inputs: None.
  /// Returns: A new widget.
  /// Side effects: None.
  /// Notes: None.
  const MediaToolsPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<MediaToolsPage> createState() => _MediaToolsPageState();
}

class _MediaToolsPageState extends ConsumerState<MediaToolsPage> {
  /// The download in progress, or null when none is running.
  FfmpegDownloadProgress? _progress;

  /// Purpose: Download a published FFmpeg build.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Network I/O, writes into the app support directory, and
  /// refreshes the toolkit status.
  /// Notes: Internal helper used within this file only. The plan is shown to
  /// the user before anything is fetched — downloading a binary from the
  /// internet is not something to start without saying what, and from where.
  Future<void> _download() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final directory = await ffmpegDownloadDirectory();
    final downloader = FfmpegDownloader(destination: directory);

    final FfmpegDownloadPlan plan;
    try {
      plan = downloader.plan();
    } on MediaException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsMediaToolsDownload),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsMediaToolsExplain),
            const SizedBox(height: 12),
            SelectableText(
              plan.url,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settingsMediaToolsDownload),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(
      () => _progress = const FfmpegDownloadProgress(
        stage: FfmpegDownloadStage.downloading,
      ),
    );
    try {
      await downloader.download(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      ref.refresh(mediaToolkitProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsMediaToolsDownloaded)),
      );
    } on MediaException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.settingsMediaToolsDownloadFailed}: ${error.message}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  /// Purpose: Let the user point at a build they already have.
  /// Inputs: [tool] — `ffmpeg` or `ffprobe`.
  /// Returns: None.
  /// Side effects: Opens a file picker, writes the path, refreshes the status.
  /// Notes: Internal helper used within this file only.
  Future<void> _choose(String tool) async {
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null) return;
    if (tool == 'ffmpeg') {
      await TranscribeStorage.setFfmpegPath(path);
    } else {
      await TranscribeStorage.setFfprobePath(path);
    }
    ref.refresh(mediaToolkitProvider);
  }

  /// Purpose: Forget the paths the user set and search again.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Clears both stored paths and refreshes the status.
  /// Notes: Internal helper used within this file only.
  Future<void> _clear() async {
    await TranscribeStorage.setFfmpegPath(null);
    await TranscribeStorage.setFfprobePath(null);
    ref.refresh(mediaToolkitProvider);
  }

  /// Purpose: Build the media tools page.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the toolkit status.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final status = ref.watch(mediaToolkitStatusProvider);
    final downloading = _progress != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsMediaTools)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              l10n.settingsMediaToolsExplain,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          status.when(
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text(''),
            ),
            error: (error, _) => ListTile(
              leading: Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(l10n.settingsMediaToolsMissing),
              subtitle: SelectableText('$error'),
            ),
            data: (value) => Column(
              children: [
                ListTile(
                  leading: Icon(
                    value.available
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: value.available ? null : theme.colorScheme.error,
                  ),
                  title: Text(
                    value.available
                        ? l10n.settingsMediaToolsReady
                        : l10n.settingsMediaToolsMissing,
                  ),
                  subtitle: SelectableText(value.detail),
                ),
                if (value.ffmpegPath case final path?)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.terminal_outlined),
                    title: const Text('ffmpeg'),
                    subtitle: SelectableText(path),
                  ),
                if (value.ffprobePath case final path?)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.terminal_outlined),
                    title: const Text('ffprobe'),
                    subtitle: SelectableText(path),
                  ),
              ],
            ),
          ),
          if (downloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsMediaToolsDownloading,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _progress?.fraction),
                ],
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.settingsMediaToolsDownload),
            enabled: !downloading,
            onTap: downloading ? null : _download,
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text('${l10n.settingsMediaToolsChoose} (ffmpeg)'),
            enabled: !downloading,
            onTap: downloading ? null : () => _choose('ffmpeg'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text('${l10n.settingsMediaToolsChoose} (ffprobe)'),
            enabled: !downloading,
            onTap: downloading ? null : () => _choose('ffprobe'),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.settingsMediaToolsClear),
            enabled: !downloading,
            onTap: downloading ? null : _clear,
          ),
        ],
      ),
    );
  }
}
