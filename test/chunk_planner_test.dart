/// Purpose: Test how a recording is divided before it is sent.
/// Inputs: None.
/// Returns: None.
/// Side effects: None — the planner is pure.
/// Notes: The cases are the ones a user would notice: a short clip that should
/// never touch FFmpeg, a long one that must be split, and the two different
/// reasons a window gets shortened. Each expectation names the limit it is
/// exercising, so a regression says which one moved.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/models/chunk_plan.dart';
import 'package:my_transcribe/features/jobs/services/chunk_planner.dart';
import 'package:my_transcribe/features/media/models/media_info.dart';
import 'package:my_transcribe/features/providers/models/model_config.dart';
import 'package:my_transcribe/features/providers/models/provider_config.dart';

void main() {
  const twentyFive = 25 * 1024 * 1024;

  ProviderConfig provider({int? maxRequestSeconds, int? maxFileBytes}) =>
      ProviderConfig(
        id: 'provider:test',
        name: 'Test',
        dialect: ProviderDialect.openai,
        baseUrl: 'https://api.example.com/v1',
        maxRequestSeconds: maxRequestSeconds,
        maxFileBytes: maxFileBytes ?? twentyFive,
      );

  ModelConfig model({int? maxDurationSeconds, List<String>? inputFormats}) =>
      ModelConfig(
        id: 'model:test',
        providerId: 'provider:test',
        modelName: 'test-model',
        maxFileBytes: twentyFive,
        maxDurationSeconds: maxDurationSeconds,
        inputFormats: inputFormats ?? const ['mp3', 'wav', 'm4a'],
      );

  PlanRequest request({
    required int bytes,
    required double? duration,
    String extension = 'mp3',
    ProviderConfig? source,
    ModelConfig? chosen,
    bool diarize = false,
    bool jsonMode = false,
    double overlap = 5,
    double? userWindow,
    bool toolkit = true,
    bool hasVideo = false,
  }) => PlanRequest(
    sourceBytes: bytes,
    sourceExtension: extension,
    media: duration == null
        ? null
        : MediaInfo(durationSeconds: duration, hasVideo: hasVideo),
    model: chosen ?? model(),
    provider: source ?? provider(),
    diarize: diarize,
    jsonMode: jsonMode,
    overlapSeconds: overlap,
    userWindowSeconds: userWindow,
    toolkitAvailable: toolkit,
  );

  group('the fast path', () {
    test('a short clip goes up untouched', () {
      final result = ChunkPlanner.plan(
        request(bytes: 2 * 1024 * 1024, duration: 120),
      );
      final plan = result.plan!;
      expect(plan.single, isTrue);
      expect(plan.uploadsOriginal, isTrue);
      expect(plan.windows, hasLength(1));
      expect(
        plan.reasons.first.code,
        PlanReasonCode.fitsWhole,
        reason: 'and it says so, rather than leaving the user guessing',
      );
    });

    test('works even with no FFmpeg, which is the point of it', () {
      // A fresh install on Windows has no audio tools until the user sets them
      // up. A short recording still transcribes.
      final result = ChunkPlanner.plan(
        request(bytes: 1024 * 1024, duration: 60, toolkit: false),
      );
      expect(result.isSuccess, isTrue);
      expect(result.plan!.uploadsOriginal, isTrue);
    });

    test('works even when nothing could read the duration', () {
      final result = ChunkPlanner.plan(
        request(bytes: 1024 * 1024, duration: null),
      );
      expect(result.isSuccess, isTrue);
      expect(result.plan!.uploadsOriginal, isTrue);
    });

    test('a format the model does not accept is converted, however small', () {
      final result = ChunkPlanner.plan(
        request(bytes: 1024 * 1024, duration: 60, extension: 'opus'),
      );
      expect(result.plan!.uploadsOriginal, isFalse);
      expect(
        result.plan!.reasons.map((r) => r.code),
        contains(PlanReasonCode.splitByFormat),
      );
    });

    test('a video file is converted, however small', () {
      // The audio is extracted; the video would be uploaded for nothing.
      final result = ChunkPlanner.plan(
        request(bytes: 1024 * 1024, duration: 60, hasVideo: true),
      );
      expect(result.plan!.uploadsOriginal, isFalse);
    });
  });

  group('splitting', () {
    test('a file over the upload limit is split, and says why', () {
      final result = ChunkPlanner.plan(
        request(bytes: 80 * 1024 * 1024, duration: 5400),
      );
      final plan = result.plan!;
      expect(plan.uploadsOriginal, isFalse);
      expect(plan.windows.length, greaterThan(1));
      expect(
        plan.reasons.map((r) => r.code),
        contains(PlanReasonCode.splitBySize),
      );
    });

    test('windows overlap by the requested amount', () {
      final plan = ChunkPlanner.plan(
        request(bytes: 80 * 1024 * 1024, duration: 5400, overlap: 5),
      ).plan!;
      expect(plan.overlapSeconds, 5);
      final first = plan.windows[0];
      final second = plan.windows[1];
      expect(
        first.endSeconds - second.startSeconds,
        closeTo(5, 0.001),
        reason: 'the shared stretch is what the merge removes',
      );
    });

    test('windows cover the whole recording', () {
      final plan = ChunkPlanner.plan(
        request(bytes: 200 * 1024 * 1024, duration: 7200),
      ).plan!;
      expect(plan.windows.first.startSeconds, 0);
      expect(plan.windows.last.endSeconds, closeTo(7200, 0.001));
      for (var i = 1; i < plan.windows.length; i++) {
        expect(
          plan.windows[i].startSeconds,
          lessThan(plan.windows[i - 1].endSeconds),
          reason: 'window $i leaves a gap',
        );
      }
    });

    test('the byte budget sets the window when nothing else does', () {
      // 24 MiB at 8000 bytes a second, with the margin, is about 48 minutes.
      final plan = ChunkPlanner.plan(
        request(bytes: 500 * 1024 * 1024, duration: 20000),
      ).plan!;
      expect(plan.strideSeconds, lessThanOrEqualTo(maxAutoWindowSeconds));
      expect(
        plan.reasons.map((r) => r.code),
        anyOf(
          contains(PlanReasonCode.windowCappedBySize),
          contains(PlanReasonCode.windowCappedByCeiling),
        ),
      );
    });

    test("a model's audio cap shortens the window", () {
      final plan = ChunkPlanner.plan(
        request(
          bytes: 200 * 1024 * 1024,
          duration: 7200,
          chosen: model(maxDurationSeconds: 1500),
        ),
      ).plan!;
      expect(plan.strideSeconds, lessThanOrEqualTo(1500 * 0.95));
      expect(
        plan.reasons.map((r) => r.code),
        contains(PlanReasonCode.windowCappedByModel),
      );
    });

    test("a gateway's request cap shortens it further", () {
      // The cap belongs to the provider and applies to every model behind it.
      final plan = ChunkPlanner.plan(
        request(
          bytes: 200 * 1024 * 1024,
          duration: 7200,
          source: provider(maxRequestSeconds: 600),
          chosen: model(maxDurationSeconds: 1500),
        ),
      ).plan!;
      expect(plan.strideSeconds, lessThanOrEqualTo(600 * 0.95));
      expect(
        plan.reasons.map((r) => r.code),
        contains(PlanReasonCode.windowCappedByProvider),
      );
    });

    test('a gateway cap splits a recording that would otherwise fit', () {
      // Ten minutes of audio is well under 24 MiB, but the gateway gives up
      // after 600 seconds, so it still has to be divided.
      final result = ChunkPlanner.plan(
        request(
          bytes: 9 * 1024 * 1024,
          duration: 900,
          extension: 'opus',
          source: provider(maxRequestSeconds: 600),
        ),
      );
      expect(result.plan!.windows.length, greaterThan(1));
    });

    test('JSON mode lowers the size a file may be to go up untouched', () {
      // Base64 inflates the body by a third, so a file that fits a multipart
      // upload may not fit inside a JSON document. Twenty megabytes is between
      // the two budgets, so it takes the fast path one way and not the other.
      const twentyMegabytes = 20 * 1024 * 1024;
      expect(
        ChunkPlanner.plan(
          request(bytes: twentyMegabytes, duration: 1200),
        ).plan!.uploadsOriginal,
        isTrue,
      );
      expect(
        ChunkPlanner.plan(
          request(bytes: twentyMegabytes, duration: 1200, jsonMode: true),
        ).plan!.uploadsOriginal,
        isFalse,
      );
    });

    test(
      'the ceiling on a single request binds before the byte budget does',
      () {
        // Worth pinning: 1500 seconds of normalized audio is about 11 MB, which
        // is under both byte budgets, so the ceiling is what actually decides a
        // window length whenever no model or gateway caps it lower. The byte
        // budgets still decide the fast path above.
        final plan = ChunkPlanner.plan(
          request(bytes: 500 * 1024 * 1024, duration: 20000),
        ).plan!;
        expect(plan.strideSeconds + plan.overlapSeconds, maxAutoWindowSeconds);
        expect(
          plan.reasons.map((r) => r.code),
          contains(PlanReasonCode.windowCappedByCeiling),
        );
      },
    );

    test('a longer overlap is used when speakers were asked for', () {
      final plan = ChunkPlanner.plan(
        request(
          bytes: 80 * 1024 * 1024,
          duration: 5400,
          diarize: true,
          overlap: 20,
        ),
      ).plan!;
      expect(plan.overlapSeconds, 20);
      expect(
        plan.reasons.map((r) => r.code),
        contains(PlanReasonCode.overlapForSpeakers),
      );
    });

    test('a window the user chose is used and reported', () {
      final plan = ChunkPlanner.plan(
        request(bytes: 200 * 1024 * 1024, duration: 7200, userWindow: 300),
      ).plan!;
      expect(plan.strideSeconds, 300);
      expect(
        plan.reasons.map((r) => r.code),
        contains(PlanReasonCode.windowChosenByUser),
      );
    });

    test('a window the user chose is still clamped to something workable', () {
      final plan = ChunkPlanner.plan(
        request(bytes: 200 * 1024 * 1024, duration: 7200, userWindow: 1),
      ).plan!;
      expect(plan.strideSeconds, greaterThanOrEqualTo(minStrideSeconds));
    });

    test('a short final window is folded into the one before it', () {
      // A three-second window is a round trip that returns almost nothing and
      // usually ends mid-word.
      final plan = ChunkPlanner.plan(
        request(
          bytes: 200 * 1024 * 1024,
          duration: 605,
          userWindow: 300,
          source: provider(maxRequestSeconds: 600),
        ),
      ).plan!;
      for (final window in plan.windows) {
        expect(
          window.lengthSeconds,
          greaterThanOrEqualTo(minLastWindowSeconds),
          reason: 'window ${window.index} is too short to be worth a request',
        );
      }
    });
  });

  group('when a plan cannot be made', () {
    test('says so when the audio tools are missing', () {
      final result = ChunkPlanner.plan(
        request(bytes: 80 * 1024 * 1024, duration: 5400, toolkit: false),
      );
      expect(result.isSuccess, isFalse);
      expect(result.failure, PlanFailure.mediaToolkitMissing);
    });

    test('says so when the duration is unknown and splitting is needed', () {
      final result = ChunkPlanner.plan(
        request(bytes: 80 * 1024 * 1024, duration: null),
      );
      expect(result.failure, PlanFailure.durationUnknown);
    });

    test('says so when the file has no audio', () {
      final result = ChunkPlanner.plan(
        PlanRequest(
          sourceBytes: 1024,
          sourceExtension: 'mp3',
          media: const MediaInfo(durationSeconds: 0),
          model: model(),
          provider: provider(),
          overlapSeconds: 5,
          toolkitAvailable: true,
        ),
      );
      expect(result.failure, PlanFailure.noAudio);
    });
  });

  group('the fingerprint', () {
    test('changes when a setting that invalidates a result changes', () {
      final base = ChunkPlanner.plan(
        request(bytes: 80 * 1024 * 1024, duration: 5400),
      ).plan!;
      final withSpeakers = ChunkPlanner.plan(
        request(
          bytes: 80 * 1024 * 1024,
          duration: 5400,
          diarize: true,
          overlap: 20,
        ),
      ).plan!;
      expect(withSpeakers.fingerprint, isNot(base.fingerprint));
    });

    test('is stable for the same settings, so a resume reuses its work', () {
      final first = ChunkPlanner.plan(
        request(bytes: 80 * 1024 * 1024, duration: 5400),
      ).plan!;
      final second = ChunkPlanner.plan(
        request(bytes: 80 * 1024 * 1024, duration: 5400),
      ).plan!;
      expect(second.fingerprint, first.fingerprint);
    });
  });

  group('shrinking after a window came out too large', () {
    test('produces a shorter stride and covers the recording', () {
      final original = ChunkPlanner.plan(
        request(bytes: 200 * 1024 * 1024, duration: 7200),
      ).plan!;
      final smaller = ChunkPlanner.shrink(
        original,
        request(bytes: 200 * 1024 * 1024, duration: 7200),
        7200,
      )!;
      expect(smaller.strideSeconds, lessThan(original.strideSeconds));
      expect(smaller.windows.last.endSeconds, closeTo(7200, 0.001));
      expect(
        smaller.fingerprint,
        isNot(original.fingerprint),
        reason: 're-planning must not reuse the old windows results',
      );
    });

    test('gives up rather than shrinking below a useful stride', () {
      final tiny = ChunkPlan(
        single: false,
        uploadsOriginal: false,
        strideSeconds: minStrideSeconds.toDouble(),
        overlapSeconds: 5,
        windows: const [],
        predictedChunkBytes: 0,
        fingerprint: 'x',
      );
      expect(
        ChunkPlanner.shrink(tiny, request(bytes: 1, duration: 100), 100),
        isNull,
      );
    });
  });
}
