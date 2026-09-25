/// Purpose: What one downloadable model package is — its files, their sizes and
/// hashes, where they come from, and under what licence.
/// Inputs: A built-in template's manifest, or `models/<artifactId>/manifest.json`.
/// Returns: `ArtifactManifest`, `ArtifactFile`, `InstalledFile` and the enums
/// that go with them.
/// Side effects: None.
/// Notes: Downloads come only from the URLs in a manifest, and every file is
/// checked against the SHA-256 written here before it is installed (decision
/// D17 of the local-models plan). The template's manifest describes what to
/// fetch; the one written into the installed folder adds what was actually
/// unpacked, hashed on this device, so a later check has something to compare
/// against. See `doc/en-us/data-formats.md`.
library;

import '../../../shared/utils/platform_capabilities.dart';
import 'engine_capability.dart';

/// The on-disk format of a package, as its adapter reads it.
enum ArtifactFormat {
  /// whisper.cpp's GGML file.
  ggml,

  /// ONNX models, as sherpa-onnx and ONNX Runtime load them.
  onnx,

  /// A compiled Core ML model.
  coreml,

  /// A Qualcomm context binary wrapped in ONNX.
  qnn,

  /// A format this build does not know.
  unknown;

  /// Purpose: Parse a persisted format.
  /// Inputs: [value].
  /// Returns: The format, or [unknown].
  /// Side effects: None.
  /// Notes: None.
  static ArtifactFormat parse(Object? value) {
    for (final format in ArtifactFormat.values) {
      if (format != unknown && format.name == value) return format;
    }
    return unknown;
  }
}

/// Whether a downloaded file is an archive to unpack.
enum ArchiveKind {
  /// Installed as it is.
  none,

  /// A ZIP, unpacked in place — the Core ML encoder folders are shipped so.
  zip,

  /// A bzip2-compressed tar, as sherpa-onnx publishes its models.
  tarBz2;

  /// Purpose: Parse a persisted archive kind.
  /// Inputs: [value].
  /// Returns: The kind; anything unrecognised reads as [none].
  /// Side effects: None.
  /// Notes: None.
  static ArchiveKind parse(Object? value) {
    for (final kind in ArchiveKind.values) {
      if (kind.name == value) return kind;
    }
    return none;
  }
}

/// One file to download.
class ArtifactFile {
  /// Where it goes inside the package folder, with forward slashes.
  final String path;

  /// Its exact size in bytes.
  final int bytes;

  /// Its SHA-256, lower-case hex.
  final String sha256;

  /// The one URL it may be fetched from, pinned to a revision.
  final String sourceUrl;

  /// The platforms that need it, by [platformId]; empty means all.
  final List<String> platforms;

  /// Whether it is an archive to unpack.
  final ArchiveKind unpack;

  /// The size of what it unpacks to, in bytes, when known.
  ///
  /// Counted in the disk-space check separately from the download, because
  /// the archive and its contents exist side by side until the archive is
  /// deleted.
  final int? unpackedBytes;

  /// Purpose: Create a file entry.
  /// Inputs: All fields; the first four are required.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ArtifactFile({
    required this.path,
    required this.bytes,
    required this.sha256,
    required this.sourceUrl,
    this.platforms = const [],
    this.unpack = ArchiveKind.none,
    this.unpackedBytes,
  });

  /// Purpose: Report whether this platform needs the file.
  /// Inputs: [platform], defaulting to this one.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool appliesTo([String? platform]) =>
      platforms.isEmpty || platforms.contains(platform ?? platformId);

  /// Purpose: Parse a file entry.
  /// Inputs: [json].
  /// Returns: An [ArtifactFile].
  /// Side effects: None.
  /// Notes: None.
  factory ArtifactFile.fromJson(Map<String, dynamic> json) => ArtifactFile(
    path: json['path'] as String? ?? '',
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    sha256: (json['sha256'] as String? ?? '').toLowerCase(),
    sourceUrl: json['sourceUrl'] as String? ?? '',
    platforms: [
      for (final item in (json['platforms'] as List?) ?? const [])
        if (item is String) item,
    ],
    unpack: ArchiveKind.parse(json['unpack']),
    unpackedBytes: (json['unpackedBytes'] as num?)?.toInt(),
  );

  /// Purpose: Serialize a file entry.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'path': path,
    'bytes': bytes,
    'sha256': sha256,
    'sourceUrl': sourceUrl,
    if (platforms.isNotEmpty) 'platforms': platforms,
    if (unpack != ArchiveKind.none) 'unpack': unpack.name,
    if (unpackedBytes != null) 'unpackedBytes': unpackedBytes,
  };
}

