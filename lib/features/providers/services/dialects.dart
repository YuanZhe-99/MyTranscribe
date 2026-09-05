/// Purpose: The three request shapes the app can speak.
/// Inputs: A normalized request, a source and a model.
/// Returns: `ProviderDialectHandler` implementations, and a lookup for them.
/// Side effects: None here; the handlers open the audio file when building a
/// request.
/// Notes: The differences between these are not cosmetic. One takes a list of
/// languages where the others take a code; one drops a prompt silently; one can
/// only reach speaker labels through a JSON body. Each is written down where it
/// applies rather than as a note somewhere else. See
/// `doc/en-us/features/provider-library.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'provider_dialect.dart';
import 'response_parsers.dart';

/// The path every one of these endpoints exposes.
const transcriptionPath = 'audio/transcriptions';

/// Purpose: Pick the handler for a source.
/// Inputs: [dialect].
/// Returns: The handler.
/// Side effects: None.
/// Notes: Every dialect has exactly one handler, so a source's `dialect` field
/// fully determines how its requests are shaped.
ProviderDialectHandler dialectHandler(ProviderDialect dialect) =>
    switch (dialect) {
      ProviderDialect.openai => const OpenAiDialect(),
      ProviderDialect.openrouter => const OpenRouterDialect(),
      ProviderDialect.openaiCompatible => const OpenAiCompatibleDialect(),
    };

/// The official OpenAI audio API.
class OpenAiDialect extends ProviderDialectHandler {
  /// Purpose: Create the dialect.
  /// Inputs: None.
  /// Returns: A new handler.
  /// Side effects: None.
  /// Notes: None.
  const OpenAiDialect();

  /// Purpose: Choose the reply format.
  /// Inputs: [request], [model].
  /// Returns: The format name.
  /// Side effects: None.
  /// Notes: Speaker labels come back only in the diarized format, and only from
  /// the model that produces it. Otherwise the verbose format is asked for when
  /// times are wanted and the model states it can return them.
  @override
  String responseFormatFor(TranscriptionRequest request, ModelConfig model) {
    if (request.diarize && model.diarization != Capability.unsupported) {
      return model.chooseResponseFormat(const ['diarized_json', 'json']);
    }
    if (request.wantTimestamps &&
        model.segmentTimestamps == Capability.supported) {
      return model.chooseResponseFormat(const ['verbose_json', 'json']);
    }
    return model.chooseResponseFormat(const ['json']);
  }

  /// Purpose: Build the multipart request.
  /// Inputs: [request], [provider], [model], [apiKey].
  /// Returns: A streamed multipart request.
  /// Side effects: Opens the audio file.
  /// Notes: Three things here are model-specific and would be wrong if applied
  /// generally. The language hint is a **list** for a model that takes one and
  /// a single code otherwise. A diarizing request must state a chunking
  /// strategy, or the endpoint refuses anything over half a minute. And speaker
  /// references travel as data URLs beside the names they belong to, capped at
  /// what the model accepts.
  @override
  Future<http.BaseRequest> buildRequest(
    TranscriptionRequest request,
    ProviderConfig provider,
    ModelConfig model,
    String? apiKey,
  ) async {
    final uri = Uri.parse(provider.endpoint(transcriptionPath));
    final multipart = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        ...provider.extraHeaders,
        ...authHeaders(provider, apiKey),
      })
      ..fields['model'] = model.modelName;

    final format = responseFormatFor(request, model);
    multipart.fields['response_format'] = format;

    if (model.supportsPrompt && (request.prompt?.isNotEmpty ?? false)) {
      multipart.fields['prompt'] = request.prompt!;
    }
    if (model.supportsKeywords) {
      for (final keyword in request.keywords) {
        multipart.files.add(
          http.MultipartFile.fromString('keywords[]', keyword),
        );
      }
    }

    _addLanguage(multipart, request, model);

    if (format == 'diarized_json') {
      if (model.requiresChunkingStrategy) {
        // Without this the endpoint refuses anything past half a minute, which
        // is every window this app produces.
        multipart.fields['chunking_strategy'] = 'auto';
      }
      final limit = model.maxKnownSpeakers ?? 0;
      for (final speaker in request.knownSpeakers.take(limit)) {
        multipart.fields['known_speaker_names[]'] = speaker.id;
        final bytes = await speaker.sample.readAsBytes();
        multipart.fields['known_speaker_references[]'] =
            'data:audio/wav;base64,${base64Encode(bytes)}';
      }
    } else if (request.wantTimestamps &&
        model.segmentTimestamps == Capability.supported &&
        format == 'verbose_json') {
      multipart.fields['timestamp_granularities[]'] = 'segment';
    }

    multipart.files.add(
      await http.MultipartFile.fromPath(
        'file',
        request.file.path,
        filename: _fileName(request.file),
      ),
    );
    return multipart;
  }

  /// Purpose: Read a reply.
  /// Inputs: [body], [format].
  /// Returns: A [TranscriptionResult].
  /// Side effects: None.
  /// Notes: The window length is not known here, so a text-only reply gets a
  /// zero-length segment; the job replaces it with the window's own bounds.
  @override
  TranscriptionResult parseResponse(String body, String format) =>
      parseTranscriptionBody(body, format, 0);
}

