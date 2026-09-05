/// Purpose: The synced settings document — every source, model and default the
/// app keeps, as a flat list of records the shared merge engine can reconcile.
/// Inputs: Parsed `transcribe_settings.json` content.
/// Returns: `SettingsRecord` and `TranscribeSettings` value types.
/// Side effects: None.
/// Notes: Records are deliberately *flat* and carry an opaque `payload` map.
/// The sync engine only needs an id and a timestamp per record, so keeping the
/// typed shapes (`ProviderConfig`, `ModelConfig`) one layer above means a
/// record written by a newer build merges correctly here even when this build
/// cannot interpret its payload. Nothing in this file is API-key aware; keys
/// live in `transcribe_secrets.json`, which is not part of any data module.
library;

/// What a [SettingsRecord] describes.
///
/// The wire value is the enum name, and it is a persisted compatibility
/// contract: an unrecognised kind parses to [SettingsRecordKind.unknown] and is
/// carried through sync untouched rather than dropped.
enum SettingsRecordKind {
  /// An API endpoint — OpenAI, OpenRouter, or an OpenAI-compatible server.
  provider,

  /// One transcription model offered by a provider, with its capabilities.
  model,

  /// The single record holding the defaults a new job starts from.
  defaults,

  /// A kind this build does not know. Preserved, never interpreted.
  unknown;

  /// Purpose: Parse a persisted kind string.
  /// Inputs: [value] the raw `kind` field, possibly null.
  /// Returns: The matching kind, or [SettingsRecordKind.unknown].
  /// Side effects: None.
  /// Notes: Never throws — a newer build's record must not stop this one from
  /// reading the file.
  static SettingsRecordKind parse(Object? value) {
    for (final kind in SettingsRecordKind.values) {
      if (kind != SettingsRecordKind.unknown && kind.name == value) return kind;
    }
    return SettingsRecordKind.unknown;
  }
}

/// The record id of the singleton defaults record.
const defaultsRecordId = 'defaults';

/// Keys this build writes at the top level of a record.
///
/// Anything else found in a record is kept in [SettingsRecord.extraJson] and
/// written back out, so an older build never deletes a newer build's field.
const _knownRecordKeys = {'id', 'kind', 'createdAt', 'modifiedAt', 'payload'};

/// Keys this build writes at the top level of the settings document.
const _knownDocumentKeys = {'records'};

/// One mergeable unit of configuration: a source, a model, or the defaults.
class SettingsRecord {
  /// Stable identifier, e.g. `provider:openai` or `model:openai:gpt-transcribe`.
  ///
  /// Template records use derived ids so two fresh devices seed the same ones
  /// and the first sync merges them instead of producing duplicates.
  final String id;

  /// What this record describes.
  final SettingsRecordKind kind;

  /// When the record was first created, in UTC.
  final DateTime createdAt;

  /// When the record last changed, in UTC.
  ///
  /// The merge engine compares this against the base snapshot to decide which
  /// side changed, so it must be UTC: a local-time value read on a device in
  /// another zone would silently reorder edits.
  final DateTime modifiedAt;

  /// The record's own fields, interpreted by the typed layer above.
  final Map<String, dynamic> payload;

  /// Top-level fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a settings record.
  /// Inputs: [id], [kind], [createdAt], [modifiedAt], [payload], [extraJson].
  /// Returns: A new immutable record.
  /// Side effects: None.
  /// Notes: Callers pass UTC timestamps; [touch] is the normal way to set
  /// [modifiedAt] on an edit.
  const SettingsRecord({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.modifiedAt,
    this.payload = const {},
    this.extraJson = const {},
  });