/// One file as it was installed on this device.
class InstalledFile {
  /// Its path inside the package folder, with forward slashes.
  final String path;

  /// Its size in bytes.
  final int bytes;

  /// Its SHA-256 as measured here after unpacking.
  final String sha256;

  /// Purpose: Create an installed-file entry.
  /// Inputs: [path], [bytes], [sha256].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const InstalledFile({
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  /// Purpose: Parse an installed-file entry.
  /// Inputs: [json].
  /// Returns: An [InstalledFile].
  /// Side effects: None.
  /// Notes: None.
  factory InstalledFile.fromJson(Map<String, dynamic> json) => InstalledFile(
    path: json['path'] as String? ?? '',
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    sha256: json['sha256'] as String? ?? '',
  );

  /// Purpose: Serialize an installed-file entry.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'path': path,
    'bytes': bytes,
    'sha256': sha256,
  };
}

/// Keys this build writes at the top level of a manifest.
const _knownKeys = {
  'artifactId',
  'modelId',
  'adapterId',
  'format',
  'quantization',
  'revision',
  'files',
  'licenseId',
  'licenseUrl',
  'attribution',
  'minimumRamBytes',
  'ramEstimateSource',
  'installedAt',
  'installed',
};

/// One downloadable model package.
class ArtifactManifest {
  /// The package's id, and the name of its folder under `models/`.
  final String artifactId;

  /// The model record it serves.
  final String modelId;

  /// The adapter that loads it.
  final String adapterId;

  /// Its format.
  final ArtifactFormat format;

  /// Its quantization, e.g. `f16`, `q5_0`, `int8`.
  final String quantization;

  /// The upstream revision its URLs are pinned to.
  ///
  /// Part of a job's plan fingerprint, so an updated package discards cached
  /// windows exactly as a changed prompt does.
  final String revision;

  /// The files to download.
  final List<ArtifactFile> files;

  /// The SPDX id of the model's licence.
  final String licenseId;

  /// Where the licence text is published.
  final String licenseUrl;

  /// The attribution the licence asks for, in the publisher's words.
  final String attribution;

  /// The memory a loaded session needs, in bytes, when known.
  ///
  /// The memory guard refuses to load a package whose figure exceeds what the
  /// device has, with the numbers, rather than letting the system kill the app.
  final int? minimumRamBytes;

  /// Where [minimumRamBytes] came from.
  final EstimateSource ramEstimateSource;

  /// When it was installed here, in UTC; null in a template.
  final DateTime? installedAt;

  /// What was actually installed, hashed here; empty in a template.
  final List<InstalledFile> installed;

