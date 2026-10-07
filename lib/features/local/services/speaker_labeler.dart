import 'dart:io';

import 'package:myapps_ai_asr/myapps_ai_asr.dart' as shared;
import 'package:myapps_ai_asr_sherpa/myapps_ai_asr_sherpa.dart';

import '../../providers/services/provider_dialect.dart';
import 'artifact_manager.dart';
import 'local_model_templates.dart';

typedef SpeakerTurn = ({double start, double end, int speaker});

/// Purpose: Attach window-local labels. Inputs: segments, turns. Returns: Segments.
/// Side effects: None. Notes: Cross-window identity remains application-owned.
List<RawSegment> labelSegments(
  List<RawSegment> segments,
  List<SpeakerTurn> turns,
) => [
  for (final segment in shared.labelSegments(
    [
      for (final item in segments)
        shared.AsrSegment(
          startSeconds: item.startSeconds,
          endSeconds: item.endSeconds,
          text: item.text,
          speaker: item.speaker,
        ),
    ],
    [
      for (final turn in turns)
        shared.SpeakerTurn(
          start: turn.start,
          end: turn.end,
          speaker: turn.speaker,
        ),
    ],
  ))
    RawSegment(
      startSeconds: segment.startSeconds,
      endSeconds: segment.endSeconds,
      text: segment.text,
      speaker: segment.speaker,
    ),
];

/// Application-owned artifact selection over the shared diarizer.
class SpeakerLabeler {
  /// Purpose: Create a labeler. Inputs: artifacts. Returns: Labeler.
  /// Side effects: None until use. Notes: Downloads remain explicit.
  SpeakerLabeler({required this.artifacts}) {
    _diarizer = SherpaDiarizer(
      models: () async {
        if (!await available()) return null;
        return findDiarizerModels(
          await artifacts.artifactDir(speakerLabelsManifest.artifactId),
        );
      },
    );
  }

  final ArtifactManager artifacts;
  late final SherpaDiarizer _diarizer;

  /// Purpose: Check package presence. Inputs: None. Returns: Presence.
  /// Side effects: Reads manifest. Notes: Does not download.
  Future<bool> available() async =>
      await artifacts.installed(speakerLabelsManifest.artifactId) != null;

  /// Purpose: Label a window. Inputs: pcm, segments. Returns: Labeled segments.
  /// Side effects: Runs inference. Notes: Failures keep the transcript usable.
  Future<List<RawSegment>> label(File pcm, List<RawSegment> segments) async {
    if (segments.isEmpty || !await available()) return segments;
    final lease = artifacts.lease(speakerLabelsManifest.artifactId);
    try {
      return labelSegments(segments, [
        for (final turn in await _diarizer.diarize(pcm.path))
          (start: turn.start, end: turn.end, speaker: turn.speaker),
      ]);
    } catch (_) {
      return segments;
    } finally {
      lease.release();
    }
  }
}
