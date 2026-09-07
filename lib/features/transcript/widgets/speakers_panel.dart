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

  /// Called to fold one speaker into another, `from` into `into`.
  final void Function(String from, String into) onMerge;

  /// Purpose: Create the speakers panel.
  /// Inputs: [transcript], [onRename], [onMerge].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const SpeakersPanel({
    super.key,
    required this.transcript,
    required this.onRename,
    required this.onMerge,
  });

  /// Purpose: Say what to call one speaker.
  /// Inputs: The [speaker] and the [l10n].
  /// Returns: Their name, or the numbered fallback.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Goes through the
  /// transcript so an unnamed speaker is numbered by position rather than by
  /// their id, which can have gaps — see [Transcript.displayNameOf]. The id is
  /// the last resort and cannot be reached from this panel, whose speakers all
  /// come from the transcript.
  String _nameOf(Speaker speaker, AppLocalizations l10n) =>
      transcript.displayNameOf(speaker.id, l10n.viewerSpeakerFallback) ??
      speaker.id;

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
                _nameOf(speaker, l10n).characters.first,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(_nameOf(speaker, l10n)),
            subtitle: Text(l10n.viewerSpeakerLines(counts[speaker.id] ?? 0)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => action == 'rename'
                  ? _rename(context, l10n, speaker)
                  : _merge(context, l10n, speaker),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text(l10n.viewerSpeakerRename),
                ),
                PopupMenuItem(
                  value: 'merge',
                  // The matching refuses a doubtful join rather than guessing,
                  // so one person coming back as two is the expected way for it
                  // to be wrong. This is the fix, and it takes one tap.
                  enabled: transcript.speakers.length > 1,
                  child: Text(l10n.viewerSpeakerMerge),
                ),
              ],
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
          decoration: InputDecoration(hintText: _nameOf(speaker, l10n)),
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

  /// Purpose: Ask which speaker to fold this one into.
  /// Inputs: `context`, [l10n] and the [speaker] being merged away.
  /// Returns: None.
  /// Side effects: Opens a dialog and calls [onMerge].
  /// Notes: Internal helper used within this file only. The speaker being
  /// merged away is the one the menu was opened on, so the list offered is
  /// everybody else — merging somebody into themselves is not a thing.
  Future<void> _merge(
    BuildContext context,
    AppLocalizations l10n,
    Speaker speaker,
  ) async {
    final others = [
      for (final other in transcript.speakers)
        if (other.id != speaker.id) other,
    ];
    if (others.isEmpty) return;

    final into = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.viewerSpeakerMergeTitle(_nameOf(speaker, l10n))),
        children: [
          for (final other in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(other.id),
              child: Text(_nameOf(other, l10n)),
            ),
        ],
      ),
    );
    if (into != null) onMerge(speaker.id, into);
  }
}
