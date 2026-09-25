/// Purpose: Label who spoke in a local job's windows (L8 of the local-models
/// plan).
/// Inputs: A PCM window; the window's transcribed segments.
/// Returns: The segments with window-local speaker labels.
/// Side effects: Starts a worker isolate that loads the speaker models.
/// Notes: No local transcription model labels speakers (decision D18), so a
/// separate pipeline does: sherpa-onnx's offline diarization over each window
/// — pyannote segmentation, a CAM++ voice embedding, clustering — with the
/// labels meaningful only within that window. The speaker unifier then joins
/// them across windows exactly as it joins a cloud source's labels. Needs the
/// speaker-labels package from Settings. See
/// `doc/en-us/features/local-models.md`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:local_asr_sherpa/local_asr_sherpa.dart';

import '../../../shared/utils/platform_capabilities.dart';
import '../../providers/services/provider_dialect.dart';
import 'artifact_manager.dart';
import 'local_model_templates.dart';
import 'pcm_window_cutter.dart';

/// Purpose: Give each segment the speaker it overlaps most.
/// Inputs: The window's [segments] and the diarizer's [turns], both in
/// seconds from the window's start.
/// Returns: The segments with `speaker` set to `S1`, `S2`, … — or left as they
/// were where no turn overlaps them.
/// Side effects: None.
/// Notes: Pure, so it is tested without models. Labels follow the diarizer's
/// numbering, which is local to this window.
List<RawSegment> labelSegments(
  List<RawSegment> segments,
  List<SpeakerTurn> turns,
) => [
  for (final segment in segments)
    () {
      final overlap = <int, double>{};
      for (final turn in turns) {
        final shared =
            (segment.endSeconds < turn.end ? segment.endSeconds : turn.end) -
            (segment.startSeconds > turn.start
                ? segment.startSeconds
                : turn.start);
        if (shared > 0) {
          overlap[turn.speaker] = (overlap[turn.speaker] ?? 0) + shared;
        }
      }
      if (overlap.isEmpty) return segment;
      final best = overlap.entries.reduce((a, b) => b.value > a.value ? b : a);
      return RawSegment(
        startSeconds: segment.startSeconds,
        endSeconds: segment.endSeconds,
        text: segment.text,
        speaker: 'S${best.key + 1}',
      );
    }(),
];

/// The speaker labeller: one per app, with its own worker isolate.
class SpeakerLabeler {
  /// Purpose: Create the labeller.
  /// Inputs: The [artifacts] manager the package is installed through.
  /// Returns: A new labeller; the worker starts on first use.
  /// Side effects: None.
  /// Notes: None.
  SpeakerLabeler({required this.artifacts});

  /// Where the speaker-labels package lives.
  final ArtifactManager artifacts;

  _Worker? _worker;

  /// Purpose: Say whether the speaker-labels package is installed.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: Reads the installed manifest.
  /// Notes: None.
  Future<bool> available() async =>
      await artifacts.installed(speakerLabelsManifest.artifactId) != null;

  /// Purpose: Label one window's segments.
  /// Inputs: The window's [pcm] file and its [segments].
  /// Returns: The labelled segments; unchanged when the package is missing.
  /// Side effects: Loads the models on first use; runs them.
  /// Notes: A diarization failure leaves the window unlabelled rather than
  /// failing the job: the transcript is the product, the labels a bonus.
  Future<List<RawSegment>> label(File pcm, List<RawSegment> segments) async {
    if (segments.isEmpty || !await available()) return segments;
    final dir = await artifacts.artifactDir(speakerLabelsManifest.artifactId);
    final models = _findModels(dir);
    if (models == null) return segments;
    final worker = _worker ??= await _Worker.spawn();
    final turns = await worker.call((
      models.segmentation,
      models.embedding,
      pcm.path,
    ));
    if (turns is! List<SpeakerTurn>) return segments;
    return labelSegments(segments, turns);
  }
}

/// Purpose: Find the two model files in the installed package.
/// Inputs: The package [dir].
/// Returns: Their paths, or null.
/// Side effects: Lists the folder.
/// Notes: Internal helper used within this file only. The segmentation
/// archive unpacks into a folder of its own name.
({String segmentation, String embedding})? _findModels(Directory dir) {
  if (!dir.existsSync()) return null;
  String? segmentation;
  String? embedding;
  for (final entry in dir.listSync(recursive: true)) {
    if (entry is! File) continue;
    final name = entry.uri.pathSegments.last;
    if (name == 'model.onnx' && entry.path.contains('segmentation')) {
      segmentation = entry.path;
    } else if (name.contains('campplus') && name.endsWith('.onnx')) {
      embedding = entry.path;
    }
  }
  if (segmentation == null || embedding == null) return null;
  return (segmentation: segmentation, embedding: embedding);
}

/// The main isolate's end of the diarization worker.
class _Worker {
  _Worker._(this._send, this._receive) {
    _receive.listen((message) {
      final (id, result) = message as (int, Object?);
      _pending.remove(id)?.complete(result);
    });
  }

  final SendPort _send;
  final ReceivePort _receive;
  final _pending = <int, Completer<Object?>>{};
  var _next = 0;

  /// Purpose: Start the worker.
  /// Inputs: None.
  /// Returns: A connected [_Worker].
  /// Side effects: Spawns an isolate.
  /// Notes: None.
  static Future<_Worker> spawn() async {
    final receive = ReceivePort();
    final handshake = Completer<SendPort>();
    final replies = ReceivePort();
    receive.listen((message) {
      if (message is SendPort && !handshake.isCompleted) {
        handshake.complete(message);
      }
    });
    await Isolate.spawn(_workerMain, (
      receive.sendPort,
      replies.sendPort,
      localEngineThreads(Platform.numberOfProcessors),
    ), debugName: 'speaker-labels');
    final send = await handshake.future;
    receive.close();
    return _Worker._(send, replies);
  }

  /// Purpose: Diarize one window.
  /// Inputs: The segmentation and embedding model paths and the window's path.
  /// Returns: The turns, or a failure string.
  /// Side effects: None beyond the worker's.
  /// Notes: Requests run one after another on the worker.
  Future<Object?> call((String, String, String) request) {
    final id = _next++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _send.send((id, request));
    return completer.future;
  }
}

/// Purpose: The diarization worker's entry point.
/// Inputs: The handshake port, the reply port and the thread count.
/// Returns: None.
/// Side effects: Loads the speaker models once; runs them per window.
/// Notes: Internal helper used within this file only. A failure is answered
/// as a string; requests are handled one at a time.
void _workerMain((SendPort, SendPort, int) ports) {
  final (handshake, replies, threads) = ports;
  final requests = ReceivePort();
  handshake.send(requests.sendPort);
  SpeakerDiarizer? diarizer;

  Future<void> handle(Object? message) async {
    final (id, (segmentation, embedding, wav)) =
        message as (int, (String, String, String));
    Object? answer;
    try {
      diarizer ??= SpeakerDiarizer.load(
        segmentation: segmentation,
        embedding: embedding,
        threads: threads,
      );
      final window = await readPcmWindow(File(wav));
      answer = diarizer!.process(await window.readSamples());
    } catch (error) {
      answer = '$error';
    }
    replies.send((id, answer));
  }

  var queue = Future<void>.value();
  requests.listen((message) {
    queue = queue.then((_) => handle(message));
  });
}
