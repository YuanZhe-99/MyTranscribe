/// Purpose: Turn one transcription request into an HTTP request, and one HTTP
/// response back into segments, for whichever endpoint is being used.
/// Inputs: A normalized request, the source and the model.
/// Returns: The dialect interface and its shared value types.
/// Side effects: None here; implementations build requests and parse bodies.
/// Notes: The three endpoints differ in more than their URLs — where options
/// go, whether the body is multipart or JSON, what a reply looks like — and a
/// dialect is where that difference lives. Above this, a job knows only that it
/// has audio and wants text.
library;

import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/model_config.dart';
import '../models/provider_config.dart';

/// A speaker whose voice the request carries a sample of.
class KnownSpeaker {
  /// The identifier to send, and to expect back in the reply.
  ///
  /// The app's own stable speaker id rather than a display name, so renaming a
  /// speaker in the viewer does not change what the next window is told.
  final String id;

  /// A short clip of them speaking.
  final File sample;

  /// Purpose: Create a known speaker reference.
  /// Inputs: [id], [sample].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const KnownSpeaker({required this.id, required this.sample});
}

/// What the app wants transcribed, before any endpoint's shape is applied.
class TranscriptionRequest {
  /// The audio to send.
  final File file;

  /// Its media type, from the extension.
  final String mimeType;

  /// Language hints, most likely first; empty means let the model decide.
  final List<String> languages;

  /// Context for models that accept it.
  final String? prompt;

  /// Terms the recording is likely to contain.
  final List<String> keywords;

  /// Whether to ask for speaker labels.
  final bool diarize;

  /// Whether to ask for per-segment times.
  final bool wantTimestamps;

  /// Voice samples to carry, where the endpoint accepts them.
  final List<KnownSpeaker> knownSpeakers;

  /// Purpose: Describe one window to transcribe.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptionRequest({
    required this.file,
    required this.mimeType,
    this.languages = const [],
    this.prompt,
    this.keywords = const [],
    this.diarize = false,
    this.wantTimestamps = true,
    this.knownSpeakers = const [],
  });
}

/// One piece of transcript as the endpoint returned it.
class RawSegment {
  /// Where it starts inside this window, in seconds.
  final double startSeconds;

  /// Where it ends inside this window, in seconds.
  final double endSeconds;

  /// What was said.
  final String text;

  /// The speaker label the endpoint used, if any.
  ///
  /// Window-local. The same person is labelled independently in each window,
  /// which is what the speaker unifier resolves.
  final String? speaker;

  /// Purpose: Create a raw segment.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const RawSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
    this.speaker,
  });
}

/// What one window came back as.
class TranscriptionResult {
  /// The whole window's text.
  final String text;

  /// Its segments, when the endpoint returned any.
  final List<RawSegment> segments;

  /// Whether the times on those segments are real.
  ///
  /// False when the endpoint returned only text and the segments were
  /// synthesised from the window's own boundaries.
  final bool hasRealTimestamps;

  /// Whether any segment carries a speaker label.
  final bool hasSpeakers;

  /// Purpose: Create a result.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptionResult({
    required this.text,
    this.segments = const [],
    this.hasRealTimestamps = false,
    this.hasSpeakers = false,
  });
}

/// Why a transcription request failed.
enum TranscriptionFailure {
  /// No key, or the wrong one.
  unauthorized,

  /// The upload was larger than the endpoint accepts.
  tooLarge,

  /// Too many requests; the caller should wait.
  rateLimited,

  /// The endpoint rejected something in the request.
  ///
  /// [TranscriptionException.rejectedFeature] says which feature, when it can
  /// be told, so the caller can offer to run again without it.
  rejected,

  /// The endpoint had a problem of its own.
  serverError,

  /// The request never got there, or never came back.
  network,

  /// The reply was not something this dialect could read.
  badResponse,

  /// The caller cancelled.
  cancelled,
}

/// A feature an endpoint refused, where the refusal named one.
enum RejectedFeature { diarization, keywords, timestamps, prompt }

/// A transcription request that did not succeed.
class TranscriptionException implements Exception {
  /// What went wrong.
  final TranscriptionFailure failure;

  /// What to tell the user — the endpoint's own words where it gave any.
  final String message;

  /// The HTTP status, when there was one.
  final int? statusCode;

  /// How long the endpoint asked the caller to wait.
  final Duration? retryAfter;

  /// The feature the endpoint refused, when the refusal named one.
  ///
  /// Lets the job offer "run again without speaker labels" instead of making
  /// the user find the setting themselves.
  final RejectedFeature? rejectedFeature;

