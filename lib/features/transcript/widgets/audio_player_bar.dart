/// Purpose: Play the recording beside its transcript.
/// Inputs: The player service, and whether the window can carry a wide layout.
/// Returns: A bar for the bottom of the viewer.
/// Side effects: None; the service plays.
/// Notes: The bar is always present, even when there is no audio to play — a
/// control that disappears is harder to understand than one that is visibly
/// disabled, and a transcript whose recording was deleted is a normal state.
library;

import 'package:flutter/material.dart';

import '../../../shared/services/audio_player_service.dart';
import '../../../l10n/app_localizations.dart';
import '../services/export_formatters.dart';

/// How far the skip buttons move, in seconds.
const _skipSeconds = 10.0;

/// The speeds offered, in order.
const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

class AudioPlayerBar extends StatelessWidget {
  /// The player to drive.
  final AudioPlayerService player;

  /// Whether the window is wide enough for the times and the speed control to
  /// sit beside the slider.
  final bool wide;

  /// Purpose: Create the bar.
  /// Inputs: [player], [wide].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const AudioPlayerBar({super.key, required this.player, required this.wide});

  /// Purpose: Build the bar.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: Narrow windows stack the slider above the buttons rather than
  /// shrinking either: a seek bar too short to aim at is worse than one on its
  /// own line.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ValueListenableBuilder<PlaybackState>(
      valueListenable: player.state,
      builder: (context, state, _) {
        if (!state.ready) {
          return Material(
            color: theme.colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  l10n.viewerAudioMissing,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }

        final total = state.duration.inMilliseconds / 1000;
        final at = state.positionSeconds.clamp(0.0, total <= 0 ? 0.0 : total);

        final slider = Slider(
          value: at,
          max: total <= 0 ? 1 : total,
          onChanged: total <= 0 ? null : player.seek,
        );
        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () => player.nudge(-_skipSeconds),
            ),
            IconButton.filled(
              icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
              onPressed: player.toggle,
            ),
            IconButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () => player.nudge(_skipSeconds),
            ),
          ],
        );
        final times = Text(
          '${readableTimestamp(at)} / ${readableTimestamp(total)}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        final speed = PopupMenuButton<double>(
          tooltip: '',
          initialValue: state.speed,
          onSelected: player.setSpeed,
          itemBuilder: (context) => [
            for (final option in _speeds)
              PopupMenuItem(value: option, child: Text('${option}x')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text('${state.speed}x', style: theme.textTheme.labelLarge),
          ),
        );

        return Material(
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: wide
                  ? Row(
                      children: [
                        buttons,
                        Expanded(child: slider),
                        times,
                        const SizedBox(width: 8),
                        speed,
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        slider,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [times, buttons, speed],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
