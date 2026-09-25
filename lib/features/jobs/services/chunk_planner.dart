/// Purpose: Decide how a recording is divided before it is sent.
/// Inputs: What the file is, what the model and source allow, and what the user
/// asked for.
/// Returns: A plan, or the reason there cannot be one.
/// Side effects: None — pure, so the whole table is testable without a file, a
/// network or a device.
/// Notes: Get this wrong in one direction and the request is rejected; in the
/// other, and a two-hour lecture becomes fifty needless round trips. See
/// `doc/en-us/algorithms/chunk-planner.md`.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../media/models/media_info.dart';
import '../../providers/models/model_config.dart';
import '../../providers/models/provider_config.dart';
import '../models/chunk_plan.dart';

/// Bytes one second of normalized audio occupies.
///
/// The app converts everything to a fixed 64 kbps before cutting, so this is
/// exact rather than an estimate — which is the whole reason a byte budget can
/// be turned into a time budget at all.
const transcodeBytesPerSecond = 8000;

/// The upload budget, below the 25 MB every one of these services states.
///
/// The margin covers container overhead and the fact that a "64 kbps" encode is
/// not exactly 64 kbps. The original scripts used the same figure.
const safeUploadBytes = 24 * 1024 * 1024;

/// The upload budget when the audio must be sent as base64 inside a JSON body.
///
/// Base64 inflates by a third, so the encoded body has to fit where the raw
/// bytes would. Used for the gateway's JSON mode, which is the only way to
/// reach a provider's own options such as speaker labels.
const jsonModeSafeBytes = 18 * 1024 * 1024;

/// How much of the byte budget one window may use.
const chunkByteMargin = 0.92;

/// How much of a duration cap one window may use.
const chunkDurationMargin = 0.95;

/// The longest single request the app will make, whatever the limits allow.
///
/// A very long request fails slowly and costs the whole window again on retry,
/// and it delays the first visible progress by that long. Twenty-five minutes.
///
/// Note what this implies: 1500 seconds of normalized audio is about 11 MB,
/// under both byte budgets above, so **this ceiling is what actually decides a
/// window length** whenever no model or gateway caps it lower. The byte budgets
/// still decide the fast path — whether a file goes up untouched — which is
/// where they earn their keep.
const maxAutoWindowSeconds = 1500;

/// The shortest stride the planner will produce.
///
/// Below this the overhead of a request dominates the audio it carries.
const minStrideSeconds = 60;

/// A final window shorter than this is folded into the one before it.
///
/// A three-second window is a round trip that returns almost nothing and often
/// ends mid-word.
const minLastWindowSeconds = 20;

/// What the user asked for, as far as planning is concerned.
class PlanRequest {
  /// The file's size in bytes.
  final int sourceBytes;

  /// Its extension, without the dot.
  final String sourceExtension;

  /// What probing found, or null when nothing could read it.
  final MediaInfo? media;

  /// The model that will be used.
  final ModelConfig model;

  /// The source it belongs to.
  final ProviderConfig provider;

  /// Whether speaker labels were requested.
  final bool diarize;

  /// Whether the request must carry the audio as base64 in a JSON body.
  final bool jsonMode;

  /// The overlap between windows, in seconds.
  final double overlapSeconds;

  /// A window length the user set by hand, in seconds, or null for automatic.
  final double? userWindowSeconds;

  /// Whether FFmpeg is available on this device.
  final bool toolkitAvailable;

  /// Everything else that would invalidate a cached result, for the
  /// fingerprint: language hints, the prompt, keywords.
  final List<String> settingsFingerprintParts;

  /// Purpose: Describe one planning request.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const PlanRequest({
    required this.sourceBytes,
    required this.sourceExtension,
    required this.model,
    required this.provider,
    required this.overlapSeconds,
    required this.toolkitAvailable,
    this.media,
    this.diarize = false,
    this.jsonMode = false,
    this.userWindowSeconds,
    this.settingsFingerprintParts = const [],
  });
}

/// What a local job asked for, as far as planning is concerned.
///
/// A local model has no upload, so there is no byte budget and no fast path:
/// the planner works in time alone, and every window is decoded to PCM, even
/// when the whole recording is one window.
class LocalPlanRequest {
  /// What probing found, or null when nothing could read it.
  final MediaInfo? media;

  /// The local model record's id.
  final String modelId;

  /// The model's own window ceiling, in seconds, or null.
  final int? engineMaxSeconds;

  /// The route's own window ceiling, in seconds, or null.
  final int? routeMaxSeconds;

