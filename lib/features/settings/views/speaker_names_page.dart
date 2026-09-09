/// Purpose: Manage the speaker names offered when naming somebody in a
/// transcript.
/// Inputs: The synced settings library.
/// Returns: A settings sub-page.
/// Side effects: Writes the settings file, so the list syncs.
/// Notes: The same list the rename dialog offers as chips. It exists as a page
/// of its own because a list that only grows by being used is one nobody can
/// tidy: a name typed with a typo would be offered for ever. See
/// `doc/en-us/features/diarization-and-speakers.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/services/settings_repository.dart';

class SpeakerNamesPage extends ConsumerStatefulWidget {
  /// Purpose: Create the speaker names page.
  /// Inputs: None.
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const SpeakerNamesPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<SpeakerNamesPage> createState() => _SpeakerNamesPageState();
}

class _SpeakerNamesPageState extends ConsumerState<SpeakerNamesPage> {
  final _controller = TextEditingController();

  /// Purpose: Release the text field.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees the controller.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Purpose: Add whatever is typed to the list.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes the settings file and clears the field.
  /// Notes: Internal helper used within this file only. Through the repository,
  /// so the same deduplication and cap apply as when a name is remembered from
  /// a rename.
  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    _controller.clear();
    await ref.read(settingsRepositoryProvider).rememberSpeakerName(name);
    if (mounted) ref.refresh(settingsLibraryProvider);
  }

  /// Purpose: Stop offering one name.
  /// Inputs: The [name].
  /// Returns: None.
  /// Side effects: Writes the settings file.
  /// Notes: Internal helper used within this file only. Speakers already given
  /// the name keep it; only the suggestion goes.
  Future<void> _remove(String name) async {
    await ref.read(settingsRepositoryProvider).forgetSpeakerName(name);
    if (mounted) ref.refresh(settingsLibraryProvider);
  }

  /// Purpose: Build the page.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final names =
        ref.watch(settingsLibraryProvider).value?.defaults.knownSpeakerNames ??
        const <String>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSpeakerNames)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: l10n.settingsSpeakerNamesAdd,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l10n.settingsSpeakerNamesAdd,
                  icon: const Icon(Icons.add),
                  onPressed: _add,
                ),
              ],
            ),
          ),
          if (names.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.settingsSpeakerNamesEmpty,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          for (final name in names)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(name),
              trailing: IconButton(
                tooltip: l10n.viewerSpeakerForget,
                icon: const Icon(Icons.close),
                onPressed: () => _remove(name),
              ),
            ),
        ],
      ),
    );
  }
}
