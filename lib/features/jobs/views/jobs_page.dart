import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// The transcribe tab: every recording the app has transcribed, newest first.
///
/// M0 renders the empty state only. The list, the two-pane detail and the
/// running-job progress arrive with the job runner; the layout rules they will
/// use (`useJobsTwoPane`, `jobsListPaneWidth`, `jobTileMinWidth`) already live
/// in `adaptive_layout.dart`, so this page never grows a breakpoint of its own.
class JobsPage extends StatelessWidget {
  /// Purpose: Create a jobs page instance.
  /// Inputs: None.
  /// Returns: A new `JobsPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const JobsPage({super.key});

  /// Purpose: Build the transcribe tab.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.jobsTitle)),
      body: EmptyState(
        icon: Icons.graphic_eq_outlined,
        title: l10n.jobsEmptyTitle,
        body: l10n.jobsEmptyBody,
      ),
      floatingActionButton: FloatingActionButton.extended(
        // The new-job route arrives with the job runner. Until then there is
        // nothing honest for this to do, and a button that silently does
        // nothing is worse than one that shows it cannot yet.
        onPressed: null,
        icon: const Icon(Icons.add),
        label: Text(l10n.jobsNew),
      ),
    );
  }
}
