/// Purpose: Test what each dialect actually puts on the wire, and what it makes
/// of a reply.
/// Inputs: None; a fake server records the requests.
/// Returns: None.
/// Side effects: Creates a temporary audio file to upload.
/// Notes: These are the differences that cost a whole job when they are wrong:
/// a language sent as a string where a list was wanted, a diarizing request
/// without its chunking strategy, a prompt sent to a gateway that drops it. No
/// API key and no network are involved.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/providers/models/model_config.dart';
import 'package:my_transcribe/features/providers/models/provider_config.dart';
import 'package:my_transcribe/features/providers/services/provider_dialect.dart';
import 'package:my_transcribe/features/providers/services/transcription_client.dart';
import 'package:path/path.dart' as p;

import 'golden/fake_transcription_server.dart';

void main() {
  late Directory work;
  late File audio;

  setUp(() async {
    work = await Directory.systemTemp.createTemp('mytranscribe_dialect_');
    audio = File(p.join(work.path, 'chunk_0000.mp3'))
      ..writeAsBytesSync(List.filled(2048, 7));
  });

  tearDown(() async {
    try {
      await work.delete(recursive: true);
    } catch (_) {}
  });

  ProviderConfig source(
    ProviderDialect dialect, {
    AuthScheme auth = AuthScheme.bearer,
    String? headerName,
  }) => ProviderConfig(
    id: 'provider:test',
    name: 'Test',
    dialect: dialect,
    baseUrl: 'https://api.example.com/v1',
    authScheme: auth,
    authHeaderName: headerName,
  );

  ModelConfig model({
    String name = 'test-model',
    Capability diarization = Capability.unsupported,
    Capability segments = Capability.unsupported,
    bool prompt = false,
    bool keywords = false,
    LanguageParamStyle languageStyle = LanguageParamStyle.language,
    List<String> formats = const ['json'],
    bool chunkingStrategy = false,
    int? maxKnownSpeakers,
  }) => ModelConfig(
    id: 'model:test',
    providerId: 'provider:test',
    modelName: name,
    diarization: diarization,
    segmentTimestamps: segments,
    supportsPrompt: prompt,
    supportsKeywords: keywords,
    languageParamStyle: languageStyle,
    responseFormats: formats,
    requiresChunkingStrategy: chunkingStrategy,
    maxKnownSpeakers: maxKnownSpeakers,
  );

  Future<RecordedRequest> send({
    required ProviderConfig provider,
    required ModelConfig chosen,
    required FakeTranscriptionServer server,
    List<String> languages = const [],
    String? prompt,
    List<String> keywords = const [],
    bool diarize = false,
    bool wantTimestamps = true,
    String? apiKey = 'sk-test',
    List<KnownSpeaker> knownSpeakers = const [],
  }) async {
    final client = TranscriptionClient(
      clientFactory: () => server,
      sleep: (_) async {},
    );
    await client.transcribe(
      request: TranscriptionRequest(
        file: audio,
        mimeType: 'audio/mpeg',
        languages: languages,
        prompt: prompt,
        keywords: keywords,
        diarize: diarize,
        wantTimestamps: wantTimestamps,
        knownSpeakers: knownSpeakers,
      ),
      provider: provider,
      model: chosen,
      apiKey: apiKey,
      windowSeconds: 600,
    );
    return server.requests.single;
  }

  group('the OpenAI dialect', () {
    test('sends the file, the model and the format as multipart', () async {
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(ProviderDialect.openai),
        chosen: model(),
        server: server,
      );

      expect(request.isJson, isFalse);
      expect(request.url.path, endsWith('/audio/transcriptions'));
      expect(request.field('model'), 'test-model');
      expect(request.field('response_format'), 'json');
      expect(request.fileNames['file'], 'chunk_0000.mp3');
      expect(request.headers['Authorization'], 'Bearer sk-test');
    });

    test(
      'sends a language list as a list for a model that takes one',
      () async {
        // The single difference that makes gpt-transcribe work: it wants
        // `languages[]`, and rejects the singular field the others use.
        final server = FakeTranscriptionServer([FakeReply.text('hello')]);
        final request = await send(
          provider: source(ProviderDialect.openai),
          chosen: model(languageStyle: LanguageParamStyle.languages),
          server: server,
          languages: const ['en', 'zh'],
        );

        expect(request.valuesOf('languages[]'), ['en', 'zh']);
        expect(request.field('language'), isNull);
      },
    );

    test('sends a single language code for a model that takes one', () async {
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(ProviderDialect.openai),
        chosen: model(languageStyle: LanguageParamStyle.language),
        server: server,
        languages: const ['en', 'zh'],
      );

      expect(request.field('language'), 'en');
      expect(request.valuesOf('languages[]'), isEmpty);
    });

    test('omits a prompt the model does not accept', () async {
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(ProviderDialect.openai),
        chosen: model(prompt: false),
        server: server,
        prompt: 'a lecture about linear algebra',
      );
      expect(request.field('prompt'), isNull);
    });

    test('sends keywords as repeated parts where they are accepted', () async {
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(ProviderDialect.openai),
        chosen: model(keywords: true),
        server: server,
        keywords: const ['eigenvector', 'Gram-Schmidt'],
      );
      expect(request.valuesOf('keywords[]'), ['eigenvector', 'Gram-Schmidt']);
    });

    test('a diarizing request carries its chunking strategy', () async {
      // Without it the endpoint refuses anything over half a minute, which is
      // every window this app produces.
      final server = FakeTranscriptionServer([
        FakeReply.diarized([(0, 5, 'A', 'hello')]),
      ]);
      final request = await send(
        provider: source(ProviderDialect.openai),
        chosen: model(
          diarization: Capability.supported,
          formats: const ['diarized_json', 'json'],
          chunkingStrategy: true,
        ),
        server: server,
        diarize: true,
      );

      expect(request.field('response_format'), 'diarized_json');
      expect(request.field('chunking_strategy'), 'auto');
    });

    test('carries speaker samples, capped at what the model accepts', () async {
      final sample = File(p.join(work.path, 'spk.wav'))
        ..writeAsBytesSync([1, 2, 3, 4]);
      final server = FakeTranscriptionServer([
        FakeReply.diarized([(0, 5, 'spk_1', 'hello')]),
      ]);
      final request = await send(
        provider: source(ProviderDialect.openai),
        chosen: model(
          diarization: Capability.supported,
          formats: const ['diarized_json'],
          maxKnownSpeakers: 1,
        ),
        server: server,
        diarize: true,
        knownSpeakers: [
          KnownSpeaker(id: 'spk_1', sample: sample),
          KnownSpeaker(id: 'spk_2', sample: sample),
        ],
      );

      expect(request.field('known_speaker_names[]'), 'spk_1');
      expect(
        request.field('known_speaker_references[]'),
        startsWith('data:audio/wav;base64,'),
      );
    });

    test('asks for times only where the model states it has them', () async {
      final withTimes = FakeTranscriptionServer([
        FakeReply.timed([(0, 5, 'hello')]),
      ]);
      final request = await send(
        provider: source(ProviderDialect.openai),
        chosen: model(
          segments: Capability.supported,
          formats: const ['verbose_json', 'json'],
        ),
        server: withTimes,
      );
      expect(request.field('response_format'), 'verbose_json');
      expect(request.field('timestamp_granularities[]'), 'segment');

      final without = FakeTranscriptionServer([FakeReply.text('hello')]);
      final plain = await send(
        provider: source(ProviderDialect.openai),
        chosen: model(segments: Capability.unsupported),
        server: without,
      );
      expect(plain.field('response_format'), 'json');
    });
  });

  group('the OpenRouter dialect', () {
    test('uses multipart when nothing needs a provider option', () async {
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(ProviderDialect.openrouter),
        chosen: model(),
        server: server,
      );
      expect(request.isJson, isFalse);
      expect(request.field('model'), 'test-model');
    });

    test('switches to JSON to ask for speakers', () async {
      // The gateway's provider options exist only in JSON mode, which is why
      // the planner has to know before it sizes a window.
      final server = FakeTranscriptionServer([
        FakeReply.diarized([(0, 5, 'S0', 'hello')]),
      ]);
      final request = await send(
        provider: source(ProviderDialect.openrouter),
        chosen: model(
          diarization: Capability.supported,
          segments: Capability.supported,
          formats: const ['verbose_json', 'json'],
        ),
        server: server,
        diarize: true,
      );

      expect(request.isJson, isTrue);
      expect(request.json!['model'], 'test-model');
      expect(request.json!['provider'], {
        'options': {
          'azure': {
            'diarization': {'enabled': true},
          },
        },
      });
      final audioField = request.json!['input_audio'] as Map<String, dynamic>;
      expect(audioField['format'], 'mp3');
      expect(base64Decode(audioField['data'] as String), hasLength(2048));
    });

    test('sends keywords as a phrase list, in JSON', () async {
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(ProviderDialect.openrouter),
        chosen: model(keywords: true, formats: const ['verbose_json', 'json']),
        server: server,
        keywords: const ['eigenvector'],
      );

      expect(request.isJson, isTrue);
      final options =
          (request.json!['provider'] as Map)['options'] as Map<String, dynamic>;
      expect((options['azure'] as Map)['phraseList'], {
        'phrases': ['eigenvector'],
      });
    });

    test('never sends a prompt, because the gateway drops it', () async {
      // Accepting a prompt and silently discarding it is worse than refusing
      // it, so the templates mark these models as not taking one and the
      // dialect never sends one either way.
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(ProviderDialect.openrouter),
        chosen: model(prompt: true),
        server: server,
        prompt: 'a lecture',
      );
      expect(request.field('prompt'), isNull);
    });
  });

  group('the compatible dialect', () {
    test('sends the smallest request a local server would accept', () async {
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(
          ProviderDialect.openaiCompatible,
          auth: AuthScheme.none,
        ),
        chosen: model(),
        server: server,
        apiKey: null,
      );

      expect(request.field('model'), 'test-model');
      expect(request.field('response_format'), 'json');
      expect(
        request.headers.containsKey('Authorization'),
        isFalse,
        reason: 'a server with no authentication must not be sent a header',
      );
    });

    test('uses a custom header when the source names one', () async {
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(
          ProviderDialect.openaiCompatible,
          auth: AuthScheme.header,
          headerName: 'X-Api-Key',
        ),
        chosen: model(),
        server: server,
      );
      expect(request.headers['X-Api-Key'], 'sk-test');
      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('does not ask for times a model has not claimed', () async {
      // For a server the user configured themselves this is usually unknown,
      // and asking for a format it does not have costs a round trip.
      final server = FakeTranscriptionServer([FakeReply.text('hello')]);
      final request = await send(
        provider: source(ProviderDialect.openaiCompatible),
        chosen: model(segments: Capability.unknown),
        server: server,
      );
      expect(request.field('response_format'), 'json');
    });
  });

  group('reading replies', () {
    Future<TranscriptionResult> read(FakeReply reply) async {
      final server = FakeTranscriptionServer([reply]);
      final client = TranscriptionClient(
        clientFactory: () => server,
        sleep: (_) async {},
      );
      return client.transcribe(
        request: TranscriptionRequest(file: audio, mimeType: 'audio/mpeg'),
        provider: source(ProviderDialect.openai),
        model: model(),
        apiKey: 'sk-test',
        windowSeconds: 600,
      );
    }

    test(
      'a plain transcript becomes one segment covering the window',
      () async {
        final result = await read(FakeReply.text('the whole window'));
        expect(result.text, 'the whole window');
        expect(result.hasRealTimestamps, isFalse);
        expect(result.segments.single.endSeconds, 600);
      },
    );

    test('a timed transcript keeps its segments', () async {
      final result = await read(
        FakeReply.timed([(0, 5, 'first'), (5, 9, 'second')]),
      );
      expect(result.hasRealTimestamps, isTrue);
      expect(result.segments.map((s) => s.text), ['first', 'second']);
      expect(result.segments.last.startSeconds, 5);
    });

    test('a diarized transcript keeps its speaker labels', () async {
      final result = await read(
        FakeReply.diarized([(0, 5, 'A', 'hello'), (5, 9, 'B', 'hi')]),
      );
      expect(result.hasSpeakers, isTrue);
      expect(result.segments.map((s) => s.speaker), ['A', 'B']);
    });

    test('a numeric speaker label becomes a distinguishable string', () async {
      // One service labels speakers with integers. Zero must not be mistaken
      // for "no speaker" anywhere downstream.
      final result = await read(
        FakeReply(
          jsonEncode({
            'text': 'hello',
            'segments': [
              {'start': 0, 'end': 5, 'speaker': 0, 'text': 'hello'},
            ],
          }),
        ),
      );
      expect(result.segments.single.speaker, 'S0');
    });

    test('plain text that is not JSON is still a transcript', () async {
      final result = await read(const FakeReply('just some words'));
      expect(result.text, 'just some words');
    });

    test('an empty reply is an error, not an empty transcript', () async {
      // A window that silently produced nothing is indistinguishable from
      // silence, and would be merged in as a gap nobody could explain.
      await expectLater(
        read(const FakeReply('')),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.failure,
            'failure',
            TranscriptionFailure.badResponse,
          ),
        ),
      );
    });
  });

  group('failures', () {
    Future<void> expectFailure(
      FakeReply reply,
      TranscriptionFailure expected, {
      int replies = 1,
    }) async {
      final server = FakeTranscriptionServer(List.filled(replies, reply));
      final client = TranscriptionClient(
        clientFactory: () => server,
        sleep: (_) async {},
      );
      await expectLater(
        client.transcribe(
          request: TranscriptionRequest(file: audio, mimeType: 'audio/mpeg'),
          provider: source(ProviderDialect.openai),
          model: model(),
          apiKey: 'sk-test',
          windowSeconds: 600,
        ),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.failure,
            'failure',
            expected,
          ),
        ),
      );
    }

    test('a rejected key is not retried', () async {
      final server = FakeTranscriptionServer([
        FakeReply.error(401, 'Incorrect API key provided'),
      ]);
      final client = TranscriptionClient(
        clientFactory: () => server,
        sleep: (_) async {},
      );
      await expectLater(
        client.transcribe(
          request: TranscriptionRequest(file: audio, mimeType: 'audio/mpeg'),
          provider: source(ProviderDialect.openai),
          model: model(),
          apiKey: 'sk-wrong',
          windowSeconds: 600,
        ),
        throwsA(isA<TranscriptionException>()),
      );
      expect(
        server.requests,
        hasLength(1),
        reason: 'a wrong key will not become right on the second try',
      );
    });

    test('the server\'s own message is what the user sees', () async {
      final server = FakeTranscriptionServer([
        FakeReply.error(400, 'Unsupported audio format: opus'),
      ]);
      final client = TranscriptionClient(
        clientFactory: () => server,
        sleep: (_) async {},
      );
      await expectLater(
        client.transcribe(
          request: TranscriptionRequest(file: audio, mimeType: 'audio/mpeg'),
          provider: source(ProviderDialect.openai),
          model: model(),
          apiKey: 'sk-test',
          windowSeconds: 600,
        ),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Unsupported audio format: opus',
          ),
        ),
      );
    });

    test('a server error is retried, then given up on', () async {
      final server = FakeTranscriptionServer([
        FakeReply.error(503, 'temporarily unavailable'),
      ]);
      final client = TranscriptionClient(
        clientFactory: () => server,
        sleep: (_) async {},
      );
      await expectLater(
        client.transcribe(
          request: TranscriptionRequest(file: audio, mimeType: 'audio/mpeg'),
          provider: source(ProviderDialect.openai),
          model: model(),
          apiKey: 'sk-test',
          windowSeconds: 600,
        ),
        throwsA(isA<TranscriptionException>()),
      );
      expect(server.requests, hasLength(maxTranscriptionRetries + 1));
    });

    test('a transient error that clears is not a failure', () async {
      final server = FakeTranscriptionServer([
        FakeReply.error(500, 'oops'),
        FakeReply.text('it worked the second time'),
      ]);
      final client = TranscriptionClient(
        clientFactory: () => server,
        sleep: (_) async {},
      );
      final result = await client.transcribe(
        request: TranscriptionRequest(file: audio, mimeType: 'audio/mpeg'),
        provider: source(ProviderDialect.openai),
        model: model(),
        apiKey: 'sk-test',
        windowSeconds: 600,
      );
      expect(result.text, 'it worked the second time');
    });

    test('a refusal that names a feature says which one', () async {
      // So the job can offer "run again without speaker labels" rather than
      // making the user find the setting.
      final server = FakeTranscriptionServer([
        FakeReply.error(400, 'diarization is not supported for this model'),
      ]);
      final client = TranscriptionClient(
        clientFactory: () => server,
        sleep: (_) async {},
      );
      await expectLater(
        client.transcribe(
          request: TranscriptionRequest(
            file: audio,
            mimeType: 'audio/mpeg',
            diarize: true,
          ),
          provider: source(ProviderDialect.openai),
          model: model(diarization: Capability.unknown),
          apiKey: 'sk-test',
          windowSeconds: 600,
        ),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.rejectedFeature,
            'rejectedFeature',
            RejectedFeature.diarization,
          ),
        ),
      );
    });

    test('a rate limit is reported as one', () async {
      await expectFailure(
        FakeReply.error(429, 'slow down'),
        TranscriptionFailure.rateLimited,
        replies: maxTranscriptionRetries + 1,
      );
    });

    test('an upload that is too large is reported as one', () async {
      await expectFailure(
        FakeReply.error(413, 'file too large'),
        TranscriptionFailure.tooLarge,
      );
    });
  });
}