  /// The longest window the route's memory budget allows, in seconds, or null
  /// when it reported none.
  final int? memoryMaxSeconds;

  /// The revision of the package that will be loaded.
  final String artifactRevision;

  /// What the user asked to run on: `auto`, `cpu`, or a route key.
  final String requestedDevice;

  /// The overlap between windows, in seconds.
  final double overlapSeconds;

  /// A window length the user set by hand, in seconds, or null.
  final double? userWindowSeconds;

  /// Whether FFmpeg is available on this device.
  final bool toolkitAvailable;

  /// Everything else that would invalidate a cached result: language hints,
  /// the prompt, keywords.
  final List<String> settingsFingerprintParts;

  /// Purpose: Describe one local planning request.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const LocalPlanRequest({
    required this.modelId,
    required this.artifactRevision,
    required this.requestedDevice,
    required this.overlapSeconds,
    required this.toolkitAvailable,
    this.media,
    this.engineMaxSeconds,
    this.routeMaxSeconds,
    this.memoryMaxSeconds,
    this.userWindowSeconds,
    this.settingsFingerprintParts = const [],
  });
}

/// Works out how to divide a recording.
class ChunkPlanner {
  /// Purpose: Prevent instantiation; the entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: None.
  const ChunkPlanner._();

  /// Purpose: Plan how to send one recording.
  /// Inputs: [request].
  /// Returns: A [PlanResult].
  /// Side effects: None.
  /// Notes: The order matters. The fast path is checked first, because a
  /// recording that already fits should never involve FFmpeg at all — that is
  /// what makes the app usable before the media tools are set up.
  static PlanResult plan(PlanRequest request) {
    final byteLimit = _byteLimit(request);
    final durationLimit = _durationLimit(request);
    final duration = request.media?.durationSeconds;
    final reasons = <PlanReason>[];

    if (request.media != null && !request.media!.hasAudio) {
      return const PlanResult.failed(PlanFailure.noAudio);
    }

    // ── The fast path ──
    final formatAccepted =
        request.model.acceptsInputFormat(request.sourceExtension) &&
        !(request.media?.hasVideo ?? false);
    final withinBytes = request.sourceBytes <= byteLimit;
    final withinDuration =
        durationLimit == null ||
        duration == null ||
        duration <= durationLimit * chunkDurationMargin;

    if (formatAccepted && withinBytes && withinDuration) {
      return PlanResult.success(
        ChunkPlan(
          single: true,
          uploadsOriginal: true,
          strideSeconds: duration ?? 0,
          overlapSeconds: 0,
          windows: [
            ChunkWindow(index: 0, startSeconds: 0, endSeconds: duration ?? 0),
          ],
          predictedChunkBytes: request.sourceBytes,
          reasons: const [PlanReason(PlanReasonCode.fitsWhole)],
          fingerprint: _fingerprint(request, 0, 0),
        ),
      );
    }

    // Everything below needs FFmpeg, and a duration to divide.
    if (!request.toolkitAvailable) {
      return const PlanResult.failed(PlanFailure.mediaToolkitMissing);
    }
    if (duration == null || duration <= 0) {
      return const PlanResult.failed(PlanFailure.durationUnknown);
    }

    if (!withinBytes) {
      reasons.add(PlanReason(PlanReasonCode.splitBySize, request.sourceBytes));
    } else if (!withinDuration) {
      reasons.add(PlanReason(PlanReasonCode.splitByDuration, durationLimit));
    } else if (!formatAccepted) {
      reasons.add(PlanReason(PlanReasonCode.splitByFormat));
    }

    // ── Window length ──
    final byWindowBytes =
        (byteLimit * chunkByteMargin) ~/ transcodeBytesPerSecond;
    var window = byWindowBytes.toDouble();
    var cap = PlanReasonCode.windowCappedBySize;

    if (durationLimit != null) {
      final byDuration = durationLimit * chunkDurationMargin;
      if (byDuration < window) {
        window = byDuration;
        cap =
            request.provider.maxRequestSeconds != null &&
                request.provider.maxRequestSeconds! <=
                    (request.model.maxDurationSeconds ?? 1 << 30)
            ? PlanReasonCode.windowCappedByProvider
            : PlanReasonCode.windowCappedByModel;
      }
    }
    if (maxAutoWindowSeconds < window) {
      window = maxAutoWindowSeconds.toDouble();
      cap = PlanReasonCode.windowCappedByCeiling;
    }

    // A whole recording that now fits one converted window still needs the
    // conversion, but not the division.
    final overlap = request.overlapSeconds.clamp(0.0, window / 2);
    if (request.diarize && request.overlapSeconds > 0) {
      reasons.add(
        PlanReason(PlanReasonCode.overlapForSpeakers, request.overlapSeconds),
      );
    }

    double stride;
    if (request.userWindowSeconds != null) {
      stride = request.userWindowSeconds!;
      reasons.add(PlanReason(PlanReasonCode.windowChosenByUser, stride));
    } else {
      stride = window - overlap;
      reasons.add(PlanReason(cap, window));
    }
    stride = stride.clamp(minStrideSeconds.toDouble(), window - overlap);
    if (stride <= 0) stride = window;

    final windows = _windows(duration, stride, overlap);
    return PlanResult.success(
      ChunkPlan(
        single: windows.length == 1,
        uploadsOriginal: false,
        strideSeconds: stride,
        overlapSeconds: overlap,
        windows: windows,
        predictedChunkBytes:
            ((stride + overlap) * transcodeBytesPerSecond).round() + 4096,
        reasons: reasons,
        fingerprint: _fingerprint(request, stride, overlap),
      ),
    );
  }

