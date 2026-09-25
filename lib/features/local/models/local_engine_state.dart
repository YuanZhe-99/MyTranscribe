/// Purpose: The device-local state of the local engines — what each route's
/// check on this device found, which route was running when the app last
/// stopped, what the user chose per model, and the fallback policy.
/// Inputs: Parsed `local_engine_state.json`.
/// Returns: `LocalEngineState`, `SmokeTestKey`, `SmokeTestRecord` and
/// `InFlightMarker`.
/// Side effects: None.
/// Notes: Never synced, never backed up (decision D2 of the local-models
/// plan): a check result and a GPU choice are facts about this device. The
/// in-flight marker is what turns a native crash into a recorded `crashed`
/// result at the next start instead of a crash loop (D20). See
/// `doc/en-us/data-formats.md`.
library;

import 'engine_capability.dart';

/// What a check result is filed under.
///
/// Any part changing asks for a new check: a new adapter build, a different
/// model file, an OS update, a driver update, another device, or another
/// precision can each turn a passing route into a failing one.
class SmokeTestKey {
  /// The adapter and its native library version.
  final String adapterVersion;

  /// The SHA-256 of the model file the route loads.
  final String modelHash;

  /// The operating system version.
  final String osVersion;

  /// The GPU or NPU driver version, or empty for the CPU.
  final String driverVersion;

  /// The processor the route drives, as the runtime names it.
  final String deviceId;

  /// The precision the route runs at, e.g. `f16` or `q5_0`.
  final String precision;

  /// Purpose: Create a key.
  /// Inputs: All six parts.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SmokeTestKey({
    required this.adapterVersion,
    required this.modelHash,
    required this.osVersion,
    required this.driverVersion,
    required this.deviceId,
    required this.precision,
  });

  /// Purpose: Render the key as the string results are filed under.
  /// Inputs: None.
  /// Returns: The six parts joined with `|`.
  /// Side effects: None.
  /// Notes: Readable on purpose, so the diagnostics page and a support report
  /// can show which part changed.
  String encode() => [
    adapterVersion,
    modelHash,
    osVersion,
    driverVersion,
    deviceId,
    precision,
  ].map((part) => part.replaceAll('|', '/')).join('|');
}

/// One check of one route on this device.
class SmokeTestRecord {
  /// The route checked.
  final String routeKey;

  /// What the check found.
  final SmokeTestOutcome outcome;

  /// The text the route produced, when it produced any.
  final String? text;

  /// How close that text was to the expected text, from 0 to 1.
  final double? similarity;

  /// Seconds of work per second of audio.
  final double? realTimeFactor;

  /// Why it failed, in words.
  final String? reason;

  /// When it was checked, in UTC.
  final DateTime checkedAt;

  /// Purpose: Create a check record.
  /// Inputs: All fields; [routeKey], [outcome] and [checkedAt] are required.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SmokeTestRecord({
    required this.routeKey,
    required this.outcome,
    required this.checkedAt,
    this.text,
    this.similarity,
    this.realTimeFactor,
    this.reason,
  });

  /// Purpose: Summarise the record for the router.
  /// Inputs: None.
  /// Returns: A [SmokeTestSummary].
  /// Side effects: None.
  /// Notes: None.
  SmokeTestSummary get summary =>
      SmokeTestSummary(outcome, realTimeFactor: realTimeFactor, reason: reason);

  /// Purpose: Parse a check record.
  /// Inputs: [json].
  /// Returns: A [SmokeTestRecord].
  /// Side effects: None.
  /// Notes: None.
  factory SmokeTestRecord.fromJson(Map<String, dynamic> json) =>
      SmokeTestRecord(
        routeKey: json['routeKey'] as String? ?? '',
        outcome: SmokeTestOutcome.parse(json['outcome']),
        checkedAt:
            DateTime.tryParse('${json['checkedAt']}')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        text: json['text'] as String?,
        similarity: (json['similarity'] as num?)?.toDouble(),
        realTimeFactor: (json['realTimeFactor'] as num?)?.toDouble(),
        reason: json['reason'] as String?,
      );

  /// Purpose: Serialize a check record.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'routeKey': routeKey,
    'outcome': outcome.name,
    'checkedAt': checkedAt.toUtc().toIso8601String(),
    if (text != null) 'text': text,
    if (similarity != null) 'similarity': similarity,
    if (realTimeFactor != null) 'realTimeFactor': realTimeFactor,
    if (reason != null) 'reason': reason,
  };
}

/// A native call in progress, written before it starts and cleared after it
/// returns.
class InFlightMarker {
  /// The route the call runs on.
  final String routeKey;

  /// The key its check result is filed under.
  final String smokeKey;

  /// The job it was for, or null for a check.
  final String? jobId;

  /// When the call started, in UTC.
  final DateTime startedAt;