/// A gateway that is OpenAI-compatible for the simple case.
class OpenRouterDialect extends ProviderDialectHandler {
  /// Purpose: Create the dialect.
  /// Inputs: None.
  /// Returns: A new handler.
  /// Side effects: None.
  /// Notes: None.
  const OpenRouterDialect();

  /// Purpose: Choose the reply format.
  /// Inputs: [request], [model].
  /// Returns: The format name.
  /// Side effects: None.
  /// Notes: Some models behind this gateway reject the verbose format outright,
  /// which is why the model's own list decides rather than the request.
  @override
  String responseFormatFor(TranscriptionRequest request, ModelConfig model) {
    final wantsDetail =
        request.diarize ||
        (request.wantTimestamps &&
            model.segmentTimestamps != Capability.unsupported);
    return wantsDetail
        ? model.chooseResponseFormat(const ['verbose_json', 'json'])
        : model.chooseResponseFormat(const ['json']);
  }

  /// Purpose: Say whether this request needs a JSON body.
  /// Inputs: [request], [model].
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: **The gateway's provider options exist only in JSON mode.** Speaker
  /// labels and keyword biasing are provider options, so asking for either
  /// forces the audio to travel as base64 — which is why the planner needs to
  /// know before it sizes a window.
  @override
  bool needsJsonBody(TranscriptionRequest request, ModelConfig model) =>
      (request.diarize && model.diarization != Capability.unsupported) ||
      (model.supportsKeywords && request.keywords.isNotEmpty);

  /// Purpose: Build the request, as multipart or as JSON.
  /// Inputs: [request], [provider], [model], [apiKey].
  /// Returns: A request ready to send.
  /// Side effects: Reads the audio file when a JSON body is needed.
  /// Notes: A prompt is never sent. The gateway accepts the field and drops it,
  /// and showing a user their context being accepted and silently discarded is
  /// worse than not offering it — which is why the templates mark these models
  /// as not supporting one.
  @override
  Future<http.BaseRequest> buildRequest(
    TranscriptionRequest request,
    ProviderConfig provider,
    ModelConfig model,
    String? apiKey,
  ) async {
    final uri = Uri.parse(provider.endpoint(transcriptionPath));
    final headers = {
      ...provider.extraHeaders,
      ...authHeaders(provider, apiKey),
    };
    final format = responseFormatFor(request, model);

    if (!needsJsonBody(request, model)) {
      final multipart = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers)
        ..fields['model'] = model.modelName
        ..fields['response_format'] = format;
      if (request.languages.isNotEmpty) {
        multipart.fields['language'] = request.languages.first;
      }
      if (format == 'verbose_json') {
        multipart.fields['timestamp_granularities[]'] = 'segment';
      }
      multipart.files.add(
        await http.MultipartFile.fromPath(
          'file',
          request.file.path,
          filename: _fileName(request.file),
        ),
      );
      return multipart;
    }

    final options = <String, dynamic>{};
    if (request.diarize && model.diarization != Capability.unsupported) {
      options['diarization'] = {'enabled': true};
    }
    if (model.supportsKeywords && request.keywords.isNotEmpty) {
      options['phraseList'] = {'phrases': request.keywords};
    }

    final body = <String, dynamic>{
      'model': model.modelName,
      'input_audio': {
        'data': base64Encode(await request.file.readAsBytes()),
        'format': audioFormatForPath(request.file.path),
      },
      'response_format': format,
      if (request.languages.isNotEmpty) 'language': request.languages.first,
      if (format == 'verbose_json') 'timestamp_granularities': ['segment'],
      if (options.isNotEmpty)
        'provider': {
          'options': {'azure': options},
        },
    };

