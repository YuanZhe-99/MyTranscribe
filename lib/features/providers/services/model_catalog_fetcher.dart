/// Purpose: Ask a source which models it offers.
/// Inputs: A source, and its API key when it needs one.
/// Returns: The model identifiers it listed.
/// Side effects: One HTTP request.
/// Notes: Every endpoint here exposes `GET {base}/models`, and OpenRouter takes
/// a filter that narrows it to transcription. The result is only a list of
/// names: **capabilities are never guessed from it.** A model imported this way
/// arrives with everything `unknown` unless a built-in template describes it,
/// because a wrong guess turns into a failed job with a message that points at
/// the wrong thing.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/model_config.dart';
import '../models/provider_config.dart';
import '../models/provider_templates.dart';

/// A model the source said it has.
class CatalogEntry {
  /// The identifier to send as `model`.
  final String modelName;

  /// A friendlier name, when the source supplied one.
  final String? displayName;

  /// Purpose: Create a catalog entry.
  /// Inputs: [modelName], optional [displayName].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const CatalogEntry({required this.modelName, this.displayName});
}

/// A model list that could not be fetched.
class CatalogException implements Exception {
  /// A sentence naming what went wrong.
  final String message;

  /// Purpose: Create a catalog exception.
  /// Inputs: [message].
  /// Returns: A new exception.
  /// Side effects: None.
  /// Notes: None.
  const CatalogException(this.message);

  @override
  String toString() => message;
}

/// Fetches a source's model list.
class ModelCatalogFetcher {
  /// Builds the HTTP client, injectable for tests.
  final http.Client Function() clientFactory;

  /// Purpose: Create a fetcher.
  /// Inputs: Optional [clientFactory].
  /// Returns: A new fetcher.
  /// Side effects: None.
  /// Notes: None.
  ModelCatalogFetcher({http.Client Function()? clientFactory})
    : clientFactory = clientFactory ?? http.Client.new;

  /// Purpose: Ask a source what models it has.
  /// Inputs: [provider], and [apiKey] when the source needs one.
  /// Returns: The entries, sorted by identifier.
  /// Side effects: One HTTP GET.
  /// Notes: OpenRouter is asked to narrow the list to transcription models,
  /// because its full catalogue is hundreds of chat models the user would have
  /// to scroll past. The others return a short enough list to show whole.
  Future<List<CatalogEntry>> fetch(
    ProviderConfig provider, {
    String? apiKey,
  }) async {
    final path = provider.dialect == ProviderDialect.openrouter
        ? 'models?output_modalities=transcription'
        : 'models';
    final uri = Uri.tryParse(provider.endpoint(path));
    if (uri == null) {
      throw const CatalogException('That address could not be read as a URL.');
    }

    final client = clientFactory();
    try {
      final response = await client
          .get(uri, headers: _headers(provider, apiKey))
          .timeout(Duration(seconds: provider.requestTimeoutSeconds));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CatalogException(
          'The source refused the request. Check the API key.',
        );
      }
      if (response.statusCode != 200) {
        throw CatalogException(
          'The source answered with status ${response.statusCode}.',
        );
      }
      return _parse(utf8.decode(response.bodyBytes));
    } on CatalogException {
      rethrow;
    } catch (error) {
      throw CatalogException('The model list could not be fetched: $error');
    } finally {
      client.close();
    }
  }

  /// Purpose: Build the request headers for a source.
  /// Inputs: [provider], [apiKey].
  /// Returns: The headers.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Map<String, String> _headers(ProviderConfig provider, String? apiKey) => {
    ...provider.extraHeaders,
    if (apiKey != null && apiKey.isNotEmpty)
      switch (provider.authScheme) {
        AuthScheme.bearer => 'Authorization',
        AuthScheme.header => provider.authHeaderName ?? 'Authorization',
        AuthScheme.none => 'X-Unused',
      }: switch (provider.authScheme) {
        AuthScheme.bearer => 'Bearer $apiKey',
        AuthScheme.header => apiKey,
        AuthScheme.none => '',
      },
  }..removeWhere((key, value) => key == 'X-Unused');

  /// Purpose: Read the model list out of a response body.
  /// Inputs: [body].
  /// Returns: The entries, sorted and deduplicated.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Every one of these
  /// endpoints answers `{"data": [{"id": …}]}`, but a self-hosted server might
  /// return a bare list, so both are accepted. An entry without an id is
  /// skipped rather than making the whole list unreadable.
  List<CatalogEntry> _parse(String body) {
    final decoded = jsonDecode(body);
    final items = switch (decoded) {
      {'data': final List list} => list,
      final List list => list,
      _ => throw const CatalogException(
        'The source returned something that is not a model list.',
      ),
    };

    final seen = <String>{};
    final entries = <CatalogEntry>[];
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['id'] ?? item['name'] ?? item['model'];
      if (id is! String || id.trim().isEmpty) continue;
      if (!seen.add(id)) continue;
      final name = item['name'];
      entries.add(
        CatalogEntry(
          modelName: id,
          displayName: name is String && name != id ? name : null,
        ),
      );
    }
    entries.sort((a, b) => a.modelName.compareTo(b.modelName));
    return entries;
  }
}

/// Purpose: Turn a catalogue entry into a model record for one source.
/// Inputs: [entry], the [provider] it belongs to, and the [id] to give it.
/// Returns: A [ModelConfig].
/// Side effects: None.
/// Notes: **Capabilities come from a matching built-in template or from
/// nowhere.** If the app ships a description of this exact model under this
/// exact source, that is used; otherwise every capability is `unknown`, which
/// makes the app offer features with a warning instead of promising or hiding
/// them. Guessing from a name — "it has whisper in it, so it must return
/// timestamps" — is how a job fails at the last window with a confusing error.
ModelConfig modelFromCatalog(
  CatalogEntry entry,
  ProviderConfig provider,
  String id,
) {
  for (final template in buildProviderTemplates()) {
    if (template.provider.id != provider.id) continue;
    for (final model in template.models) {
      if (model.modelName != entry.modelName) continue;
      return ModelConfig(
        id: id,
        providerId: provider.id,
        templateId: model.templateId,
        modelName: model.modelName,
        displayName: entry.displayName ?? model.displayName,
        maxFileBytes: model.maxFileBytes,
        maxDurationSeconds: model.maxDurationSeconds,
        diarization: model.diarization,
        wordTimestamps: model.wordTimestamps,
        segmentTimestamps: model.segmentTimestamps,
        supportsPrompt: model.supportsPrompt,
        supportsKeywords: model.supportsKeywords,
        languageParamStyle: model.languageParamStyle,
        responseFormats: model.responseFormats,
        inputFormats: model.inputFormats,
        maxKnownSpeakers: model.maxKnownSpeakers,
        requiresChunkingStrategy: model.requiresChunkingStrategy,
        templateVersion: templateVersion,
      );
    }
  }

  return ModelConfig(
    id: id,
    providerId: provider.id,
    modelName: entry.modelName,
    displayName: entry.displayName ?? entry.modelName,
    maxFileBytes: provider.maxFileBytes,
  );
}
