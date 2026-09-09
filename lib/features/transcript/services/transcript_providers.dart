/// Purpose: Hand the viewer its transcript and the way the user likes to read
/// one.
/// Inputs: The transcript store and the device preferences.
/// Returns: Riverpod providers.
/// Side effects: Reads files.
/// Notes: The page reads nothing itself. That keeps the file access in one
/// place, and it is what lets the viewer be tested at six window geometries
/// without a disk — a widget test runs in a zone where `dart:io` futures never
/// complete, so a page that awaited one in `initState` could never be pumped.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/transcribe_storage.dart';
import '../../jobs/services/job_providers.dart';
import '../models/transcript.dart';
import 'transcript_store.dart';

/// Which view the transcript is in.
enum ViewerMode {
  /// Flowing paragraphs, for reading.
  transcript,

  /// One row per line with its times, for correcting.
  segments,
}

/// How the user likes to read a transcript.
class ViewerPreferences {
  /// Which view to open in.
  final ViewerMode mode;

  /// Whether consecutive lines from one speaker are joined.
  final bool group;

  /// Whether times are shown.
  final bool showTimes;

  /// Whether the page scrolls itself as the audio plays.
  final bool follow;

  /// The reading size, in logical pixels.
  final double fontSize;

  /// Purpose: Create a set of preferences.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: The defaults are the ones the storage hub applies, repeated here so
  /// a test that overrides this provider gets the same starting point as a
  /// device that has never been configured.
  const ViewerPreferences({
    this.mode = ViewerMode.transcript,
    this.group = true,
    this.showTimes = true,
    this.follow = true,
    this.fontSize = 16,
  });
}

/// How many times a transcript has been written since the app started.
///
/// Purpose: Let anything that writes a transcript ask the viewer to re-read it.
/// Inputs: None.
/// Returns: A counter.
/// Side effects: None.
/// Notes: The viewer keeps its own edited copy in page state, which dies with
/// the route; without this the next open would be served the first read for the
/// rest of the session, and a rename would look as though it had never been
/// saved. The job list solves the same problem the same way — see
/// `jobRevisionProvider`.
final transcriptRevisionProvider = StateProvider<int>((ref) => 0);

/// One job's transcript, or null when it has none.
final transcriptProvider = FutureProvider.family<Transcript?, String>((
  ref,
  jobId,
) async {
  // A finished run, the viewer's own save and the sync's apply step all bump
  // one of these, and each is a reason the file on disk is no longer what was
  // read.
  ref.watch(jobRevisionProvider);
  ref.watch(transcriptRevisionProvider);
  return TranscriptStore.load(jobId);
});

/// How the user last left the viewer.
final viewerPreferencesProvider = FutureProvider<ViewerPreferences>((
  ref,
) async {
  return ViewerPreferences(
    mode: await TranscribeStorage.getViewerMode() == 'segments'
        ? ViewerMode.segments
        : ViewerMode.transcript,
    group: await TranscribeStorage.getViewerGroupSpeakers(),
    showTimes: await TranscribeStorage.getViewerShowTimestamps(),
    follow: await TranscribeStorage.getViewerAutoScroll(),
    fontSize: (await TranscribeStorage.getViewerFontSize() ?? 16).toDouble(),
  );
});