  /// Purpose: Plan a recording for a local model — time-only mode.
  /// Inputs: [request].
  /// Returns: A [PlanResult].
  /// Side effects: None.
  /// Notes: No fast path: a local engine takes PCM, so even a short clip is
  /// decoded, as one window, and that needs FFmpeg. The window is the smallest
  /// of the model's or route's own ceiling (`windowCappedByEngine`), the
  /// memory budget (`windowCappedByMemory`) and the app's ceiling on one
  /// request. The fingerprint names the model, the package revision and the
  /// device asked for, so an updated package or another device discards
  /// cached windows exactly as a changed prompt does.
  static PlanResult planLocal(LocalPlanRequest request) {
    final media = request.media;
    if (media != null && !media.hasAudio) {
      return const PlanResult.failed(PlanFailure.noAudio);
    }
    if (!request.toolkitAvailable) {
      return const PlanResult.failed(PlanFailure.mediaToolkitMissing);
    }
    final duration = media?.durationSeconds;
    if (duration == null || duration <= 0) {
      return const PlanResult.failed(PlanFailure.durationUnknown);
    }

    var window = maxAutoWindowSeconds.toDouble();
    var cap = PlanReasonCode.windowCappedByCeiling;
    for (final limit in [request.engineMaxSeconds, request.routeMaxSeconds]) {
      if (limit != null && limit < window) {
        window = limit.toDouble();
        cap = PlanReasonCode.windowCappedByEngine;
      }
    }
    final memory = request.memoryMaxSeconds;
    if (memory != null && memory < window) {
      window = memory.toDouble();
      cap = PlanReasonCode.windowCappedByMemory;
    }

    final overlap = request.overlapSeconds.clamp(0.0, window / 2);
    final reasons = <PlanReason>[];
    double stride;
    if (request.userWindowSeconds != null) {
      stride = request.userWindowSeconds!;
      reasons.add(PlanReason(PlanReasonCode.windowChosenByUser, stride));
    } else {
      stride = window - overlap;
      reasons.add(PlanReason(cap, window));
    }
    stride = stride.clamp(minStrideSeconds.toDouble(), window - overlap);
    if (stride <= 0) stride = window;

    final windows = _windows(duration, stride, overlap);
    return PlanResult.success(
      ChunkPlan(
        single: windows.length == 1,
        uploadsOriginal: false,
        strideSeconds: stride,
        overlapSeconds: overlap,
        windows: windows,
        // Two bytes a sample, one channel, plus the WAV header.
        predictedChunkBytes: ((stride + overlap) * 32000).round() + 44,
        reasons: reasons,
        fingerprint: _localFingerprint(request, stride, overlap),
      ),
    );
  }

  /// Purpose: Identify the settings a local plan was made under.
  /// Inputs: [request], [stride], [overlap].
  /// Returns: A short hash.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The device is the one
  /// *asked for*, not the one that ran: a fallback to the CPU mid-job keeps
  /// the windows the GPU already finished, because they came from the same
  /// model.
  static String _localFingerprint(
    LocalPlanRequest request,
    double stride,
    double overlap,
  ) {
    final parts = [
      'local',
      request.modelId,
      request.artifactRevision,
      request.requestedDevice,
      stride.toStringAsFixed(2),
      overlap.toStringAsFixed(2),
      ...request.settingsFingerprintParts,
    ];
    return sha256
        .convert(utf8.encode(parts.join(' ')))
        .toString()
        .substring(0, 16);
  }

