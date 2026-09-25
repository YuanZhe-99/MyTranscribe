/// Purpose: Carry every finished transcription's record and transcript as one
/// syncable document.
/// Inputs: The raw JSON of `jobs/<id>/job.json` and `jobs/<id>/transcript.json`.
/// Returns: A document the sync, backup and ZIP engines can treat like any
/// other module file.
/// Side effects: None; this file is pure data.
/// Notes: A **projection**, not a source of truth. `jobs/` stays where the app
/// reads and writes; this document is rebuilt from it before a sync and applied
/// back into it afterwards. The engines only ever touch the file names in the
/// module registry, and a job folder can never be one of those — it holds hours
/// of audio. Projecting the small half of each folder is what lets the text
/// travel while the recordings stay put.
///
/// The `job` and `transcript` fields are **raw maps**, deliberately. Nested
/// types inside a job record — the options, the chunk plan, each chunk result,
/// the media probe — have no `extraJson`, so parsing a record written by a
/// newer build and writing it back would silently drop whatever that build
/// added. Two devices would then take turns stripping each other's fields and
/// re-uploading for ever. Carrying the maps through untouched costs nothing and
/// cannot do that. See `doc/en-us/data-formats.md`.
library;

/// One finished transcription, as it travels between devices.
class TranscriptSyncRecord {
  /// The job id, which is also its folder name under `jobs/`.
  final String id;

  /// When the transcription was created.
  final DateTime createdAt;

  /// The later of the record's own change time and the transcript's.
  ///
  /// The merge compares these, so a speaker renamed in the viewer has to move
  /// it even though the job record itself did not change.
  final DateTime modifiedAt;

  /// The raw contents of `job.json`.
  final Map<String, dynamic> job;

  /// The raw contents of `transcript.json`.
  final Map<String, dynamic> transcript;

