/// Purpose: Let the user pick a winner when sync finds the same thing edited on
/// two devices.
/// Inputs: One conflict, described by the merge that found it.
/// Returns: The chosen record, or null when the user backs out.
/// Side effects: Shows a modal dialog.
/// Notes: The dialog is not barrier-dismissible and has no cancel action:
/// resolution is all-or-nothing, and the caller treats a null (system back) as
/// "abort the whole sync", never as "keep local".
///
/// It renders a [SyncConflictView] rather than a record type, which is what let
/// transcriptions start syncing without a second dialog being written: each
/// module says how to describe its own records, and the chosen one comes back
/// opaque for the caller to hand to the right module.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../services/sync_merge.dart';

/// Shows both versions of one conflicting record side by side.
class SyncConflictDialog extends StatelessWidget {
  /// The conflict, as the merge described it.
  final SyncConflictView conflict;

  /// Purpose: Create a conflict dialog instance.
  /// Inputs: `conflict`.
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const SyncConflictDialog({super.key, required this.conflict});

  /// Purpose: Format a UTC timestamp in the device's zone.
  /// Inputs: `time`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Records store UTC; the
  /// user compares them in local time.
  static String _formatTime(DateTime time) =>
      DateFormat.yMd().add_Hms().format(time.toLocal());

  /// Purpose: Render one version's facts as a labelled block.
  /// Inputs: `context`, `heading`, `side`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Both blocks show the
  /// same fields in the same order, so the difference is easy to spot.
  Widget _version(BuildContext context, String heading, SyncConflictSide side) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '${l10n.syncModifiedAt}: ${_formatTime(side.modifiedAt)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          side.lines.isEmpty ? '—' : side.lines.join('\n'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Purpose: Build the conflict dialog.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.syncConflictTitle(conflict.displayName)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.syncConflictDesc),
            const SizedBox(height: 16),
            _version(context, l10n.syncLocalVersion, conflict.local),
            const Divider(height: 24),
            _version(context, l10n.syncRemoteVersion, conflict.remote),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(conflict.remote.record),
          child: Text(l10n.syncKeepRemote),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(conflict.local.record),
          child: Text(l10n.syncKeepLocal),
        ),
      ],
    );
  }
}

/// Purpose: Ask the user which version of one record to keep.
/// Inputs: `context`, `conflict`.
/// Returns: `Future<Object?>` — the chosen record, or null when the user backs
/// out.
/// Side effects: Shows a modal dialog.
/// Notes: Not barrier-dismissible: backing out aborts the whole sync, so it
/// must be a deliberate act rather than a stray tap outside the dialog. The
/// record comes back opaque; the caller knows from `conflict.moduleId` which
/// module to hand it to.
Future<Object?> showSyncConflictDialog(
  BuildContext context,
  SyncConflictView conflict,
) {
  return showDialog<Object>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => SyncConflictDialog(conflict: conflict),
  );
}
