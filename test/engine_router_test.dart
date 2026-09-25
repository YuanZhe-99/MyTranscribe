/// Purpose: Test every rule of the engine router, as pure cases.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The worked examples in `doc/en-us/algorithms/engine-routing.md` are
/// these cases. The Auto rule of decision D20 gets the most of them, because
/// it is what decides whether a user's first transcription runs on a GPU
/// nobody here has tested.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/models/local_model_config.dart';
import 'package:my_transcribe/features/local/services/engine_router.dart';
import 'package:my_transcribe/features/local/services/local_asr_engine.dart';
import 'package:my_transcribe/features/providers/models/model_config.dart';

import 'golden/fake_local_asr_engine.dart';

const _whisper = LocalModelConfig(
  id: 'local:whisper',
  displayName: 'Whisper',
  artifacts: {
    'whisper_cpp': ['w-ggml'],
  },
);

const _parakeet = LocalModelConfig(
  id: 'local:parakeet',
  displayName: 'Parakeet',
  languages: ['en', 'de', 'fr'],
  artifacts: {
    'sherpa_onnx': ['p-onnx'],
  },
);

/// Purpose: A route of the Whisper model.
/// Inputs: The route's shape.
/// Returns: An [EngineRoute].
/// Side effects: None.
/// Notes: Internal helper used within this file only.
EngineRoute _w({
  ComputeDevice device = ComputeDevice.cpu,
  String? backend,
  EvidenceLevel evidence = EvidenceLevel.official,
  bool testedHere = false,
  bool available = true,
  SmokeTestOutcome outcome = SmokeTestOutcome.passed,
  double? rtf,
  Capability segmentTimestamps = Capability.supported,
}) => fakeRoute(
  adapterId: 'whisper_cpp',
  modelId: _whisper.id,
  artifactId: 'w-ggml',
  device: device,
  backend: backend,
  evidence: evidence,
  testedHere: testedHere,
  available: available,
  smokeTest: SmokeTestSummary(outcome, realTimeFactor: rtf),
  segmentTimestamps: segmentTimestamps,
);

/// Purpose: Route a Whisper job.
/// Inputs: The [routes], and the request's other parts.
/// Returns: The decision.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
RouteDecision _route(
  List<EngineRoute> routes, {
  RouteRequest requested = RouteRequest.auto,
  FallbackPolicy policy = FallbackPolicy.sameModelOnCpu,
  LocalModelConfig model = _whisper,
  Set<String> installed = const {'w-ggml', 'p-onnx'},
  List<String> languages = const [],
  bool requireSegmentTimestamps = false,
}) => EngineRouter.choose(
  RoutingRequest(
    model: model,
    routes: routes,
    installedArtifacts: installed,
    requested: requested,
    policy: policy,
    languages: languages,
    requireSegmentTimestamps: requireSegmentTimestamps,
  ),
);

