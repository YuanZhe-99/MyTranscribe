/// Purpose: The small vocabulary every local engine, the router and the pages
/// share: how good the evidence for a route is, where the work actually ran,
/// what the user asked for, and what happened when a route was checked.
/// Inputs: None.
/// Returns: Enums and the `EngineRoute` value type.
/// Side effects: None.
/// Notes: These are in the code, not only in the docs, because "NPU" in a menu
/// is a promise (decision D8 of the local-models plan). Every enum parses an
/// unknown value to its most cautious member rather than throwing, since the
/// values are persisted on the device and on synced job records. See
/// `doc/en-us/features/local-models.md` and
/// `doc/en-us/algorithms/engine-routing.md`.
library;

import '../../providers/models/model_config.dart';

/// How well a route — an engine, a model package and a kind of device — is
/// documented to work.
///
/// Mirrors the survey's grades A, B, E and U. `none` is deliberately not
/// called "unverified": that word belongs to the product, where it means "this
/// project has not tested it on this kind of device", which is
/// [EngineRoute.testedHere].
enum EvidenceLevel {
  /// A: the runtime's or the chip vendor's own documentation covers this model
  /// on this kind of device.
  official,

  /// B: reproducible community results exist.
  community,

  /// E: only the generic backend is documented; nobody has shown this model
  /// on it.
  experimental,

  /// U: nothing found either way.
  none;

  /// Purpose: Parse a persisted evidence level.
  /// Inputs: [value].
  /// Returns: The level; anything unrecognised reads as [none].
  /// Side effects: None.
  /// Notes: The weakest grade is the safe fallback — an unreadable grade must
  /// never make Auto pick a route it would otherwise leave alone.
  static EvidenceLevel parse(Object? value) {
    for (final level in EvidenceLevel.values) {
      if (level.name == value) return level;
    }
    return none;
  }

  /// Purpose: Name the grade the way the survey and the support matrix do.
  /// Inputs: None.
  /// Returns: `A`, `B`, `E` or `U`.
  /// Side effects: None.
  /// Notes: For the diagnostics page and its copied report.
  String get letter => switch (this) {
    official => 'A',
    community => 'B',
    experimental => 'E',
    none => 'U',
  };

  /// Whether Auto may use an accelerator route of this grade that this
  /// project has not tested on this kind of device (D20).
  bool get allowsUntestedAuto => this == official || this == community;
}

/// Where a window of work actually ran, as the runtime reported it.
enum PlacementKind {
  /// Only the CPU.
  cpu,

  /// The graph ran on a GPU.
  gpu,

  /// The graph ran on a neural processor.
  npu,

  /// Parts ran in different places — an encoder on one, a decoder on another.
  mixed,

  /// The runtime did not say. Never replaced by a guess.
  unknown;

  /// Purpose: Parse a persisted placement.
  /// Inputs: [value].
  /// Returns: The placement; anything unrecognised reads as [unknown].
  /// Side effects: None.
  /// Notes: None.
  static PlacementKind parse(Object? value) {
    for (final kind in PlacementKind.values) {
      if (kind.name == value) return kind;
    }
    return unknown;
  }
}

/// The kind of processor a route is built for.
enum ComputeDevice {
  /// The CPU. Every adapter has this route, and it is Auto's floor.
  cpu,

  /// A GPU backend — Metal, OpenCL, Vulkan.
  gpu,

  /// A neural processor — the Neural Engine, Hexagon.
  npu;

  /// Purpose: Parse a persisted device.
  /// Inputs: [value].
  /// Returns: The device; anything unrecognised reads as [cpu].
  /// Side effects: None.
  /// Notes: The CPU is the fallback because it is the one route that exists
  /// everywhere a local model runs at all.
  static ComputeDevice parse(Object? value) {
    for (final device in ComputeDevice.values) {
      if (device.name == value) return device;
    }
    return cpu;
  }
}

/// What the app may do when the route a job asked for cannot run.
///
/// The user's setting, device-local. Whatever it allows is recorded on the job
/// as a visible fallback; nothing is substituted silently (D6).
enum FallbackPolicy {
  /// Fail the job and say why.
  none,

