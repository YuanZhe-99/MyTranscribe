/// Purpose: Read, seed, edit and save the library of sources and models.
/// Inputs: The settings document from the storage hub.
/// Returns: A typed view of it, and a Riverpod notifier over that view.
/// Side effects: Reads and writes `transcribe_settings.json`, which notifies
/// auto-sync.
/// Notes: This is the only place that turns settings records into typed
/// configurations and back. The records stay flat and opaque one layer down so
/// sync can merge a record this build cannot interpret; the typing happens
/// here, where a value that does not parse can fall back rather than break the
/// file. See `doc/en-us/features/provider-library.md`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/transcribe_storage.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import '../models/provider_templates.dart';
import '../models/transcribe_defaults.dart';
import '../models/transcribe_settings.dart';

/// The library, as the interface sees it.
class SettingsLibrary {
  /// Every source, in record order.
  final List<ProviderConfig> providers;

  /// Every model, in record order.
  final List<ModelConfig> models;

  /// What a new transcription starts from.
  final TranscribeDefaults defaults;

  /// Purpose: Create a library view.
  /// Inputs: [providers], [models], [defaults].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SettingsLibrary({
    this.providers = const [],
    this.models = const [],
    this.defaults = const TranscribeDefaults(),
  });

  /// Purpose: List the models belonging to one source.
  /// Inputs: [providerId].
  /// Returns: A new list, in record order.
  /// Side effects: None.
  /// Notes: None.
  List<ModelConfig> modelsOf(String providerId) => [
    for (final model in models)
      if (model.providerId == providerId) model,
  ];

  /// Purpose: Find one source by id.
  /// Inputs: [id].
  /// Returns: The source, or null.
  /// Side effects: None.
  /// Notes: None.
  ProviderConfig? provider(String? id) {
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  /// Purpose: Find one model by id.
  /// Inputs: [id].
  /// Returns: The model, or null.
  /// Side effects: None.
  /// Notes: None.
  ModelConfig? model(String? id) {
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }

  /// Purpose: Report whether the library has been seeded yet.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Drives the empty state; a user who deleted every source sees it
  /// again, which is correct — they can seed the built-in ones back.
  bool get isEmpty => providers.isEmpty;
}

/// Turns settings records into a typed library and back.
class SettingsRepository {
  /// Generates ids for records the user creates.
  final Uuid _uuid;

