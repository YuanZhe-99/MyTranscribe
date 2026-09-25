/// Purpose: Test the device-local engine state: how check results are keyed,
/// the in-flight marker, and what a marker left behind does at the next start.
/// Inputs: None.
/// Returns: None.
/// Side effects: Writes into a temporary directory.
/// Notes: The marker is the safeguard that turns a native crash into one
/// recorded result instead of a crash on every launch (decision D20), so the
/// cases here are the ones that decide whether a user with an untested GPU
/// can still open the app.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/models/local_engine_state.dart';
import 'package:my_transcribe/features/local/services/local_engine_state_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late File file;
  late LocalEngineStateStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_engine_state_');
    file = File(p.join(root.path, 'local_engine_state.json'));
    store = LocalEngineStateStore(
      file: () async => file,
      clock: () => DateTime.utc(2026, 9, 24, 12),
    );
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  group('a check result', () {
    const key = SmokeTestKey(
      adapterVersion: 'whisper_cpp 1.9.4',
      modelHash: 'abc',
      osVersion: 'Windows 11 26200',
      driverVersion: '31.0.101',
      deviceId: 'Adreno X1-85',
      precision: 'f16',
    );

    test('is filed under all six parts of its key', () async {
      await store.recordSmokeTest(
        key.encode(),
        SmokeTestRecord(
          routeKey: 'whisper_cpp:w:opencl',
          outcome: SmokeTestOutcome.passed,
          checkedAt: DateTime.utc(2026, 9, 24),
          realTimeFactor: 0.2,
        ),
      );
      final state = await store.load();
      expect(state.smokeTestFor(key.encode()).outcome, SmokeTestOutcome.passed);

      // A driver update is a different key, so the route asks for a new check.
      const updated = SmokeTestKey(
        adapterVersion: 'whisper_cpp 1.9.4',
        modelHash: 'abc',
        osVersion: 'Windows 11 26200',
        driverVersion: '31.0.102',
        deviceId: 'Adreno X1-85',
        precision: 'f16',
      );
      expect(
        state.smokeTestFor(updated.encode()).outcome,
        SmokeTestOutcome.notRun,
      );
    });

    test('keeps a separator inside a part from forging another key', () {
      const a = SmokeTestKey(
        adapterVersion: 'a|b',
        modelHash: 'c',
        osVersion: '',
        driverVersion: '',
        deviceId: '',
        precision: '',
      );
      const b = SmokeTestKey(
        adapterVersion: 'a',
        modelHash: 'b|c',
        osVersion: '',
        driverVersion: '',
        deviceId: '',
        precision: '',
      );
      expect(a.encode(), isNot(b.encode()));
    });
  });

  group('the in-flight marker', () {
    test('is written before a call and cleared after it', () async {
      await store.markInFlight(
        routeKey: 'whisper_cpp:w:opencl',
        smokeKey: 'k',
        jobId: 'job-1',
      );
      expect((await store.load()).inFlight!.jobId, 'job-1');
      await store.clearInFlight();
      expect((await store.load()).inFlight, isNull);
      expect(await store.recoverFromCrash(), isNull, reason: 'a clean exit');
    });

    test('left behind marks the route crashed and is cleared', () async {
      await store.recordSmokeTest(
        'k',
        SmokeTestRecord(
          routeKey: 'whisper_cpp:w:opencl',
          outcome: SmokeTestOutcome.passed,
          checkedAt: DateTime.utc(2026, 9, 23),
        ),
      );
      await store.markInFlight(
        routeKey: 'whisper_cpp:w:opencl',
        smokeKey: 'k',
        jobId: 'job-1',
      );
      // The process dies here. At the next start:
      final restarted = LocalEngineStateStore(file: () async => file);
      final marker = await restarted.recoverFromCrash();
      expect(marker!.jobId, 'job-1');
      final state = await restarted.load();
      expect(state.inFlight, isNull);
      expect(state.smokeTestFor('k').outcome, SmokeTestOutcome.crashed);
      expect(state.smokeTests['k']!.reason, contains('stopped'));
      expect(
        await restarted.recoverFromCrash(),
        isNull,
        reason: 'recorded once, not on every start',
      );
    });
  });

  group('the file', () {
    test(
      'is pretty JSON that keeps unknown fields and omits defaults',
      () async {
        await file.writeAsString(
          jsonEncode({
            'futureField': 1,
            'routeChoices': {'local:w': 'cpu'},
          }),
        );
        await store.update(
          (state) => state.copyWith(fallbackPolicy: FallbackPolicy.none),
        );
        final text = await file.readAsString();
        expect(text, contains('\n  "futureField": 1'));
        final json = jsonDecode(text) as Map<String, dynamic>;
        expect(json['fallbackPolicy'], 'none');
        expect(json['routeChoices'], {'local:w': 'cpu'});

        await store.update(
          (state) =>
              state.copyWith(fallbackPolicy: FallbackPolicy.sameModelOnCpu),
        );
        final back = jsonDecode(await file.readAsString()) as Map;
        expect(
          back.containsKey('fallbackPolicy'),
          isFalse,
          reason: 'the default is stored as an absent key',
        );
      },
    );

    test('that is unreadable reads as a device that checked nothing', () async {
      await file.writeAsString('{not json');
      final state = await store.load();
      expect(state.smokeTests, isEmpty);
      expect(state.fallbackPolicy, FallbackPolicy.sameModelOnCpu);
    });

    test('serialises writes that race', () async {
      await Future.wait([
        for (var i = 0; i < 20; i++)
          store.recordSmokeTest(
            'k$i',
            SmokeTestRecord(
              routeKey: 'r$i',
              outcome: SmokeTestOutcome.passed,
              checkedAt: DateTime.utc(2026, 9, 24),
            ),
          ),
      ]);
      expect((await store.load()).smokeTests, hasLength(20));
    });
  });
}