  /// Purpose: Parse one record from JSON.
  /// Inputs: [json] a record object.
  /// Returns: A [SettingsRecord].
  /// Side effects: None.
  /// Notes: A missing or unparseable timestamp falls back to the Unix epoch in
  /// UTC rather than to "now": "now" would make an unchanged record look newer
  /// than the remote copy on every read and win every merge.
  factory SettingsRecord.fromJson(Map<String, dynamic> json) {
    final created = _parseUtc(json['createdAt']);
    return SettingsRecord(
      id: json['id'] as String? ?? '',
      kind: SettingsRecordKind.parse(json['kind']),
      createdAt: created ?? _epoch,
      modifiedAt: _parseUtc(json['modifiedAt']) ?? created ?? _epoch,
      payload: _asMap(json['payload']),
      extraJson: {
        for (final e in json.entries)
          if (!_knownRecordKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Purpose: Serialize the record, unknown fields included.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Unknown fields are written first so a known key always wins a
  /// collision with a stale unknown one of the same name.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'kind': kind.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'payload': payload,
  };

  /// Purpose: Return a copy with a new payload and a fresh modification time.
  /// Inputs: [payload] the replacement fields; [now] for tests.
  /// Returns: A new [SettingsRecord].
  /// Side effects: None.
  /// Notes: The one supported way to edit a record, so no edit can forget to
  /// move [modifiedAt] and then lose to an older remote copy.
  SettingsRecord touch(Map<String, dynamic> payload, {DateTime? now}) =>
      SettingsRecord(
        id: id,
        kind: kind,
        createdAt: createdAt,
        modifiedAt: (now ?? DateTime.now()).toUtc(),
        payload: payload,
        extraJson: extraJson,
      );

  /// Purpose: Merge another record's unknown fields into this one.
  /// Inputs: [other] the record to take unknown fields from.
  /// Returns: A new [SettingsRecord] carrying both sets.
  /// Side effects: None.
  /// Notes: Passed to the shared merge engine as `mergeUnknownFields`, so the
  /// losing side of a merge still contributes any field this build cannot see.
  SettingsRecord withPreservedUnknownJson(SettingsRecord? other) {
    if (other == null || other.extraJson.isEmpty) return this;
    return SettingsRecord(
      id: id,
      kind: kind,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      payload: payload,
      extraJson: {...other.extraJson, ...extraJson},
    );
  }
}

/// The whole `transcribe_settings.json` document.
class TranscribeSettings {
  /// Every record, in file order.
  final List<SettingsRecord> records;

  /// Top-level fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a settings document.
  /// Inputs: [records], [extraJson].
  /// Returns: A new immutable document.
  /// Side effects: None.
  /// Notes: None.
  const TranscribeSettings({
    this.records = const [],
    this.extraJson = const {},
  });

  /// Purpose: Parse the settings document.
  /// Inputs: [json] the decoded file content.
  /// Returns: A [TranscribeSettings].
  /// Side effects: None.
  /// Notes: A `records` value that is not a list reads as empty rather than
  /// throwing, so one malformed field does not make the file unopenable. A
  /// record without an id is dropped: it can never be merged or addressed.
  factory TranscribeSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['records'];
    return TranscribeSettings(
      records: [
        if (raw is List)
          for (final item in raw)
            if (item is Map<String, dynamic>)
              if (SettingsRecord.fromJson(item) case final r
                  when r.id.isNotEmpty)
                r,
      ],
      extraJson: {
        for (final e in json.entries)
          if (!_knownDocumentKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Purpose: Serialize the document, unknown fields included.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'records': [for (final r in records) r.toJson()],
  };

  /// Purpose: Find one record by id.
  /// Inputs: [id].
  /// Returns: The record, or null when absent.
  /// Side effects: None.
  /// Notes: None.
  SettingsRecord? byId(String id) {
    for (final r in records) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Purpose: List the records of one kind, in file order.
  /// Inputs: [kind].
  /// Returns: A new list.
  /// Side effects: None.
  /// Notes: None.
  List<SettingsRecord> ofKind(SettingsRecordKind kind) => [
    for (final r in records)
      if (r.kind == kind) r,
  ];

  /// Purpose: Return a copy with one record inserted or replaced by id.
  /// Inputs: [record].
  /// Returns: A new [TranscribeSettings].
  /// Side effects: None.
  /// Notes: Order is preserved for an existing id, and a new record is
  /// appended, so the file stays stable between saves and sync keeps hitting
  /// its raw-equality fast path when nothing actually changed.
  TranscribeSettings upsert(SettingsRecord record) {
    final next = List<SettingsRecord>.of(records);
    final index = next.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      next[index] = record;
    } else {
      next.add(record);
    }
    return TranscribeSettings(records: next, extraJson: extraJson);
  }

  /// Purpose: Return a copy without the record of the given id.
  /// Inputs: [id].
  /// Returns: A new [TranscribeSettings].
  /// Side effects: None.
  /// Notes: A real removal, not a tombstone: the shared merge engine reads
  /// deletions from the base snapshot, so a record missing here and present in
  /// the base propagates the deletion to the other device.
  TranscribeSettings remove(String id) => TranscribeSettings(
    records: [
      for (final r in records)
        if (r.id != id) r,
    ],
    extraJson: extraJson,
  );
}

/// The fallback timestamp for a record with no readable date.
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Purpose: Read an ISO-8601 timestamp as UTC.
/// Inputs: [value] the raw field.
/// Returns: The parsed UTC time, or null when it is missing or unreadable.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
DateTime? _parseUtc(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

/// Purpose: Read a field that should be a JSON object.
/// Inputs: [value] the raw field.
/// Returns: A copy of the map, or an empty map when it is anything else.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? Map<String, dynamic>.of(value) : {};
