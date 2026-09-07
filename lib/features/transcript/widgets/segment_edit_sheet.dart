/// Purpose: Correct one line of a transcript — what was said, and who said it.
/// Inputs: The segment and the speakers available.
/// Returns: The edit, or null when it was dismissed.
/// Side effects: Opens a modal sheet.
/// Notes: A sheet rather than an inline field: an inline editor on a long
/// transcript makes every row a potential text field, which is slow to build
/// and easy to type into by accident.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/transcript.dart';

/// What the user changed.
class SegmentEdit {
  /// The corrected text.
  final String text;

  /// Who said it, or null for nobody in particular.
  final String? speakerId;

  /// Purpose: Create an edit.
  /// Inputs: [text], [speakerId].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SegmentEdit({required this.text, this.speakerId});
}

/// Purpose: Open the editor for one line.
/// Inputs: `context`, the [segment], the [speakers] to choose from, and how to
/// [nameOf] each one.
/// Returns: The edit, or null.
/// Side effects: Opens a modal sheet.
/// Notes: Returns null when nothing changed as well as when it was dismissed,
/// so the caller never writes the file for an edit that was not made.
Future<SegmentEdit?> showSegmentEditSheet(
  BuildContext context, {
  required TranscriptSegment segment,
  required List<Speaker> speakers,
  required String? Function(String?) nameOf,
}) async {
  final controller = TextEditingController(text: segment.text);
  var speakerId = segment.speakerId;

  final result = await showModalBottomSheet<SegmentEdit>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.viewerEditSegment,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 6,
                minLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.viewerEditText,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (speakers.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: speakerId,
                  decoration: InputDecoration(
                    labelText: l10n.viewerEditSpeaker,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.viewerEditNobody),
                    ),
                    // Indexed, so the fallback can number a speaker by their
                    // position rather than by their id, which can have gaps.
                    for (var index = 0; index < speakers.length; index++)
                      DropdownMenuItem(
                        value: speakers[index].id,
                        child: Text(
                          nameOf(speakers[index].id) ??
                              speakers[index].displayName(
                                l10n.viewerSpeakerFallback,
                                number: index + 1,
                              ),
                        ),
                      ),
                  ],
                  onChanged: (value) => setSheetState(() => speakerId = value),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(
                      SegmentEdit(text: controller.text, speakerId: speakerId),
                    ),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  controller.dispose();
  if (result == null) return null;
  if (result.text == segment.text && result.speakerId == segment.speakerId) {
    return null;
  }
  return result;
}
