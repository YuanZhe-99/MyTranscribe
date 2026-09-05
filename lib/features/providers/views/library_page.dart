import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// The library tab: the transcription services the app can use, and the models
/// each one offers.
///
/// M0 renders the empty state only. The grouped list, the two-pane editor and
/// the built-in templates arrive with the library repository; the layout rules
/// they will use (`useLibraryTwoPane`, `libraryListPaneWidth`) already live in
/// `adaptive_layout.dart`.
class LibraryPage extends StatelessWidget {
  /// Purpose: Create a library page instance.
  /// Inputs: None.
  /// Returns: A new `LibraryPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const LibraryPage({super.key});

  /// Purpose: Build the library tab.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTitle)),
      body: EmptyState(
        icon: Icons.library_books_outlined,
        title: l10n.libraryEmptyTitle,
        body: l10n.libraryEmptyBody,
      ),
    );
  }
}
