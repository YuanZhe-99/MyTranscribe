/// Purpose: The Settings row that downloads or removes the speaker-labels
/// package (L8 of the local-models plan).
/// Inputs: The artifact manager and whether the package is installed.
/// Returns: A list tile.
/// Side effects: Downloads or removes the package when tapped.
/// Notes: The package belongs to no model — every local job that asks for
/// speakers uses it — so it lives in Settings › Local models rather than on a
/// model's page. See `doc/en-us/features/local-models.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/byte_format.dart';
import '../services/engine_registry.dart';
import '../services/local_model_templates.dart';

/// The speaker-labels row.
class SpeakerLabelsTile extends ConsumerStatefulWidget {
  /// Purpose: Create the row.
  /// Inputs: None.
  /// Returns: A new widget.
  /// Side effects: None.
  /// Notes: None.
  const SpeakerLabelsTile({super.key});

  /// Purpose: Create the row's state.
  /// Inputs: None.
  /// Returns: The state.
  /// Side effects: None.
  /// Notes: None.
  @override
  ConsumerState<SpeakerLabelsTile> createState() => _SpeakerLabelsTileState();
}

class _SpeakerLabelsTileState extends ConsumerState<SpeakerLabelsTile> {
  bool _busy = false;
  double? _progress;
  String? _error;

  /// Purpose: Ask before downloading, naming the size and the host.
  /// Inputs: None.
  /// Returns: Whether the user agreed.
  /// Side effects: Shows a dialog.
  /// Notes: The same confirmation a model's page asks; the app contacts the
  /// host only after it.
  Future<bool> _confirmDownload() async {
    final l10n = AppLocalizations.of(context)!;
    final hosts = {
      for (final file in speakerLabelsManifest.filesFor())
        Uri.parse(file.sourceUrl).host,
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.localModelDownloadTitle(l10n.settingsSpeakerLabels)),
        content: Text(
          l10n.localModelDownloadBody(
            formatBytes(speakerLabelsManifest.downloadBytesFor()),
            hosts.join(', '),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsSpeakerLabelsDownload),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Purpose: Download or remove the package.
  /// Inputs: Whether it is [installed] now.
  /// Returns: None.
  /// Side effects: Installs (after asking) or removes the files; refreshes
  /// the providers.
  /// Notes: A failure is shown on the row, not thrown.
  Future<void> _toggle(bool installed) async {
    if (!installed && !await _confirmDownload()) return;
    if (!mounted) return;
    final artifacts = ref.read(artifactManagerProvider);
    setState(() {
      _busy = true;
      _progress = null;
      _error = null;
    });
    try {
      if (installed) {
        await artifacts.remove(speakerLabelsManifest.artifactId);
      } else {
        await artifacts.install(
          speakerLabelsManifest,
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress.fraction);
          },
        );
      }
    } on Object catch (error) {
      _error = '$error';
    } finally {
      if (mounted) {
        ref.refresh(speakerLabelsInstalledProvider);
        setState(() => _busy = false);
      }
    }
  }

  /// Purpose: Build the row.
  /// Inputs: [context].
  /// Returns: A list tile.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final installed = ref.watch(speakerLabelsInstalledProvider).value ?? false;
    final megabytes = (speakerLabelsManifest.downloadBytesFor() / 1e6).round();
    return ListTile(
      leading: const Icon(Icons.record_voice_over_outlined),
      title: Text(l10n.settingsSpeakerLabels),
      subtitle: Text(
        _error ??
            (installed
                ? l10n.settingsSpeakerLabelsInstalled
                : l10n.settingsSpeakerLabelsSubtitle(megabytes)),
      ),
      trailing: _busy
          ? SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(value: _progress),
            )
          : TextButton(
              onPressed: () => _toggle(installed),
              child: Text(
                installed
                    ? l10n.settingsSpeakerLabelsRemove
                    : l10n.settingsSpeakerLabelsDownload,
              ),
            ),
    );
  }
}