  /// Purpose: Create a transcription exception.
  /// Inputs: All fields.
  /// Returns: A new exception.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptionException(
    this.failure,
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.rejectedFeature,
  });

  /// Whether trying the same request again could reasonably work.
  bool get isRetryable =>
      failure == TranscriptionFailure.network ||
      failure == TranscriptionFailure.serverError ||
      failure == TranscriptionFailure.rateLimited;

  @override
  String toString() => 'TranscriptionException(${failure.name}): $message';
}

/// Shapes requests and reads replies for one kind of endpoint.
abstract class ProviderDialectHandler {
  /// Purpose: Allow subclasses to be const.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: These handlers hold no state, so one const instance per dialect is
  /// all the app ever needs.
  const ProviderDialectHandler();

  /// Purpose: Build the HTTP request for one window.
  /// Inputs: [request], the [provider], the [model], and the [apiKey].
  /// Returns: A request ready to send.
  /// Side effects: Opens the audio file for streaming.
  /// Notes: The audio is streamed from disk rather than read into memory: a
  /// window is up to about 24 MB, and holding one twice over on a phone is
  /// avoidable.
  Future<http.BaseRequest> buildRequest(
    TranscriptionRequest request,
    ProviderConfig provider,
    ModelConfig model,
    String? apiKey,
  );

  /// Purpose: Read one reply.
  /// Inputs: The [body] and the [format] that was asked for.
  /// Returns: A [TranscriptionResult].
  /// Side effects: None.
  /// Notes: Throws [TranscriptionException] with
  /// [TranscriptionFailure.badResponse] when the body is not what the format
  /// promised, rather than returning an empty transcript — a window that
  /// silently produced nothing would be indistinguishable from silence.
  TranscriptionResult parseResponse(String body, String format);

  /// Purpose: Say which reply format this request should ask for.
  /// Inputs: [request], [model].
  /// Returns: The format name.
  /// Side effects: None.
  /// Notes: Asking for a format a model rejects costs a whole round trip and
  /// comes back as a 400, so the dialect picks from what the model states it
  /// accepts.
  String responseFormatFor(TranscriptionRequest request, ModelConfig model);

  /// Purpose: Say whether this request must travel as JSON rather than
  /// multipart.
  /// Inputs: [request], [model].
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Read by the planner, because a JSON body carries the audio as
  /// base64 and needs a smaller byte budget.
  bool needsJsonBody(TranscriptionRequest request, ModelConfig model) => false;
}

/// Purpose: Guess a media type from a file extension.
/// Inputs: [path].
/// Returns: The type, defaulting to `application/octet-stream`.
/// Side effects: None.
/// Notes: Only the formats these endpoints accept. A wrong type makes some
/// servers reject an otherwise fine upload, which is why this is a table rather
/// than a single default.
String mimeTypeForPath(String path) {
  final dot = path.lastIndexOf('.');
  final extension = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'mp3' || 'mpga' || 'mpeg' => 'audio/mpeg',
    'm4a' || 'mp4' => 'audio/mp4',
    'wav' => 'audio/wav',
    'webm' => 'audio/webm',
    'flac' => 'audio/flac',
    'ogg' || 'oga' => 'audio/ogg',
    'aac' => 'audio/aac',
    _ => 'application/octet-stream',
  };
}

/// Purpose: Name the audio format the way a JSON request expects it.
/// Inputs: [path].
/// Returns: A short format name.
/// Side effects: None.
/// Notes: The JSON mode takes a bare format name rather than a media type.
String audioFormatForPath(String path) {
  final dot = path.lastIndexOf('.');
  final extension = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'mpga' || 'mpeg' => 'mp3',
    'oga' => 'ogg',
    _ => extension.isEmpty ? 'mp3' : extension,
  };
}

/// Purpose: Build the authentication headers for a source.
/// Inputs: [provider], [apiKey].
/// Returns: The headers, empty when the source needs none.
/// Side effects: None.
/// Notes: Shared by every dialect, so a source configured with a custom header
/// works the same way everywhere.
Map<String, String> authHeaders(ProviderConfig provider, String? apiKey) {
  if (apiKey == null || apiKey.isEmpty) return const {};
  return switch (provider.authScheme) {
    AuthScheme.none => const {},
    AuthScheme.bearer => {'Authorization': 'Bearer $apiKey'},
    AuthScheme.header => {(provider.authHeaderName ?? 'Authorization'): apiKey},
  };
}
