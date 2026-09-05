/// Purpose: The controls that change how a transcript is displayed.
/// Inputs: The current settings and a callback for each.
/// Returns: A panel, used both in the sidebar and in a sheet.
/// Side effects: None; the caller saves.
/// Notes: One widget for both presentations, so a phone and a desktop cannot
/// end up offering different controls.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../services/transcript_providers.dart';

class ViewerOptionsPanel extends StatelessWidget {
  /// Which view is showing.
  final ViewerMode mode;

  /// Whether consecutive lines from one speaker are joined.
  final bool group;

  /// Whether times are shown.
  final bool showTimes;

  /// Whether the page scrolls itself as the audio plays.
  final bool follow;

  /// The reading size, in logical pixels.
  final double fontSize;

  /// Whether there is anybody to group by.
  final bool hasSpeakers;

  /// Called when the view changes.
  final ValueChanged<ViewerMode> onMode;

  /// Called when grouping is toggled.
  final ValueChanged<bool> onGroup;

  /// Called when times are toggled.
  final ValueChanged<bool> onTimes;

  /// Called when following is toggled.
  final ValueChanged<bool> onFollow;

  /// Called when the size changes.
  final ValueChanged<double> onFontSize;

  /// Purpose: Create the options panel.
  /// Inputs: All fields.
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const ViewerOptionsPanel({
    super.key,
    required this.mode,
    required this.group,
    required this.showTimes,
    required this.follow,
    required this.fontSize,
    required this.hasSpeakers,
    required this.onMode,
    required this.onGroup,
    required this.onTimes,
    required this.onFollow,
    required this.onFontSize,
  });

  /// Purpose: Build the panel.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: Grouping is offered only when there are speakers to group by; with
  /// nobody identified the switch would do nothing, and a control that does
  /// nothing reads as a bug.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.viewerOptions, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<ViewerMode>(
          segments: [
            ButtonSegment(
              value: ViewerMode.transcript,
              label: Text(l10n.viewerModeTranscript),
              icon: const Icon(Icons.notes),
            ),
            ButtonSegment(
              value: ViewerMode.segments,
              label: Text(l10n.viewerModeSegments),
              icon: const Icon(Icons.format_list_bulleted),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => onMode(selection.first),
        ),
        if (hasSpeakers)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: group,
            onChanged: onGroup,
            title: Text(l10n.viewerGroupSpeakers),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: showTimes,
          onChanged: onTimes,
          title: Text(l10n.viewerShowTimestamps),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: follow,
          onChanged: onFollow,
          title: Text(l10n.viewerAutoScroll),
        ),
        const SizedBox(height: 8),
        Text(l10n.viewerFontSize, style: theme.textTheme.bodyMedium),
        Slider(
          value: fontSize,
          min: 12,
          max: 24,
          divisions: 12,
          label: fontSize.round().toString(),
          onChanged: onFontSize,
        ),
      ],
    );
  }
}