  /// Run the same model on the CPU. The default.
  sameModelOnCpu,

  /// Use the operating system's own recogniser. A different engine, never a
  /// different model under the same name; offered only where the platform has
  /// one.
  systemRecognizer;

  /// Purpose: Parse a persisted policy.
  /// Inputs: [value].
  /// Returns: The policy; anything unrecognised reads as [sameModelOnCpu].
  /// Side effects: None.
  /// Notes: The default is the fallback, so an unreadable value behaves as a
  /// user who never touched the setting.
  static FallbackPolicy parse(Object? value) {
    for (final policy in FallbackPolicy.values) {
      if (policy.name == value) return policy;
    }
    return sameModelOnCpu;
  }
}

/// What a route's check on this device found.
enum SmokeTestOutcome {
  /// Not checked yet under the current key.
  notRun,

  /// Transcribed the check clip close enough to its expected text.
  passed,

  /// Ran, and produced the wrong text or an error.
  failed,

  /// The process died inside the route; found by the in-flight marker at the
  /// next start. Never picked automatically again under this key.
  crashed;

  /// Purpose: Parse a persisted outcome.
  /// Inputs: [value].
  /// Returns: The outcome; anything unrecognised reads as [notRun].
  /// Side effects: None.
  /// Notes: An unreadable outcome asks for a new check rather than trusting
  /// or condemning the route.
  static SmokeTestOutcome parse(Object? value) {
    for (final outcome in SmokeTestOutcome.values) {
      if (outcome.name == value) return outcome;
    }
    return notRun;
  }

  /// Whether a route with this outcome may run a job at all.
  bool get allowsUse => this == passed || this == notRun;
}

/// Where a memory estimate came from.
enum EstimateSource {
  /// Measured on a device of this kind.
  measured,

  /// Stated by the runtime or the package's publisher.
  documented,

  /// Nobody has said.
  unknown;

  /// Purpose: Parse a persisted estimate source.
  /// Inputs: [value].
  /// Returns: The source; anything unrecognised reads as [unknown].
  /// Side effects: None.
  /// Notes: None.
  static EstimateSource parse(Object? value) {
    for (final source in EstimateSource.values) {
      if (source.name == value) return source;
    }
    return unknown;
  }
}

/// Which route the user asked a job to use.
///
/// Auto, the CPU, or one named route. Persisted on the job as a string —
/// `auto`, `cpu`, or a route key — so a job made on one device reads sensibly
/// on another, where that route may not exist.
class RouteRequest {
  /// `auto`, `cpu`, or an [EngineRoute.key].
  final String value;

  /// Purpose: Create a route request from its persisted value.
  /// Inputs: [value].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: An empty value reads as Auto.
  const RouteRequest(String value) : value = value == '' ? 'auto' : value;

  /// Let the router choose (D20).
  static const auto = RouteRequest('auto');

  /// The CPU route, whatever else this device has.
  static const cpu = RouteRequest('cpu');

  /// Purpose: Ask for one named route.
  /// Inputs: [routeKey].
  /// Returns: A request for that route.
  /// Side effects: None.
  /// Notes: None.
  factory RouteRequest.route(String routeKey) => RouteRequest(routeKey);

  /// Whether this is Auto.
  bool get isAuto => value == 'auto';

  /// Whether this is the CPU.
  bool get isCpu => value == 'cpu';

  /// The named route's key, or null for Auto and the CPU.
  String? get routeKey => isAuto || isCpu ? null : value;

  /// Purpose: Compare two requests by value.
  /// Inputs: [other].
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  @override
  bool operator ==(Object other) =>
      other is RouteRequest && other.value == value;

  /// Purpose: Hash a request by value.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: None.
  @override
  int get hashCode => value.hashCode;

  /// Purpose: Render the request for a log or a fingerprint.
  /// Inputs: None.
  /// Returns: The persisted value.
  /// Side effects: None.
  /// Notes: None.
  @override
  String toString() => value;
}

/// What a route's latest check on this device found, as the router needs it.
class SmokeTestSummary {
  /// What the check found.
  final SmokeTestOutcome outcome;

