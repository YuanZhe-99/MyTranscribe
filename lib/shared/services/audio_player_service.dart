/// Purpose: Play one recording beside its transcript, and say where it is up
/// to.
/// Inputs: A file path.
/// Returns: Position and duration through a listenable.
/// Side effects: Opens an audio device and holds a decoder.
/// Notes: A thin wrapper, not an abstraction: the viewer wants position, speed
/// and seeking, and everything else the package offers would be noise. Wrapping
/// it also means the viewer's tests never touch an audio device. See
/// `doc/en-us/features/transcript-viewer.md`.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// What the player is doing.
class PlaybackState {
  /// Whether audio is coming out.
  final bool playing;

  /// Where it is up to.
  final Duration position;

  /// How long the recording runs, once that is known.
  final Duration duration;

  /// The playback rate, 1 being normal.
  final double speed;

  /// Whether a file has been loaded at all.
  final bool ready;

  /// Purpose: Create a playback state.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const PlaybackState({
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.ready = false,
  });

  /// Where playback is up to, in seconds.
  double get positionSeconds => position.inMilliseconds / 1000;

  /// Purpose: Return a copy with some fields replaced.
  /// Inputs: The fields to change.
  /// Returns: A new [PlaybackState].
  /// Side effects: None.
  /// Notes: None.
  PlaybackState copyWith({
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? ready,
  }) => PlaybackState(
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    ready: ready ?? this.ready,
  );
}

/// Plays one file.
class AudioPlayerService {
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  /// What the player is doing, for the bar to watch.
  final ValueNotifier<PlaybackState> state = ValueNotifier(
    const PlaybackState(),
  );

  /// Purpose: Create the underlying player the first time one is needed.
  /// Inputs: None.
  /// Returns: The player.
  /// Side effects: Opens an audio device and subscribes to its streams.
  /// Notes: Internal helper used within this file only. Deliberately lazy:
  /// opening a recording is what needs an audio device, and a transcript being
  /// read on a machine whose recording is long gone should not claim one. It
  /// also keeps the plugin out of the way of widget tests.
  AudioPlayer _ensure() {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer();
    _player = player;
    _subscriptions.addAll([
      player.onPositionChanged.listen((position) {
        state.value = state.value.copyWith(position: position);
      }),
      player.onDurationChanged.listen((duration) {
        state.value = state.value.copyWith(duration: duration);
      }),
      player.onPlayerStateChanged.listen((playerState) {
        state.value = state.value.copyWith(
          playing: playerState == PlayerState.playing,
        );
      }),
      player.onPlayerComplete.listen((_) {
        state.value = state.value.copyWith(
          playing: false,
          position: Duration.zero,
        );
      }),
    ]);
    return player;
  }

  /// Purpose: Load a file without starting it.
  /// Inputs: [path].
  /// Returns: A future completing once the source is set.
  /// Side effects: Opens the file.
  /// Notes: Failures are swallowed into `ready: false`. A transcript is still
  /// worth reading when its audio has been deleted or moved, so a missing file
  /// must disable the bar rather than break the page.
  Future<void> load(String path) async {
    try {
      await _ensure().setSourceDeviceFile(path);
      state.value = state.value.copyWith(ready: true);
    } catch (_) {
      state.value = state.value.copyWith(ready: false);
    }
  }

  /// Purpose: Start or stop playback.
  /// Inputs: None.
  /// Returns: A future completing after the change.
  /// Side effects: Plays or pauses.
  /// Notes: None.
  Future<void> toggle() async {
    if (!state.value.ready) return;
    if (state.value.playing) {
      await _player?.pause();
    } else {
      await _player?.resume();
    }
  }

  /// Purpose: Jump to a point in the recording.
  /// Inputs: [seconds].
  /// Returns: A future completing after the seek.
  /// Side effects: Moves playback.
  /// Notes: The position is published immediately rather than waiting for the
  /// player's own event, so tapping a segment highlights it at once instead of
  /// a beat later.
  Future<void> seek(double seconds) async {
    if (!state.value.ready) return;
    final target = Duration(milliseconds: (seconds * 1000).round());
    state.value = state.value.copyWith(
      position: target < Duration.zero ? Duration.zero : target,
    );
    await _player?.seek(state.value.position);
  }

  /// Purpose: Move forward or back by a few seconds.
  /// Inputs: [seconds], negative to go back.
  /// Returns: A future completing after the seek.
  /// Side effects: Moves playback.
  /// Notes: None.
  Future<void> nudge(double seconds) =>
      seek(state.value.positionSeconds + seconds);

  /// Purpose: Change the playback rate.
  /// Inputs: [speed].
  /// Returns: A future completing after the change.
  /// Side effects: Sets the rate.
  /// Notes: Clamped to the range the platforms agree on; outside it, some
  /// backends distort and others refuse.
  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    state.value = state.value.copyWith(speed: clamped);
    if (state.value.ready) await _player?.setPlaybackRate(clamped);
  }

  /// Purpose: Release the player.
  /// Inputs: None.
  /// Returns: A future completing after disposal.
  /// Side effects: Cancels the subscriptions and frees the audio device.
  /// Notes: Called from the viewer's `dispose`. Leaving a player alive would
  /// keep a file handle on audio the user may then try to delete.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    state.dispose();
    await _player?.dispose();
    _player = null;
  }
}