void main() {
  final cpu = _w(rtf: 0.5, testedHere: true);

  group('the model', () {
    test('is refused for a language it does not transcribe', () {
      final route = fakeRoute(
        adapterId: 'sherpa_onnx',
        modelId: _parakeet.id,
        artifactId: 'p-onnx',
        smokeTest: const SmokeTestSummary(SmokeTestOutcome.passed),
      );
      final decision = _route([route], model: _parakeet, languages: ['zh']);
      expect(decision.runs, isFalse);
      expect(decision.failure, LocalAsrErrorCode.unsupportedLanguage);
      expect(_route([route], model: _parakeet, languages: ['en']).route, route);
    });

    test('is never swapped for another model', () {
      // Parakeet is installed and passing; the job asked for Whisper, which
      // has no route here. The answer is "not built", not Parakeet.
      final other = fakeRoute(
        adapterId: 'sherpa_onnx',
        modelId: _parakeet.id,
        artifactId: 'p-onnx',
        smokeTest: const SmokeTestSummary(SmokeTestOutcome.passed),
      );
      final decision = _route([other]);
      expect(decision.runs, isFalse);
      expect(decision.failure, LocalAsrErrorCode.backendNotBuilt);
    });

    test('with no package installed at all is "not downloaded" when this '
        'build could run it', () {
      // Adapters describe routes only for installed packages, so here there
      // are none; the adapters the build contains tell the two cases apart.
      final decision = EngineRouter.choose(
        const RoutingRequest(
          model: _whisper,
          routes: [],
          installedArtifacts: {},
          builtAdapters: {'whisper_cpp'},
        ),
      );
      expect(decision.failure, LocalAsrErrorCode.modelMissing);
      final unbuilt = EngineRouter.choose(
        const RoutingRequest(
          model: _whisper,
          routes: [],
          installedArtifacts: {},
          builtAdapters: {'sherpa_onnx'},
        ),
      );
      expect(unbuilt.failure, LocalAsrErrorCode.backendNotBuilt);
    });

    test('that is not downloaded says so', () {
      final decision = _route([cpu], installed: const {});
      expect(decision.failure, LocalAsrErrorCode.modelMissing);
    });
  });

  group('the CPU, asked for by name', () {
    test('is the CPU route', () {
      final gpu = _w(device: ComputeDevice.gpu, testedHere: true, rtf: 0.1);
      expect(_route([cpu, gpu], requested: RouteRequest.cpu).route, cpu);
    });
  });

  group('a route asked for by name', () {
    final gpu = _w(
      device: ComputeDevice.gpu,
      evidence: EvidenceLevel.experimental,
    );

    test('runs when it can, even untested and experimental', () {
      final decision = _route([
        cpu,
        gpu,
      ], requested: RouteRequest.route(gpu.key));
      expect(decision.route, gpu);
      expect(decision.fallback, isNull);
    });

    test('that crashed falls back to the CPU under the default policy', () {
      final crashed = _w(
        device: ComputeDevice.gpu,
        outcome: SmokeTestOutcome.crashed,
      );
      final decision = _route([
        cpu,
        crashed,
      ], requested: RouteRequest.route(crashed.key));
      expect(decision.route, cpu);
      expect(decision.fallback!.reason, LocalAsrErrorCode.routeCrashed);
      expect(decision.fallback!.from, crashed.key);
      expect(decision.rejected[crashed.key], RouteRejection.crashed);
    });

    test('that crashed fails the job when the policy allows nothing', () {
      final crashed = _w(
        device: ComputeDevice.gpu,
        outcome: SmokeTestOutcome.crashed,
      );
      final decision = _route(
        [cpu, crashed],
        requested: RouteRequest.route(crashed.key),
        policy: FallbackPolicy.none,
      );
      expect(decision.runs, isFalse);
      expect(decision.failure, LocalAsrErrorCode.routeCrashed);
    });

    test('whose driver is missing falls back with that reason', () {
      final missing = _w(device: ComputeDevice.gpu, available: false);
      final decision = _route([
        cpu,
        missing,
      ], requested: RouteRequest.route(missing.key));
      expect(decision.route, cpu);
      expect(decision.fallback!.reason, LocalAsrErrorCode.driverMissing);
    });

    test('goes to the system recogniser only when the policy says so', () {
      final failed = _w(
        device: ComputeDevice.gpu,
        outcome: SmokeTestOutcome.failed,
      );
      final system = fakeRoute(
        adapterId: systemRecognizerAdapterId,
        modelId: '',
        artifactId: '',
        backend: 'os',
      );
      final decision = _route(
        [cpu, failed, system],
        requested: RouteRequest.route(failed.key),
        policy: FallbackPolicy.systemRecognizer,
      );
      expect(decision.route, system);
      expect(decision.fallback!.toRouteKey, system.key);
      expect(
        _route([
          cpu,
          failed,
          system,
        ], requested: RouteRequest.route(failed.key)).route,
        cpu,
        reason: 'the default policy stays with the same model',
      );
    });
  });

  group('Auto (D20)', () {
    test('takes an accelerator tested on this kind of device', () {
      final gpu = _w(
        device: ComputeDevice.gpu,
        evidence: EvidenceLevel.experimental,
        testedHere: true,
        rtf: 0.9,
      );
      expect(_route([cpu, gpu]).route, gpu);
    });

    test('takes an untested A or B route that passed and beat the CPU', () {
      for (final evidence in [
        EvidenceLevel.official,
        EvidenceLevel.community,
      ]) {
        final gpu = _w(device: ComputeDevice.gpu, evidence: evidence, rtf: 0.2);
        expect(_route([cpu, gpu]).route, gpu, reason: evidence.name);
      }
    });

    test('leaves an untested B route that was slower than the CPU', () {
      final gpu = _w(
        device: ComputeDevice.gpu,
        evidence: EvidenceLevel.community,
        rtf: 0.8,
      );
      final decision = _route([cpu, gpu]);
      expect(decision.route, cpu);
      expect(decision.rejected[gpu.key], RouteRejection.notFasterThanCpu);
    });

    test('never takes an untested E or U route, however fast', () {
      for (final evidence in [EvidenceLevel.experimental, EvidenceLevel.none]) {
        final gpu = _w(
          device: ComputeDevice.gpu,
          evidence: evidence,
          rtf: 0.01,
        );
        final decision = _route([cpu, gpu]);
        expect(decision.route, cpu, reason: evidence.name);
        expect(decision.rejected[gpu.key], RouteRejection.untestedForAuto);
      }
    });

    test('does not count an unknown speed as a win', () {
      final unmeasured = _w(testedHere: true);
      final gpu = _w(device: ComputeDevice.gpu, rtf: 0.1);
      final decision = _route([unmeasured, gpu]);
      expect(decision.route, unmeasured);
      expect(decision.rejected[gpu.key], RouteRejection.notFasterThanCpu);
    });

    test('waits for an accelerator to pass its check', () {
      final gpu = _w(
        device: ComputeDevice.gpu,
        testedHere: true,
        outcome: SmokeTestOutcome.notRun,
      );
      final decision = _route([cpu, gpu]);
      expect(decision.route, cpu);
      expect(decision.rejected[gpu.key], RouteRejection.notChecked);
    });

    test('prefers a route tested here over a faster untested one', () {
      final tested = _w(
        device: ComputeDevice.gpu,
        backend: 'opencl',
        testedHere: true,
        rtf: 0.4,
      );
      final untested = _w(device: ComputeDevice.npu, backend: 'qnn', rtf: 0.1);
      expect(_route([cpu, tested, untested]).route, tested);
    });

    test('runs an unchecked CPU route after its check', () {
      final unchecked = _w(outcome: SmokeTestOutcome.notRun);
      final decision = _route([unchecked]);
      expect(decision.route, unchecked);
      expect(decision.needsSmokeTest, isTrue);
    });

    test('fails rather than fall to an untested E route without a CPU', () {
      final broken = _w(outcome: SmokeTestOutcome.failed);
      final gpu = _w(
        device: ComputeDevice.gpu,
        evidence: EvidenceLevel.experimental,
        rtf: 0.1,
      );
      final decision = _route([broken, gpu]);
      expect(decision.runs, isFalse);
      expect(decision.rejected[broken.key], RouteRejection.checkFailed);
      expect(decision.rejected[gpu.key], RouteRejection.untestedForAuto);
    });

    test('passes over a route without the timestamps the job needs', () {
      final bare = _w(
        backend: 'cpu-bare',
        segmentTimestamps: Capability.unsupported,
      );
      final decision = _route([bare], requireSegmentTimestamps: true);
      expect(decision.runs, isFalse);
      expect(decision.failure, LocalAsrErrorCode.unsupportedFeature);
      expect(decision.rejected[bare.key], RouteRejection.lacksTimestamps);
    });
  });

  group('a route that fails mid-job', () {
    final gpu = _w(device: ComputeDevice.gpu, testedHere: true, rtf: 0.1);
    RoutingRequest request(FallbackPolicy policy) => RoutingRequest(
      model: _whisper,
      routes: [cpu, gpu],
      installedArtifacts: const {'w-ggml'},
      policy: policy,
    );

    test('moves to the CPU when the device is lost', () {
      final decision = EngineRouter.fallbackAfter(
        request(FallbackPolicy.sameModelOnCpu),
        gpu,
        LocalAsrErrorCode.deviceLost,
      );
      expect(decision.route, cpu);
      expect(decision.fallback!.reason, LocalAsrErrorCode.deviceLost);
    });

    test('fails when the policy allows nothing', () {
      final decision = EngineRouter.fallbackAfter(
        request(FallbackPolicy.none),
        gpu,
        LocalAsrErrorCode.deviceLost,
      );
      expect(decision.failure, LocalAsrErrorCode.deviceLost);
    });

    test('fails for a problem the CPU would have too', () {
      final decision = EngineRouter.fallbackAfter(
        request(FallbackPolicy.sameModelOnCpu),
        gpu,
        LocalAsrErrorCode.modelCorrupt,
      );
      expect(decision.failure, LocalAsrErrorCode.modelCorrupt);
    });

    test('has nowhere to go from the CPU', () {
      final decision = EngineRouter.fallbackAfter(
        request(FallbackPolicy.sameModelOnCpu),
        cpu,
        LocalAsrErrorCode.outOfMemory,
      );
      expect(decision.failure, LocalAsrErrorCode.outOfMemory);
    });
  });

  test('error codes have the wire spelling the docs use', () {
    expect(LocalAsrErrorCode.modelMissing.wire, 'MODEL_MISSING');
    expect(LocalAsrErrorCode.routeCrashed.wire, 'ROUTE_CRASHED');
    expect(
      LocalAsrErrorCode.parse('OUT_OF_MEMORY'),
      LocalAsrErrorCode.outOfMemory,
    );
    expect(EvidenceLevel.parse('bogus'), EvidenceLevel.none);
    expect(EvidenceLevel.community.letter, 'B');
  });
}
