/// Purpose: Show who speaks in a recording, and let them be named.
/// Inputs: The transcript, and a callback for a rename.
/// Returns: A panel, used both in the sidebar and in a sheet.
/// Side effects: None; the caller saves.
/// Notes: Naming is the whole point. A transcript that says "Speaker 1" and
/// "Speaker 2" is much harder to read a week later than one that says who was
/// talking, and the name is a property of the speaker record, so one edit
/// renames every line at once. Merging and splitting arrive with the
/// cross-window matching in M5.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/transcript.dart';
import '../services/speaker_palette.dart';

class SpeakersPanel extends StatelessWidget {
  /// The transcript whose speakers these are.
  final Transcript transcript;

  /// Called with the speaker's id and their new name.
  final void Function(String speakerId, String name) onRename;

  /// Purpose: Create the speakers panel.
  /// Inputs: [transcript], [onRename].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const SpeakersPanel({
    super.key,
    required this.transcript,
    required this.onRename,
  });

  /// Purpose: Build the panel.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: Each row says how many lines the speaker has, which is how you tell
  /// the lecturer from somebody who asked one question.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final counts = <String, int>{};
    for (final segment in transcript.segments) {
      if (segment.speakerId case final id?) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.viewerSpeakers, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final speaker in transcript.speakers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: speakerColor(
                speaker.colorIndex,
                theme.brightness,
              ),
              child: Text(
                speaker
                    .displayName(l10n.viewerSpeakerFallback)
                    .characters
                    .first,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(speaker.displayName(l10n.viewerSpeakerFallback)),
            subtitle: Text(l10n.viewerSpeakerLines(counts[speaker.id] ?? 0)),
            trailing: IconButton(
              tooltip: l10n.viewerSpeakerName,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _rename(context, l10n, speaker),
            ),
          ),
      ],
    );
  }

  /// Purpose: Ask for a speaker's name.
  /// Inputs: `context`, [l10n] and the [speaker].
  /// Returns: None.
  /// Side effects: Opens a dialog and calls [onRename].
  /// Notes: Internal helper used within this file only. An empty name is
  /// allowed and clears the name, which is how a wrong one is undone.
  Future<void> _rename(
    BuildContext context,
    AppLocalizations l10n,
    Speaker speaker,
  ) async {
    final controller = TextEditingController(text: speaker.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.viewerSpeakerName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: speaker.displayName(l10n.viewerSpeakerFallback),
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) onRename(speaker.id, name);
  }
}