  /// Purpose: Re-plan with shorter windows after one came out too large.
  /// Inputs: The [previous] plan, the [request] it came from, and the
  /// [duration].
  /// Returns: A new plan, or null when the stride cannot usefully shrink.
  /// Side effects: None.
  /// Notes: Audio is not perfectly uniform, so a window can exceed its
  /// prediction. The scripts stopped and told the user to retry with a
  /// different argument; this shortens the stride and re-cuts instead.
  static ChunkPlan? shrink(
    ChunkPlan previous,
    PlanRequest request,
    double duration,
  ) {
    final stride = previous.strideSeconds * 0.8;
    if (stride < minStrideSeconds) return null;
    final overlap = previous.overlapSeconds.clamp(0.0, stride / 2);
    final windows = _windows(duration, stride, overlap);
    return ChunkPlan(
      single: windows.length == 1,
      uploadsOriginal: false,
      strideSeconds: stride,
      overlapSeconds: overlap,
      windows: windows,
      predictedChunkBytes:
          ((stride + overlap) * transcodeBytesPerSecond).round() + 4096,
      reasons: previous.reasons,
      fingerprint: _fingerprint(request, stride, overlap),
    );
  }

  /// Purpose: Lay out the windows across a recording.
  /// Inputs: [duration], [stride], [overlap], all in seconds.
  /// Returns: The windows, in order.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A final window shorter
  /// than [minLastWindowSeconds] is folded into the one before it rather than
  /// sent on its own.
  static List<ChunkWindow> _windows(
    double duration,
    double stride,
    double overlap,
  ) {
    final windows = <ChunkWindow>[];
    var start = 0.0;
    var index = 0;
    while (start < duration) {
      final end = (start + stride + overlap).clamp(0.0, duration);
      windows.add(
        ChunkWindow(index: index, startSeconds: start, endSeconds: end),
      );
      start += stride;
      index++;
      if (end >= duration) break;
    }

    if (windows.length > 1) {
      final last = windows.last;
      if (last.lengthSeconds < minLastWindowSeconds) {
        windows.removeLast();
        final previous = windows.removeLast();
        windows.add(
          ChunkWindow(
            index: previous.index,
            startSeconds: previous.startSeconds,
            endSeconds: duration,
          ),
        );
      }
    }
    return windows;
  }

  /// Purpose: Work out the byte budget for one request.
  /// Inputs: [request].
  /// Returns: Bytes.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The model's limit, the
  /// source's, and the app's own safety margin, whichever is smallest. JSON
  /// mode gets the lower figure because base64 inflates the body by a third.
  static int _byteLimit(PlanRequest request) {
    final stated = [
      ?request.model.maxFileBytes,
      ?request.provider.maxFileBytes,
    ];
    final ceiling = request.jsonMode ? jsonModeSafeBytes : safeUploadBytes;
    return stated.isEmpty
        ? ceiling
        : [...stated, ceiling].reduce((a, b) => a < b ? a : b);
  }

  /// Purpose: Work out the time budget for one request.
  /// Inputs: [request].
  /// Returns: Seconds, or null when neither the model nor the source caps it.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A source's cap applies
  /// to every model behind it: a gateway that stops waiting after ten minutes
  /// does so regardless of what the model would have accepted.
  static int? _durationLimit(PlanRequest request) {
    final limits = [
      ?request.model.maxDurationSeconds,
      ?request.provider.maxRequestSeconds,
    ];
    if (limits.isEmpty) return null;
    return limits.reduce((a, b) => a < b ? a : b);
  }

  /// Purpose: Identify the settings a plan was made under.
  /// Inputs: [request], [stride], [overlap].
  /// Returns: A short hash.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A resume compares this;
  /// when it differs, cached window results are discarded, because a result
  /// produced under different settings is not the one the user asked for. The
  /// **model identifier** is in it and the display name is not — renaming a
  /// model in the library must not throw away hours of finished work.
  static String _fingerprint(
    PlanRequest request,
    double stride,
    double overlap,
  ) {
    final parts = [
      request.provider.id,
      request.provider.baseUrl,
      request.provider.dialect.name,
      request.model.modelName,
      stride.toStringAsFixed(2),
      overlap.toStringAsFixed(2),
      request.diarize.toString(),
      request.jsonMode.toString(),
      ...request.settingsFingerprintParts,
    ];
    return sha256
        .convert(utf8.encode(parts.join(' ')))
        .toString()
        .substring(0, 16);
  }
}
