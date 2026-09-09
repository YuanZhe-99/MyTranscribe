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

  /// Called to take one speaker's lines away from them entirely.
  final void Function(String speakerId) onUnassign;

  /// Names the user has given speakers before, offered as one-tap suggestions.
  final List<String> knownNames;

  /// Called with a name the user just used, so it can be remembered.
  final void Function(String name)? onNameUsed;

  /// Called with a suggestion the user dismissed, so it stops being offered.
  final void Function(String name)? onForgetName;

  /// Purpose: Create the speakers panel.
  /// Inputs: [transcript], [onRename], [onMerge], [onUnassign], and the
  /// [knownNames] with their [onNameUsed] and [onForgetName] callbacks.
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const SpeakersPanel({
    super.key,
    required this.transcript,
    required this.onRename,
    required this.onMerge,
    required this.onUnassign,
    this.knownNames = const [],
    this.onNameUsed,
    this.onForgetName,
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
              onSelected: (action) => switch (action) {
                'rename' => _rename(context, l10n, speaker),
                'merge' => _merge(context, l10n, speaker),
                _ => Future.sync(() => onUnassign(speaker.id)),
              },
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
                PopupMenuItem(
                  value: 'unassign',
                  // The other failure: a label that is not one person at all.
                  // Folding that into somebody who is one is worse than saying
                  // nobody knows.
                  child: Text(l10n.viewerSpeakerUnassign),
                ),
              ],
            ),
          ),
        if (transcript.unassignedCount > 0)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.person_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(l10n.viewerSpeakerUnknown),
            subtitle: Text(
              l10n.viewerSpeakerLines(transcript.unassignedCount),
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
  /// allowed and clears the name, which is how a wrong one is undone. A name
  /// the user has used before is one tap away, and is remembered when they type
  /// a new one: the same handful of people turn up in recording after
  /// recording, and retyping them each time is the sort of friction that makes
  /// a feature go unused.
  Future<void> _rename(
    BuildContext context,
    AppLocalizations l10n,
    Speaker speaker,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameSpeakerDialog(
        current: speaker.name ?? '',
        hint: _nameOf(speaker, l10n),
        suggestions: [
          for (final known in knownNames)
            if (known.toLowerCase() != (speaker.name ?? '').toLowerCase())
              known,
        ],
        onForget: onForgetName,
      ),
    );
    if (name == null) return;
    onRename(speaker.id, name);
    if (name.trim().isNotEmpty) onNameUsed?.call(name.trim());
  }

  /// Purpose: Ask which speaker to fold this one into.
  /// Inputs: `context`, [l10n] and the [speaker] being merged away.
  /// Returns: None.
  /// Side effects: Opens a dialog and calls [onMerge].
  /// Notes: Internal helper used within this file only. The speaker being
  /// merged away is the one the menu was opened on, so the list offered is
  /// everybody else — merging somebody into themselves is not a thing. The last
  /// option is nobody at all, because "these lines are not one person" is as
  /// common an answer as "these two are the same person", and asking it here
  /// is where the user is already looking.
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

    const unknown = '';
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
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(unknown),
            child: Text(l10n.viewerSpeakerUnknown),
          ),
        ],
      ),
    );
    if (into == null) return;
    into == unknown ? onUnassign(speaker.id) : onMerge(speaker.id, into);
  }
}

/// Asks for one speaker's name.
class _RenameSpeakerDialog extends StatefulWidget {
  /// The name the speaker has now, which may be empty.
  final String current;

  /// What to show when the field is empty — the numbered fallback.
  final String hint;

  /// Names the user has given speakers before.
  final List<String> suggestions;

  /// Called with a suggestion the user dismissed.
  final void Function(String name)? onForget;

  /// Purpose: Create the rename dialog.
  /// Inputs: [current], [hint], [suggestions], [onForget].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: A widget of its own rather than a bare [AlertDialog] built inline,
  /// because the text controller has to outlive the dialog's own closing
  /// animation: disposing it the moment `showDialog` returned threw "a
  /// TextEditingController was used after being disposed" on the very next
  /// frame.
  const _RenameSpeakerDialog({
    required this.current,
    required this.hint,
    this.suggestions = const [],
    this.onForget,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<_RenameSpeakerDialog> createState() => _RenameSpeakerDialogState();
}

class _RenameSpeakerDialogState extends State<_RenameSpeakerDialog> {
  late final _controller = TextEditingController(text: widget.current);

  /// The suggestions still on offer; dismissing one removes it from here too.
  late final _suggestions = [...widget.suggestions];

  /// Purpose: Release the text controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees the controller.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Purpose: Build the dialog.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: An empty name is allowed and clears the name, which is how a wrong
  /// one is undone.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.viewerSpeakerName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_suggestions.isNotEmpty) ...[
            Text(
              l10n.viewerSpeakerSuggestions,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final suggestion in _suggestions)
                  InputChip(
                    label: Text(suggestion),
                    // One tap is the whole point: picking a name you have used
                    // before should not also mean pressing Save.
                    onPressed: () => Navigator.of(context).pop(suggestion),
                    onDeleted: () {
                      setState(() => _suggestions.remove(suggestion));
                      widget.onForget?.call(suggestion);
                    },
                    deleteButtonTooltipMessage: l10n.viewerSpeakerForget,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