  /// Record fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a transcript sync record.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptSyncRecord({
    required this.id,
    required this.createdAt,
    required this.modifiedAt,
    required this.job,
    required this.transcript,
    this.extraJson = const {},
  });

  /// Purpose: Parse one record.
  /// Inputs: [json].
  /// Returns: The record, or null when it is not usable.
  /// Side effects: None.
  /// Notes: Null rather than an exception for a record with no id or without
  /// both maps: one damaged entry written by another device must not stop the
  /// rest of the document from syncing. A missing timestamp reads as the epoch,
  /// which loses to anything, matching how `SettingsRecord` treats one.
  static TranscriptSyncRecord? fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final job = json['job'];
    final transcript = json['transcript'];
    if (id.isEmpty || job is! Map || transcript is! Map) return null;

    return TranscriptSyncRecord(
      id: id,
      createdAt: _time(json['createdAt']),
      modifiedAt: _time(json['modifiedAt']),
      job: Map<String, dynamic>.from(job),
      transcript: Map<String, dynamic>.from(transcript),
      extraJson: {
        for (final entry in json.entries)
          if (!_knownRecordKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// Purpose: Write one record out.
  /// Inputs: None.
  /// Returns: The JSON map.
  /// Side effects: None.
  /// Notes: Unknown fields go first, so a field this build knows about always
  /// wins over an older copy of itself.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'job': job,
    'transcript': transcript,
  };

  /// Purpose: Keep the other side's unknown fields when this record wins.
  /// Inputs: The [other] record, which may be null.
  /// Returns: This record, or a copy carrying both sides' unknown fields.
  /// Side effects: None.
  /// Notes: The same contract `SettingsRecord` has: losing a merge must never
  /// delete a field a newer build wrote.
  TranscriptSyncRecord withPreservedUnknownJson(TranscriptSyncRecord? other) {
    if (other == null || other.extraJson.isEmpty) return this;
    return TranscriptSyncRecord(
      id: id,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      job: job,
      transcript: transcript,
      extraJson: {...other.extraJson, ...extraJson},
    );
  }

  /// Purpose: Name this transcription for the conflict dialog.
  /// Inputs: None.
  /// Returns: The name the user gave it, else the recording, else the id.
  /// Side effects: None.
  /// Notes: Nonlocalized on purpose, like [settingsRecordDisplayName]: the name
  /// the user typed is what tells two transcriptions apart.
  String get displayName {
    for (final key in const ['title', 'sourceName']) {
      final value = job[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return id;
  }

  /// Purpose: Describe one side of a conflict in a few lines.
  /// Inputs: None.
  /// Returns: Short lines for the dialog.
  /// Side effects: None.
  /// Notes: What tells two versions of the same transcription apart is who is
  /// in it and how many lines there are, not the model or the dates.
  List<String> get summaryLines {
    final lines = <String>[];
    final model = job['modelName'];
    if (model is String && model.trim().isNotEmpty) lines.add(model.trim());

    final speakers = transcript['speakers'];
    if (speakers is List && speakers.isNotEmpty) {
      final names = [
        for (final speaker in speakers)
          if (speaker is Map && speaker['name'] is String)
            (speaker['name'] as String).trim(),
      ].where((name) => name.isNotEmpty);
      if (names.isNotEmpty) lines.add(names.join(', '));
    }

    final segments = transcript['segments'];
    if (segments is List) lines.add('${segments.length} lines');

    return lines;
  }

  /// Purpose: Say whether an id is safe to use as a folder or file name.
  /// Inputs: The [id].
  /// Returns: Whether it may be used.
  /// Side effects: None.
  /// Notes: Record ids arrive from a server and name a path the app is about to
  /// write to. `..` or a separator in one would let a document reach outside
  /// `jobs/`. Every id this app generates is a UUID, so the restriction costs
  /// nothing.
  static bool isSafeId(String id) =>
      id.isNotEmpty &&
      id != '.' &&
      id != '..' &&
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(id);
}

/// Every finished transcription this device has.
class TranscriptsDocument {
  /// The transcriptions, sorted by id when written.
  final List<TranscriptSyncRecord> records;

  /// Top-level fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a transcripts document.
  /// Inputs: [records], [extraJson].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptsDocument({
    this.records = const [],
    this.extraJson = const {},
  });

  /// Purpose: Parse a document.
  /// Inputs: [json].
  /// Returns: A [TranscriptsDocument].
  /// Side effects: None.
  /// Notes: Unusable records are skipped rather than throwing, so one bad entry
  /// cannot stop every other transcription from syncing.
  factory TranscriptsDocument.fromJson(Map<String, dynamic> json) {
    final raw = json['records'];
    return TranscriptsDocument(
      records: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map<String, dynamic>)
              ?TranscriptSyncRecord.fromJson(entry),
      ],
      extraJson: {
        for (final entry in json.entries)
          if (entry.key != 'records') entry.key: entry.value,
      },
    );
  }

  /// Purpose: Write the document out.
  /// Inputs: None.
  /// Returns: The JSON map.
  /// Side effects: None.
  /// Notes: **Sorted by id.** The merge returns records in set-iteration order,
  /// which is stable within one run but says nothing across devices; without
  /// this, two devices holding identical data would encode it differently, miss
  /// the engine's raw-equality fast path and re-upload each other's document
  /// for ever.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'records': [
      for (final record in [...records]..sort((a, b) => a.id.compareTo(b.id)))
        record.toJson(),
    ],
  };

  /// Purpose: Find one transcription.
  /// Inputs: The [id].
  /// Returns: The record, or null.
  /// Side effects: None.
  /// Notes: None.
  TranscriptSyncRecord? byId(String id) {
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
  }

  /// Every transcription id in this document.
  Set<String> get ids => {for (final record in records) record.id};
}

/// Fields [TranscriptSyncRecord] writes itself, so the rest are unknown.
const _knownRecordKeys = {'id', 'createdAt', 'modifiedAt', 'job', 'transcript'};

/// Purpose: Read a timestamp that may be missing or malformed.
/// Inputs: [value].
/// Returns: The UTC time, or the epoch.
/// Side effects: None.
/// Notes: Internal helper used within this file only. The epoch loses every
/// comparison, which is the safe way for a record with no usable time to behave.
DateTime _time(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
