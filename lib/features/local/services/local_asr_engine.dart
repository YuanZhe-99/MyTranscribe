/// Purpose: The one protocol every on-device speech engine speaks, and the
/// value types that cross it.
/// Inputs: Implemented by the adapters — whisper.cpp, sherpa-onnx, the Apple
/// and Android plugins — and by the fake engine the tests use.
/// Returns: `LocalAsrEngine` and its requests, sessions, events and errors.
/// Side effects: None here; adapters load models and run native code.
/// Notes: Reduced to what a file-transcribing app needs: no streaming, since a
/// window is a file (decision D4 of the local-models plan). An adapter owns its
/// native handle on one isolate or thread and releases it only after the
/// native call has returned (D16). See `doc/en-us/features/local-models.md`.
library;

import 'dart:io';

import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';

/// Why a local engine could not do what it was asked, in one code set.
enum LocalAsrErrorCode {
  /// The package is not installed.
  modelMissing,

  /// The package's files are damaged.
  modelCorrupt,

  /// The package is not the format this adapter reads.
  modelFormatMismatch,

  /// The model does not transcribe the requested language.
  unsupportedLanguage,

  /// The model or route does not do something the job asked for.
  unsupportedFeature,

  /// This build has no such backend.
  backendNotBuilt,

  /// The backend needs a driver this device lacks.
  driverMissing,

  /// The processor is there but will not take work.
  deviceUnavailable,

  /// The runtime could not compile the model for the processor.
  modelCompileFailed,

  /// Not enough memory to load or run.
  outOfMemory,

  /// The window is longer than the route takes.
  inputTooLong,

  /// The processor went away mid-run — a GPU reset, a driver timeout.
  deviceLost,

  /// The process died inside this route; found by the in-flight marker at the
  /// next start (D20).
  routeCrashed,

  /// The caller cancelled.
  cancelled;

  /// The code as the survey and the docs write it, e.g. `MODEL_MISSING`.
  String get wire =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();

  /// Purpose: Parse a persisted code.
  /// Inputs: [value], in either the enum or the wire spelling.
  /// Returns: The code, or [deviceUnavailable] when unrecognised.
  /// Side effects: None.
  /// Notes: The fallback is a device problem because that is the one a
  /// fallback policy may answer, and it never claims the model is broken.
  static LocalAsrErrorCode parse(Object? value) {
    for (final code in LocalAsrErrorCode.values) {
      if (code.name == value || code.wire == value) return code;
    }
    return deviceUnavailable;
  }

  /// Whether the problem is with the processor or the route rather than the
  /// model or the request — the only kind a fallback to the CPU can help.
  bool get isRouteProblem => switch (this) {
    backendNotBuilt ||
    driverMissing ||
    deviceUnavailable ||
    modelCompileFailed ||
    deviceLost ||
    routeCrashed ||
    outOfMemory => true,
    _ => false,
  };
}

/// A local engine failure.
class LocalAsrException implements Exception {
  /// Which failure.
  final LocalAsrErrorCode code;

  /// What to tell the user, with the numbers where there are any.
  final String message;

  /// Whether the same call might work if tried again unchanged.
  final bool retryable;

  /// Purpose: Create a local engine failure.
  /// Inputs: [code], [message], optional [retryable].
  /// Returns: A new exception.
  /// Side effects: None.
  /// Notes: None.
  const LocalAsrException(this.code, this.message, {this.retryable = false});

  /// Purpose: Render the failure for a log.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  @override
  String toString() => 'LocalAsrException(${code.wire}): $message';
}

/// What to load, and where.
class PrepareRequest {
  /// The route to load on.
  final EngineRoute route;

  /// The installed package's manifest.
  final ArtifactManifest manifest;

  /// The installed package's folder.
  final Directory artifactDir;

  /// The job it is for, or null for a check.
  final String? jobId;

  /// Purpose: Create a prepare request.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const PrepareRequest({
    required this.route,
    required this.manifest,
    required this.artifactDir,
    this.jobId,
  });
}

/// A model loaded on a processor, ready for windows.
class PreparedSession {
  /// Identifies the session to [LocalAsrEngine.transcribe] and
  /// [LocalAsrEngine.release].
  final String sessionId;

  /// The package revision that was loaded.
  final String artifactRevision;

  /// The processor asked for.
  final ComputeDevice requestedDevice;

  /// Where the runtime says the model actually went.
  final PlacementKind placement;

  /// How long loading took.
  final Duration prepareTime;

  /// Whether a compile cache made loading faster.
  final bool usedCompileCache;

