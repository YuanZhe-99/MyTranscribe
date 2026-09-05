/// Purpose: Let the user pick a winner when sync finds one source, model or
/// defaults record edited on two devices.
/// Inputs: The conflicting record pair from the merge.
/// Returns: The chosen `SettingsRecord`, or null when the user backs out.
/// Side effects: Shows a modal dialog.
/// Notes: The dialog is not barrier-dismissible and has no cancel action:
/// resolution is all-or-nothing, and the caller treats a null (system back) as
/// "abort the whole sync", never as "keep local".
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/providers/models/transcribe_settings.dart';
import '../../l10n/app_localizations.dart';
import '../services/sync_merge.dart';

/// Shows both versions of one conflicting settings record side by side.
class SettingsConflictDialog extends StatelessWidget {
  /// The conflicting pair, as the merge reported it.
  final RecordConflict<SettingsRecord> conflict;

  /// Purpose: Create a settings conflict dialog instance.
  /// Inputs: `conflict`.
  /// Returns: A new `SettingsConflictDialog` instance.
  /// Side effects: None.
  /// Notes: None.
  const SettingsConflictDialog({super.key, required this.conflict});

  /// Purpose: Format a UTC timestamp in the device's zone.
  /// Inputs: `time`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Records store UTC; the
  /// user compares them in local time.
  static String _formatTime(DateTime time) =>
      DateFormat.yMd().add_Hms().format(time.toLocal());

  /// Purpose: Summarize what a record's payload actually says.
  /// Inputs: `record`.
  /// Returns: `String` — a few lines of `field: value`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The payload is an
  /// opaque map here on purpose (see `transcribe_settings.dart`), so this
  /// prints it rather than interpreting it — which also means a record written
  /// by a newer build still shows the user something they can choose between.
  /// Long values are cut so one differing field stays visible; the API key is
  /// never in this map, so nothing secret can be printed.
  static String _summarize(SettingsRecord record) {
    final entries = record.payload.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return '—';
    return [
      for (final e in entries.take(8)) '${e.key}: ${_short(e.value)}',
      if (entries.length > 8) '…',
    ].join('\n');
  }

  /// Purpose: Render one value on one line.
  /// Inputs: `value`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String _short(Object? value) {
    final text = '$value'.replaceAll('\n', ' ');
    return text.length <= 48 ? text : '${text.substring(0, 47)}…';
  }

  /// Purpose: Render one version's facts as a labelled block.
  /// Inputs: `context`, `heading`, `record`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Both blocks show the
  /// same fields in the same order, so the difference is easy to spot.
  Widget _version(BuildContext context, String heading, SettingsRecord record) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '${l10n.syncModifiedAt}: ${_formatTime(record.modifiedAt)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(_summarize(record), style: theme.textTheme.bodySmall),
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
            _version(context, l10n.syncLocalVersion, conflict.localRecord),
            const Divider(height: 24),
            _version(context, l10n.syncRemoteVersion, conflict.remoteRecord),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(conflict.remoteRecord),
          child: Text(l10n.syncKeepRemote),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(conflict.localRecord),
          child: Text(l10n.syncKeepLocal),
        ),
      ],
    );
  }
}

/// Purpose: Ask the user which version of one settings record to keep.
/// Inputs: `context`, `conflict`.
/// Returns: `Future<SettingsRecord?>` — null when the user backs out.
/// Side effects: Shows a modal dialog.
/// Notes: Not barrier-dismissible: backing out aborts the whole sync, so it
/// must be a deliberate act rather than a stray tap outside the dialog.
Future<SettingsRecord?> showSettingsConflictDialog(
  BuildContext context,
  RecordConflict<SettingsRecord> conflict,
) {
  return showDialog<SettingsRecord>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => SettingsConflictDialog(conflict: conflict),
  );
}