  /// Purpose: Create a marker.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const InFlightMarker({
    required this.routeKey,
    required this.smokeKey,
    required this.startedAt,
    this.jobId,
  });

  /// Purpose: Parse a marker.
  /// Inputs: [json].
  /// Returns: An [InFlightMarker].
  /// Side effects: None.
  /// Notes: None.
  factory InFlightMarker.fromJson(Map<String, dynamic> json) => InFlightMarker(
    routeKey: json['routeKey'] as String? ?? '',
    smokeKey: json['smokeKey'] as String? ?? '',
    jobId: json['jobId'] as String?,
    startedAt:
        DateTime.tryParse('${json['startedAt']}')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  /// Purpose: Serialize a marker.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'routeKey': routeKey,
    'smokeKey': smokeKey,
    if (jobId != null) 'jobId': jobId,
    'startedAt': startedAt.toUtc().toIso8601String(),
  };
}

/// Keys this build writes at the top level of the state document.
const _knownKeys = {
  'smokeTests',
  'inFlight',
  'routeChoices',
  'fallbackPolicy',
  'allowServerSpeechRecognition',
};

/// The whole `local_engine_state.json` document.
class LocalEngineState {
  /// Check results, by encoded [SmokeTestKey].
  final Map<String, SmokeTestRecord> smokeTests;

  /// The native call that was running, if the app stopped during one.
  final InFlightMarker? inFlight;

  /// The route the user chose per local model id; absent means Auto.
  final Map<String, RouteRequest> routeChoices;

  /// What to do when the chosen route cannot run.
  final FallbackPolicy fallbackPolicy;

  /// Whether the system recogniser may send audio to its vendor's servers.
  ///
  /// Off unless the user turns on the separately worded switch (D15).
  final bool allowServerSpeechRecognition;

  /// Fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a state document.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: The defaults are the state of a device that never ran anything.
  const LocalEngineState({
    this.smokeTests = const {},
    this.inFlight,
    this.routeChoices = const {},
    this.fallbackPolicy = FallbackPolicy.sameModelOnCpu,
    this.allowServerSpeechRecognition = false,
    this.extraJson = const {},
  });

  /// Purpose: Find the check result for a key.
  /// Inputs: [smokeKey], encoded.
  /// Returns: The summary, or [SmokeTestSummary.notRun].
  /// Side effects: None.
  /// Notes: A key with no record has not been checked — which is also what a
  /// changed driver or model looks like, and is exactly why the key has six
  /// parts.
  SmokeTestSummary smokeTestFor(String smokeKey) =>
      smokeTests[smokeKey]?.summary ?? SmokeTestSummary.notRun;

  /// Purpose: Return a copy with some fields replaced.
  /// Inputs: The fields to change, and [clearInFlight].
  /// Returns: A new [LocalEngineState].
  /// Side effects: None.
  /// Notes: None.
  LocalEngineState copyWith({
    Map<String, SmokeTestRecord>? smokeTests,
    InFlightMarker? inFlight,
    bool clearInFlight = false,
    Map<String, RouteRequest>? routeChoices,
    FallbackPolicy? fallbackPolicy,
    bool? allowServerSpeechRecognition,
  }) => LocalEngineState(
    smokeTests: smokeTests ?? this.smokeTests,
    inFlight: clearInFlight ? null : (inFlight ?? this.inFlight),
    routeChoices: routeChoices ?? this.routeChoices,
    fallbackPolicy: fallbackPolicy ?? this.fallbackPolicy,
    allowServerSpeechRecognition:
        allowServerSpeechRecognition ?? this.allowServerSpeechRecognition,
    extraJson: extraJson,
  );

  /// Purpose: Parse the state document.
  /// Inputs: [json].
  /// Returns: A [LocalEngineState].
  /// Side effects: None.
  /// Notes: Every field falls back; an unreadable entry is dropped, which at
  /// worst asks for a check again.
  factory LocalEngineState.fromJson(Map<String, dynamic> json) {
    final smoke = json['smokeTests'];
    final choices = json['routeChoices'];
    final inFlight = json['inFlight'];
    return LocalEngineState(
      smokeTests: {
        if (smoke is Map<String, dynamic>)
          for (final e in smoke.entries)
            if (e.value is Map<String, dynamic>)
              e.key: SmokeTestRecord.fromJson(e.value as Map<String, dynamic>),
      },
      inFlight: inFlight is Map<String, dynamic>
          ? InFlightMarker.fromJson(inFlight)
          : null,
      routeChoices: {
        if (choices is Map<String, dynamic>)
          for (final e in choices.entries)
            if (e.value is String) e.key: RouteRequest(e.value as String),
      },
      fallbackPolicy: FallbackPolicy.parse(json['fallbackPolicy']),
      allowServerSpeechRecognition:
          json['allowServerSpeechRecognition'] == true,
      extraJson: {
        for (final e in json.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Purpose: Serialize the state document.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keys are sorted, so an unchanged state writes the same bytes. The
  /// fallback policy is written only when the user changed it, so a later
  /// build that changes the default changes it for everyone who never did.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'smokeTests': {
      for (final key in (smokeTests.keys.toList()..sort()))
        key: smokeTests[key]!.toJson(),
    },
    if (inFlight != null) 'inFlight': inFlight!.toJson(),
    'routeChoices': {
      for (final key in (routeChoices.keys.toList()..sort()))
        key: routeChoices[key]!.value,
    },
    if (fallbackPolicy != FallbackPolicy.sameModelOnCpu)
      'fallbackPolicy': fallbackPolicy.name,
    if (allowServerSpeechRecognition) 'allowServerSpeechRecognition': true,
  };
}