  /// Purpose: Create a session description.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const PreparedSession({
    required this.sessionId,
    required this.artifactRevision,
    required this.requestedDevice,
    required this.placement,
    this.prepareTime = Duration.zero,
    this.usedCompileCache = false,
  });
}

/// One window to transcribe.
class TranscribeRequest {
  /// The job, for the events.
  final String jobId;

  /// The session to run it on.
  final String sessionId;

  /// The window: 16 kHz mono 16-bit PCM WAV (decision D5).
  final File pcmWindow;

  /// Its length, in seconds.
  final double windowSeconds;

  /// Language hints, most likely first; empty to detect.
  final List<String> languages;

  /// Context for models that take it.
  final String? prompt;

  /// Terms to listen for, for models that take them.
  final List<String> keywords;

  /// Purpose: Create a transcribe request.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscribeRequest({
    required this.jobId,
    required this.sessionId,
    required this.pcmWindow,
    required this.windowSeconds,
    this.languages = const [],
    this.prompt,
    this.keywords = const [],
  });
}

/// What an engine event says.
enum AsrEventType {
  /// Loading or compiling.
  preparing,

  /// The window started.
  started,

  /// How far through the window it is.
  progress,

  /// A finished segment.
  segment,

  /// The window finished.
  completed,

  /// The window stopped because it was cancelled.
  cancelled,

  /// The window failed.
  error,

  /// The engine moved to another route on its own and says so.
  fallback,
}

/// One timed piece of text, in window-local seconds.
class AsrSegment {
  /// Where it starts.
  final double startSeconds;

  /// Where it ends.
  final double endSeconds;

  /// What was said.
  final String text;

  /// Purpose: Create a segment.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const AsrSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });
}

/// One event from a running window.
class AsrEvent {
  /// The job it belongs to.
  final String jobId;

  /// Its position in the window's events, from zero.
  final int sequence;

  /// What it says.
  final AsrEventType type;

  /// How far through, from 0 to 1, for [AsrEventType.progress].
  final double? progress;

  /// The segment, for [AsrEventType.segment].
  final AsrSegment? segment;

  /// Whether the segments carry real times, for [AsrEventType.completed].
  final bool hasRealTimestamps;

  /// Where the window actually ran, for [AsrEventType.completed].
  final PlacementKind? placement;

  /// The failure, for [AsrEventType.error].
  final LocalAsrException? error;

  /// A sentence, for [AsrEventType.fallback].
  final String? detail;

  /// Purpose: Create an event.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: One envelope for every type keeps a platform-channel adapter to
  /// one message shape.
  const AsrEvent({
    required this.jobId,
    required this.sequence,
    required this.type,
    this.progress,
    this.segment,
    this.hasRealTimestamps = false,
    this.placement,
    this.error,
    this.detail,
  });
}

/// An on-device speech engine.
abstract interface class LocalAsrEngine {
  /// The adapter's id: `whisper_cpp`, `sherpa_onnx`, `apple_fluid`, …
  String get adapterId;

  /// Purpose: Describe every (model, device) this adapter could run here.
  /// Inputs: The installed [manifests] this adapter reads.
  /// Returns: The routes, with evidence and availability.
  /// Side effects: May query drivers.
  /// Notes: Check results are attached by the registry, not here.
  Future<List<EngineRoute>> probe(List<ArtifactManifest> manifests);

  /// Purpose: Load a model on a processor.
  /// Inputs: [request].
  /// Returns: The session, with the placement the runtime reported.
  /// Side effects: Loads native resources.
  /// Notes: Throws [LocalAsrException].
  Future<PreparedSession> prepare(PrepareRequest request);

  /// Purpose: Transcribe one window.
  /// Inputs: [request].
  /// Returns: Events ending in exactly one of completed, cancelled or error.
  /// Side effects: Runs the model.
  /// Notes: The stream closes after its last event.
  Stream<AsrEvent> transcribe(TranscribeRequest request);

  /// Purpose: Stop a job's running window.
  /// Inputs: [jobId].
  /// Returns: A future completing when the native call has returned.
  /// Side effects: Sets the runtime's abort flag.
  /// Notes: Cooperative: the runtime stops at its next segment or token
  /// boundary. Releasing before this completes would free memory the native
  /// call is still using.
  Future<void> cancel(String jobId);

  /// Purpose: Unload a session.
  /// Inputs: [sessionId].
  /// Returns: None.
  /// Side effects: Frees native resources.
  /// Notes: None.
  Future<void> release(String sessionId);
}