  /// Fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a manifest.
  /// Inputs: All fields; the identity fields are required.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ArtifactManifest({
    required this.artifactId,
    required this.modelId,
    required this.adapterId,
    required this.format,
    required this.revision,
    required this.files,
    required this.licenseId,
    this.quantization = '',
    this.licenseUrl = '',
    this.attribution = '',
    this.minimumRamBytes,
    this.ramEstimateSource = EstimateSource.unknown,
    this.installedAt,
    this.installed = const [],
    this.extraJson = const {},
  });

  /// Purpose: List the files this platform downloads.
  /// Inputs: [platform], defaulting to this one.
  /// Returns: The applicable [files].
  /// Side effects: None.
  /// Notes: None.
  List<ArtifactFile> filesFor([String? platform]) => [
    for (final file in files)
      if (file.appliesTo(platform)) file,
  ];

  /// Purpose: Add up what this platform downloads.
  /// Inputs: [platform], defaulting to this one.
  /// Returns: Bytes.
  /// Side effects: None.
  /// Notes: None.
  int downloadBytesFor([String? platform]) =>
      filesFor(platform).fold(0, (sum, file) => sum + file.bytes);

  /// Purpose: Return a copy recording what was installed.
  /// Inputs: [installed], [installedAt].
  /// Returns: A new [ArtifactManifest].
  /// Side effects: None.
  /// Notes: None.
  ArtifactManifest asInstalled(
    List<InstalledFile> installed,
    DateTime installedAt,
  ) => ArtifactManifest(
    artifactId: artifactId,
    modelId: modelId,
    adapterId: adapterId,
    format: format,
    revision: revision,
    files: files,
    licenseId: licenseId,
    quantization: quantization,
    licenseUrl: licenseUrl,
    attribution: attribution,
    minimumRamBytes: minimumRamBytes,
    ramEstimateSource: ramEstimateSource,
    installedAt: installedAt.toUtc(),
    installed: installed,
    extraJson: extraJson,
  );

  /// Purpose: Parse a manifest.
  /// Inputs: [json].
  /// Returns: An [ArtifactManifest].
  /// Side effects: None.
  /// Notes: Unknown fields are kept, so a manifest written by a newer build is
  /// rewritten intact.
  factory ArtifactManifest.fromJson(Map<String, dynamic> json) =>
      ArtifactManifest(
        artifactId: json['artifactId'] as String? ?? '',
        modelId: json['modelId'] as String? ?? '',
        adapterId: json['adapterId'] as String? ?? '',
        format: ArtifactFormat.parse(json['format']),
        quantization: json['quantization'] as String? ?? '',
        revision: json['revision'] as String? ?? '',
        files: [
          for (final item in (json['files'] as List?) ?? const [])
            if (item is Map<String, dynamic>) ArtifactFile.fromJson(item),
        ],
        licenseId: json['licenseId'] as String? ?? '',
        licenseUrl: json['licenseUrl'] as String? ?? '',
        attribution: json['attribution'] as String? ?? '',
        minimumRamBytes: (json['minimumRamBytes'] as num?)?.toInt(),
        ramEstimateSource: EstimateSource.parse(json['ramEstimateSource']),
        installedAt: DateTime.tryParse('${json['installedAt']}')?.toUtc(),
        installed: [
          for (final item in (json['installed'] as List?) ?? const [])
            if (item is Map<String, dynamic>) InstalledFile.fromJson(item),
        ],
        extraJson: {
          for (final e in json.entries)
            if (!_knownKeys.contains(e.key)) e.key: e.value,
        },
      );

  /// Purpose: Serialize a manifest.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Unknown fields first, so a known key wins a collision.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'artifactId': artifactId,
    'modelId': modelId,
    'adapterId': adapterId,
    'format': format.name,
    if (quantization.isNotEmpty) 'quantization': quantization,
    'revision': revision,
    'files': [for (final file in files) file.toJson()],
    'licenseId': licenseId,
    if (licenseUrl.isNotEmpty) 'licenseUrl': licenseUrl,
    if (attribution.isNotEmpty) 'attribution': attribution,
    if (minimumRamBytes != null) 'minimumRamBytes': minimumRamBytes,
    'ramEstimateSource': ramEstimateSource.name,
    if (installedAt != null) 'installedAt': installedAt!.toIso8601String(),
    if (installed.isNotEmpty)
      'installed': [for (final file in installed) file.toJson()],
  };
}