  /// Seconds of work per second of audio in the check, or null when it did not
  /// finish. Lower is faster.
  final double? realTimeFactor;

  /// Why it failed, in words, when it did.
  final String? reason;

  /// Purpose: Create a smoke-test summary.
  /// Inputs: [outcome], optional [realTimeFactor] and [reason].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SmokeTestSummary(this.outcome, {this.realTimeFactor, this.reason});

  /// A route that has not been checked under its current key.
  static const notRun = SmokeTestSummary(SmokeTestOutcome.notRun);
}

/// One way this device could run one model package: an adapter, an artifact,
/// a backend and the processor it drives.
class EngineRoute {
  /// The adapter, e.g. `whisper_cpp` or `sherpa_onnx`.
  final String adapterId;

  /// The model record this route serves.
  final String modelId;

  /// The installed package it would load.
  final String artifactId;

  /// The processor.
  final ComputeDevice device;

  /// The backend name inside the adapter — `cpu`, `metal`, `opencl`,
  /// `vulkan`, `coreml`, `qnn` — so two GPU routes stay apart.
  final String backend;

  /// How well this route is documented to work on this kind of device.
  final EvidenceLevel evidence;

  /// Whether this project verified the route on hardware of this device's
  /// class (D20). From the table in `engine-routing.md`, never from a guess.
  final bool testedHere;

  /// What the check on this device found under the current key.
  final SmokeTestSummary smokeTest;

  /// The key the check's result is filed under; changes when the adapter,
  /// the model, the OS or the driver does.
  final String smokeKey;

  /// Whether the backend was built and its driver answers.
  final bool available;

  /// Why not, in words, when it is not.
  final String? unavailableReason;

  /// Whether the route keeps segment times.
  final Capability segmentTimestamps;

  /// Whether it keeps word times.
  final Capability wordTimestamps;

  /// The longest window it takes, in seconds, or null for no limit of its own.
  final int? maxWindowSeconds;

  /// The memory a loaded session needs, in bytes, or null when unknown.
  final int? memoryBytes;

  /// Where [memoryBytes] came from.
  final EstimateSource memorySource;

  /// Purpose: Create a route.
  /// Inputs: All fields; the identity fields are required.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: Capabilities default to unknown, which is what a route that has
  /// not said anything honestly is.
  const EngineRoute({
    required this.adapterId,
    required this.modelId,
    required this.artifactId,
    required this.device,
    required this.backend,
    required this.evidence,
    this.testedHere = false,
    this.smokeTest = SmokeTestSummary.notRun,
    this.smokeKey = '',
    this.available = true,
    this.unavailableReason,
    this.segmentTimestamps = Capability.unknown,
    this.wordTimestamps = Capability.unknown,
    this.maxWindowSeconds,
    this.memoryBytes,
    this.memorySource = EstimateSource.unknown,
  });

  /// Identifies the route on this device: adapter, artifact and backend.
  ///
  /// Stable across launches, so a job and a setting can name it.
  String get key => '$adapterId:$artifactId:$backend';

  /// Whether this is a CPU route.
  bool get isCpu => device == ComputeDevice.cpu;

  /// Purpose: Return a copy with this device's check result attached.
  /// Inputs: [smokeTest].
  /// Returns: A new [EngineRoute].
  /// Side effects: None.
  /// Notes: Adapters describe routes without knowing what the device's state
  /// file says; the registry attaches the result afterwards.
  EngineRoute withSmokeTest(SmokeTestSummary smokeTest) => EngineRoute(
    adapterId: adapterId,
    modelId: modelId,
    artifactId: artifactId,
    device: device,
    backend: backend,
    evidence: evidence,
    testedHere: testedHere,
    smokeTest: smokeTest,
    smokeKey: smokeKey,
    available: available,
    unavailableReason: unavailableReason,
    segmentTimestamps: segmentTimestamps,
    wordTimestamps: wordTimestamps,
    maxWindowSeconds: maxWindowSeconds,
    memoryBytes: memoryBytes,
    memorySource: memorySource,
  );
}