    return http.Request('POST', uri)
      ..headers.addAll({...headers, 'Content-Type': 'application/json'})
      ..bodyBytes = utf8.encode(jsonEncode(body));
  }

  /// Purpose: Read a reply.
  /// Inputs: [body], [format].
  /// Returns: A [TranscriptionResult].
  /// Side effects: None.
  /// Notes: None.
  @override
  TranscriptionResult parseResponse(String body, String format) =>
      parseTranscriptionBody(body, format, 0);
}

/// Anything else that speaks the same protocol.
class OpenAiCompatibleDialect extends ProviderDialectHandler {
  /// Purpose: Create the dialect.
  /// Inputs: None.
  /// Returns: A new handler.
  /// Side effects: None.
  /// Notes: None.
  const OpenAiCompatibleDialect();

  /// Purpose: Choose the reply format.
  /// Inputs: [request], [model].
  /// Returns: The format name.
  /// Side effects: None.
  /// Notes: The verbose format is asked for only when the model is *known* to
  /// return times. For a server the user configured themselves that is usually
  /// unknown, and asking for a format it does not have costs a whole round trip
  /// and a confusing error.
  @override
  String responseFormatFor(TranscriptionRequest request, ModelConfig model) {
    if (request.wantTimestamps &&
        model.segmentTimestamps == Capability.supported) {
      return model.chooseResponseFormat(const ['verbose_json', 'json']);
    }
    return model.chooseResponseFormat(const ['json']);
  }

  /// Purpose: Build the multipart request.
  /// Inputs: [request], [provider], [model], [apiKey].
  /// Returns: A streamed multipart request.
  /// Side effects: Opens the audio file.
  /// Notes: The smallest request any of these endpoints accepts: file, model,
  /// format, and a language and prompt only where the model states it takes
  /// them. Nothing here is specific to one service, which is the point — this
  /// is what a local `whisper.cpp` server sees.
  @override
  Future<http.BaseRequest> buildRequest(
    TranscriptionRequest request,
    ProviderConfig provider,
    ModelConfig model,
    String? apiKey,
  ) async {
    final uri = Uri.parse(provider.endpoint(transcriptionPath));
    final multipart = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        ...provider.extraHeaders,
        ...authHeaders(provider, apiKey),
      })
      ..fields['model'] = model.modelName
      ..fields['response_format'] = responseFormatFor(request, model);

    if (model.supportsPrompt && (request.prompt?.isNotEmpty ?? false)) {
      multipart.fields['prompt'] = request.prompt!;
    }
    _addLanguage(multipart, request, model);

    multipart.files.add(
      await http.MultipartFile.fromPath(
        'file',
        request.file.path,
        filename: _fileName(request.file),
      ),
    );
    return multipart;
  }

  /// Purpose: Read a reply.
  /// Inputs: [body], [format].
  /// Returns: A [TranscriptionResult].
  /// Side effects: None.
  /// Notes: None.
  @override
  TranscriptionResult parseResponse(String body, String format) =>
      parseTranscriptionBody(body, format, 0);
}

/// Purpose: Add the language hint in the form this model wants.
/// Inputs: The [multipart] request, the [request] and the [model].
/// Returns: None.
/// Side effects: Adds fields to the request.
/// Notes: One model takes a **list**, so a recording that switches language can
/// say so; the rest take a single code and would reject the list. Sending the
/// wrong one is a 400 on every window of a long job.
void _addLanguage(
  http.MultipartRequest multipart,
  TranscriptionRequest request,
  ModelConfig model,
) {
  if (request.languages.isEmpty) return;
  switch (model.languageParamStyle) {
    case LanguageParamStyle.languages:
      for (final language in request.languages) {
        multipart.files.add(
          http.MultipartFile.fromString('languages[]', language),
        );
      }
    case LanguageParamStyle.language:
      multipart.fields['language'] = request.languages.first;
    case LanguageParamStyle.none:
      break;
  }
}

/// Purpose: Name the uploaded file.
/// Inputs: [file].
/// Returns: Its base name.
/// Side effects: None.
/// Notes: Some endpoints read the extension to decide how to decode the audio,
/// so the real name is sent rather than a generic one.
String _fileName(File file) {
  final path = file.path.replaceAll('\\', '/');
  final slash = path.lastIndexOf('/');
  return slash < 0 ? path : path.substring(slash + 1);
}