  /// Purpose: Create a repository.
  /// Inputs: Optional [uuid] for deterministic ids in tests.
  /// Returns: A new repository.
  /// Side effects: None.
  /// Notes: None.
  SettingsRepository({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Purpose: Read the library, seeding and refreshing it as needed.
  /// Inputs: None.
  /// Returns: The library, and whether anything was written.
  /// Side effects: May write `transcribe_settings.json`.
  /// Notes: Two things can happen on a read. An empty document is **seeded**
  /// from the templates, with derived ids so a second device produces the same
  /// records and the first sync merges rather than duplicating. A document
  /// whose template records predate the current [templateVersion] is
  /// **refreshed**, field by field, skipping anything the user overrode.
  ///
  /// Both write, and both go through the storage hub, so auto-sync learns about
  /// them. A device that only reads still ends up agreeing with one that wrote,
  /// because the seeded records are identical.
  Future<SettingsLibrary> load() async {
    var settings = await TranscribeStorage.loadSettings();
    var changed = false;

    if (settings.ofKind(SettingsRecordKind.provider).isEmpty) {
      settings = seedInto(settings);
      changed = true;
    }

    final refreshed = applyTemplateUpdates(settings);
    if (refreshed != null) {
      settings = refreshed;
      changed = true;
    }

    if (changed) await TranscribeStorage.saveSettings(settings);
    return read(settings);
  }

  /// Purpose: Turn a settings document into the typed library.
  /// Inputs: [settings].
  /// Returns: A [SettingsLibrary].
  /// Side effects: None.
  /// Notes: Pure, so the whole parsing path is testable without touching disk.
  /// A record of a kind this build does not know is skipped here and left
  /// untouched in the document, so it still syncs.
  SettingsLibrary read(TranscribeSettings settings) {
    final defaultsRecord = settings.byId(defaultsRecordId);
    return SettingsLibrary(
      providers: [
        for (final record in settings.ofKind(SettingsRecordKind.provider))
          ProviderConfig.fromPayload(record.id, record.payload),
      ],
      models: [
        for (final record in settings.ofKind(SettingsRecordKind.model))
          ModelConfig.fromPayload(record.id, record.payload),
      ],
      defaults: defaultsRecord == null
          ? const TranscribeDefaults()
          : TranscribeDefaults.fromPayload(defaultsRecord.payload),
    );
  }

  /// Purpose: Add the built-in sources and models to a document.
  /// Inputs: [settings], optional [now] for tests.
  /// Returns: A new document holding them.
  /// Side effects: None.
  /// Notes: Pure. Ids are derived from the template rather than generated, so
  /// two devices that seed independently produce identical records and the
  /// first sync merges them. An existing record with the same id is left alone:
  /// seeding must never overwrite something the user has already edited.
  TranscribeSettings seedInto(TranscribeSettings settings, {DateTime? now}) {
    final stamp = (now ?? DateTime.now()).toUtc();
    var result = settings;

    for (final template in buildProviderTemplates()) {
      if (result.byId(template.provider.id) == null) {
        result = result.upsert(
          SettingsRecord(
            id: template.provider.id,
            kind: SettingsRecordKind.provider,
            createdAt: stamp,
            modifiedAt: stamp,
            payload: template.provider.toPayload(),
          ),
        );
      }
      for (final model in template.models) {
        if (result.byId(model.id) == null) {
          result = result.upsert(
            SettingsRecord(
              id: model.id,
              kind: SettingsRecordKind.model,
              createdAt: stamp,
              modifiedAt: stamp,
              payload: model.toPayload(),
            ),
          );
        }
      }
    }

    if (result.byId(defaultsRecordId) == null) {
      result = result.upsert(
        SettingsRecord(
          id: defaultsRecordId,
          kind: SettingsRecordKind.defaults,
          createdAt: stamp,
          modifiedAt: stamp,
          payload: const TranscribeDefaults().toPayload(),
        ),
      );
    }
    return result;
  }

  /// Purpose: Bring template records up to the current template data.
  /// Inputs: [settings], optional [now] for tests.
  /// Returns: A new document, or null when nothing needed changing.
  /// Side effects: None.
  /// Notes: Pure. **Only fields the user has not overridden are refreshed.**
  /// That is what makes an improved default — a corrected limit, a newly
  /// documented capability — reach everyone who never touched it while leaving
  /// a deliberate change alone.
  ///
  /// Returning null rather than an equal document matters: writing an identical
  /// file would move `modifiedAt` on every record and make the next sync think
  /// this device changed everything.
  TranscribeSettings? applyTemplateUpdates(
    TranscribeSettings settings, {
    DateTime? now,
  }) {
    final stamp = (now ?? DateTime.now()).toUtc();
    var result = settings;
    var changed = false;

    for (final template in buildProviderTemplates()) {
      final providerRecord = result.byId(template.provider.id);
      if (providerRecord != null) {
        final current = ProviderConfig.fromPayload(
          providerRecord.id,
          providerRecord.payload,
        );
        if (current.templateVersion < templateVersion) {
          final merged = _mergeProviderTemplate(current, template.provider);
          result = result.upsert(
            providerRecord.touch(merged.toPayload(), now: stamp),
          );
          changed = true;
        }
      }

      for (final model in template.models) {
        final record = result.byId(model.id);
        if (record == null) continue;
        final current = ModelConfig.fromPayload(record.id, record.payload);
        if (current.templateVersion >= templateVersion) continue;
        final merged = _mergeModelTemplate(current, model);
        result = result.upsert(record.touch(merged.toPayload(), now: stamp));
        changed = true;
      }
    }

    return changed ? result : null;
  }

  /// Purpose: Take a template's values for every field the user left alone.
  /// Inputs: [current] the stored source, [template] the shipped one.
  /// Returns: The merged source.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The user's own name,
  /// overrides and template version bookkeeping survive; everything else comes
  /// from the template unless it is in `overriddenFields`.
  ProviderConfig _mergeProviderTemplate(
    ProviderConfig current,
    ProviderConfig template,
  ) {
    bool kept(String field) => current.overriddenFields.contains(field);
    return ProviderConfig(
      id: current.id,
      templateId: template.templateId,
      name: kept('name') ? current.name : template.name,
      dialect: kept('dialect') ? current.dialect : template.dialect,
      baseUrl: kept('baseUrl') ? current.baseUrl : template.baseUrl,
      authScheme: kept('authScheme') ? current.authScheme : template.authScheme,
      authHeaderName: kept('authHeaderName')
          ? current.authHeaderName
          : template.authHeaderName,
      extraHeaders: kept('extraHeaders')
          ? current.extraHeaders
          : template.extraHeaders,
      maxRequestSeconds: kept('maxRequestSeconds')
          ? current.maxRequestSeconds
          : template.maxRequestSeconds,
      maxFileBytes: kept('maxFileBytes')
          ? current.maxFileBytes
          : template.maxFileBytes,
      requestTimeoutSeconds: kept('requestTimeoutSeconds')
          ? current.requestTimeoutSeconds
          : template.requestTimeoutSeconds,
      // Not a template field in practice: the user's chosen default model is
      // theirs, and a template refresh has no business moving it.
      defaultModelId: current.defaultModelId ?? template.defaultModelId,
      overriddenFields: current.overriddenFields,
      templateVersion: templateVersion,
      extraJson: current.extraJson,
    );
  }

  /// Purpose: Take a template's values for every model field left alone.
  /// Inputs: [current] the stored model, [template] the shipped one.
  /// Returns: The merged model.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  ModelConfig _mergeModelTemplate(ModelConfig current, ModelConfig template) {
    bool kept(String field) => current.overriddenFields.contains(field);
    return ModelConfig(
      id: current.id,
      providerId: current.providerId,
      templateId: template.templateId,
      modelName: kept('modelName') ? current.modelName : template.modelName,
      displayName: kept('displayName')
          ? current.displayName
          : template.displayName,
      maxFileBytes: kept('maxFileBytes')
          ? current.maxFileBytes
          : template.maxFileBytes,
      maxDurationSeconds: kept('maxDurationSeconds')
          ? current.maxDurationSeconds
          : template.maxDurationSeconds,
      diarization: kept('diarization')
          ? current.diarization
          : template.diarization,
      wordTimestamps: kept('wordTimestamps')
          ? current.wordTimestamps
          : template.wordTimestamps,
      segmentTimestamps: kept('segmentTimestamps')
          ? current.segmentTimestamps
          : template.segmentTimestamps,
      supportsPrompt: kept('supportsPrompt')
          ? current.supportsPrompt
          : template.supportsPrompt,
      supportsKeywords: kept('supportsKeywords')
          ? current.supportsKeywords
          : template.supportsKeywords,
      languageParamStyle: kept('languageParamStyle')
          ? current.languageParamStyle
          : template.languageParamStyle,
      responseFormats: kept('responseFormats')
          ? current.responseFormats
          : template.responseFormats,
      inputFormats: kept('inputFormats')
          ? current.inputFormats
          : template.inputFormats,
      maxKnownSpeakers: kept('maxKnownSpeakers')
          ? current.maxKnownSpeakers
          : template.maxKnownSpeakers,
      requiresChunkingStrategy: kept('requiresChunkingStrategy')
          ? current.requiresChunkingStrategy
          : template.requiresChunkingStrategy,
      overriddenFields: current.overriddenFields,
      templateVersion: templateVersion,
      extraJson: current.extraJson,
    );
  }

  /// Purpose: Generate the record id for a source the user is adding.
  /// Inputs: None.
  /// Returns: A new id.
  /// Side effects: None.
  /// Notes: Random, unlike a template's derived id: two users adding "my
  /// server" are not adding the same thing, and merging them would be wrong.
  String newProviderId() => 'provider:${_uuid.v4()}';

  /// Purpose: Generate the record id for a model the user is adding.
  /// Inputs: None.
  /// Returns: A new id.
  /// Side effects: None.
  /// Notes: See [newProviderId].
  String newModelId() => 'model:${_uuid.v4()}';

  /// Purpose: Insert or update one source.
  /// Inputs: [provider], optional [now].
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: None.
  Future<void> saveProvider(ProviderConfig provider, {DateTime? now}) async {
    await _mutate((settings) {
      final existing = settings.byId(provider.id);
      final stamp = (now ?? DateTime.now()).toUtc();
      return settings.upsert(
        existing == null
            ? SettingsRecord(
                id: provider.id,
                kind: SettingsRecordKind.provider,
                createdAt: stamp,
                modifiedAt: stamp,
                payload: provider.toPayload(),
              )
            : existing.touch(provider.toPayload(), now: stamp),
      );
    });
  }

  /// Purpose: Insert or update one model.
  /// Inputs: [model], optional [now].
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: None.
  Future<void> saveModel(ModelConfig model, {DateTime? now}) async {
    await _mutate((settings) {
      final existing = settings.byId(model.id);
      final stamp = (now ?? DateTime.now()).toUtc();
      return settings.upsert(
        existing == null
            ? SettingsRecord(
                id: model.id,
                kind: SettingsRecordKind.model,
                createdAt: stamp,
                modifiedAt: stamp,
                payload: model.toPayload(),
              )
            : existing.touch(model.toPayload(), now: stamp),
      );
    });
  }

  /// Purpose: Replace the defaults.
  /// Inputs: [defaults], optional [now].
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: None.
  Future<void> saveDefaults(
    TranscribeDefaults defaults, {
    DateTime? now,
  }) async {
    await _mutate((settings) {
      final existing = settings.byId(defaultsRecordId);
      final stamp = (now ?? DateTime.now()).toUtc();
      return settings.upsert(
        existing == null
            ? SettingsRecord(
                id: defaultsRecordId,
                kind: SettingsRecordKind.defaults,
                createdAt: stamp,
                modifiedAt: stamp,
                payload: defaults.toPayload(),
              )
            : existing.touch(defaults.toPayload(), now: stamp),
      );
    });
  }

  /// Purpose: Change the defaults without reading them first.
  /// Inputs: A [change] applied to whatever the defaults are now.
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: A read-modify-write done inside the mutation, so two callers that
  /// both touch the defaults cannot overwrite each other with a copy each read
  /// before the other wrote. Unknown payload fields survive, because the change
  /// is applied to a parsed record that carries them.
  Future<void> updateDefaults(
    TranscribeDefaults Function(TranscribeDefaults current) change, {
    DateTime? now,
  }) async {
    await _mutate((settings) {
      final existing = settings.byId(defaultsRecordId);
      final current = existing == null
          ? const TranscribeDefaults()
          : TranscribeDefaults.fromPayload(existing.payload);
      final stamp = (now ?? DateTime.now()).toUtc();
      final payload = change(current).toPayload();
      return settings.upsert(
        existing == null
            ? SettingsRecord(
                id: defaultsRecordId,
                kind: SettingsRecordKind.defaults,
                createdAt: stamp,
                modifiedAt: stamp,
                payload: payload,
              )
            : existing.touch(payload, now: stamp),
      );
    });
  }

  /// Purpose: Remember a speaker name so it can be offered next time.
  /// Inputs: [name].
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: The list is synced, because the people in your recordings are the
  /// same people on either device.
  Future<void> rememberSpeakerName(String name) =>
      updateDefaults((current) => current.rememberSpeakerName(name));

  /// Purpose: Stop offering a speaker name.
  /// Inputs: [name].
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: Only the suggestion is forgotten; speakers already named keep the
  /// name they were given.
  Future<void> forgetSpeakerName(String name) =>
      updateDefaults((current) => current.forgetSpeakerName(name));

  /// Purpose: Remove a source and every model belonging to it.
  /// Inputs: [providerId].
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: The models go too. A model whose source is gone can never be used
  /// and would sit in the library as an orphan nobody can explain. The API key
  /// is **not** removed here — that is the caller's job, because it lives in a
  /// different file that this repository does not touch.
  Future<void> deleteProvider(String providerId) async {
    await _mutate((settings) {
      var result = settings.remove(providerId);
      for (final record in settings.ofKind(SettingsRecordKind.model)) {
        if (record.payload['providerId'] == providerId) {
          result = result.remove(record.id);
        }
      }
      return result;
    });
  }

  /// Purpose: Remove one model.
  /// Inputs: [modelId].
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: A real removal, so the deletion propagates through sync rather than
  /// the record coming back from the other device.
  Future<void> deleteModel(String modelId) async {
    await _mutate((settings) => settings.remove(modelId));
  }

  /// Purpose: Put a template record back to its shipped values.
  /// Inputs: [recordId], optional [now].
  /// Returns: A future completing after the write.
  /// Side effects: Writes the settings file; notifies auto-sync.
  /// Notes: Clears the record's overrides and re-copies the template, which is
  /// the escape hatch from an edit that turned out to be wrong. A record with
  /// no template is left alone: there is nothing to reset it to.
  Future<void> resetToTemplate(String recordId, {DateTime? now}) async {
    await _mutate((settings) {
      final record = settings.byId(recordId);
      if (record == null) return settings;
      final stamp = (now ?? DateTime.now()).toUtc();

      for (final template in buildProviderTemplates()) {
        if (template.provider.id == recordId) {
          return settings.upsert(
            record.touch(template.provider.toPayload(), now: stamp),
          );
        }
        for (final model in template.models) {
          if (model.id == recordId) {
            return settings.upsert(record.touch(model.toPayload(), now: stamp));
          }
        }
      }
      return settings;
    });
  }

  /// Purpose: Read, transform and write the settings document.
  /// Inputs: [change].
  /// Returns: A future completing after the write.
  /// Side effects: Reads and writes the settings file.
  /// Notes: Internal helper used within this file only. Read-modify-write on
  /// every mutation rather than holding the document in memory, so a record
  /// another part of the app wrote in between is never lost.
  Future<void> _mutate(
    TranscribeSettings Function(TranscribeSettings) change,
  ) async {
    final settings = await TranscribeStorage.loadSettings();
    await TranscribeStorage.saveSettings(change(settings));
  }
}

/// The repository, shared by everything that reads the library.
final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

/// The library, loaded once and refreshed when something writes to it.
///
/// Invalidate — in this Riverpod version, `ref.refresh` — after any save, so
/// the pages watching it rebuild.
final settingsLibraryProvider = FutureProvider<SettingsLibrary>((ref) async {
  return ref.watch(settingsRepositoryProvider).load();
});
