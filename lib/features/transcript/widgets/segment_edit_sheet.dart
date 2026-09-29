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
  final result = await showModalBottomSheet<SegmentEdit>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) =>
        _SegmentEditBody(segment: segment, speakers: speakers, nameOf: nameOf),
  );

  if (result == null) return null;
  if (result.text == segment.text && result.speakerId == segment.speakerId) {
    return null;
  }
  return result;
}

/// The sheet's contents; owns the text controller and the chosen speaker.
///
/// The controller lives in this widget's [State] so it is disposed with the
/// sheet's own element, not while the closing animation is still building the
/// field.
class _SegmentEditBody extends StatefulWidget {
  /// The line being edited.
  final TranscriptSegment segment;

  /// The speakers to choose from.
  final List<Speaker> speakers;

  /// How to name a speaker id, or null for the fallback.
  final String? Function(String?) nameOf;

  /// Purpose: Create the sheet body.
  /// Inputs: [segment], [speakers], [nameOf].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _SegmentEditBody({
    required this.segment,
    required this.speakers,
    required this.nameOf,
  });

  /// Purpose: Create the body's state.
  /// Inputs: None.
  /// Returns: The state.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<_SegmentEditBody> createState() => _SegmentEditBodyState();
}

/// State for [_SegmentEditBody].
class _SegmentEditBodyState extends State<_SegmentEditBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.segment.text,
  );
  late String? _speakerId = widget.segment.speakerId;

  /// Purpose: Release the text controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: Runs only after the sheet's route has finished animating out.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Purpose: Build the sheet contents.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None here; the buttons pop the route.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final speakers = widget.speakers;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.viewerEditSegment,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
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
              initialValue: _speakerId,
              decoration: InputDecoration(labelText: l10n.viewerEditSpeaker),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.viewerSpeakerUnknown),
                ),
                // Indexed, so the fallback can number a speaker by their
                // position rather than by their id, which can have gaps.
                for (var index = 0; index < speakers.length; index++)
                  DropdownMenuItem(
                    value: speakers[index].id,
                    child: Text(
                      widget.nameOf(speakers[index].id) ??
                          speakers[index].displayName(
                            l10n.viewerSpeakerFallback,
                            number: index + 1,
                          ),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _speakerId = value),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  SegmentEdit(text: _controller.text, speakerId: _speakerId),
                ),
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
