/// Purpose: Install, check, list and remove the model packages on this device.
/// Inputs: Manifests, the models directory, a downloader.
/// Returns: Installed manifests, install progress, leases.
/// Side effects: Downloads, unpacks, renames and deletes under `models/`.
/// Notes: An install is assembled in a staging folder and renamed into place
/// in one step, so a half-installed package never exists under its own name
/// and a crash mid-install leaves the previous version usable. A package a
/// running job holds a lease on cannot be replaced or removed until the job
/// lets go (decision D17 of the local-models plan). See
/// `doc/en-us/features/local-models.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../app/data_modules.dart';
import '../../../shared/services/transcribe_storage.dart';
import '../models/artifact_manifest.dart';
import 'artifact_downloader.dart';

/// What an install is doing.
enum InstallStage {
  /// Checking there is room.
  checkingSpace,

  /// Fetching a file.
  downloading,

  /// Unpacking an archive.
  unpacking,

  /// Hashing what was installed.
  verifying,

  /// Renaming it into place.
  installing,

  /// Finished.
  done,
}

/// How far an install has got.
class InstallProgress {
  /// What it is doing.
  final InstallStage stage;

  /// Bytes downloaded so far across the whole package.
  final int receivedBytes;

  /// Bytes to download in total.
  final int totalBytes;

  /// Purpose: Create a progress report.
  /// Inputs: [stage], [receivedBytes], [totalBytes].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const InstallProgress(this.stage, this.receivedBytes, this.totalBytes);

  /// The fraction downloaded, from 0 to 1, or null before anything is known.
  double? get fraction =>
      totalBytes <= 0 ? null : (receivedBytes / totalBytes).clamp(0.0, 1.0);
}

/// The space an install needs, counted in its three phases.
class SpaceBudget {
  /// Bytes still to download.
  final int download;

  /// Bytes the archives unpack to, alongside the archives themselves.
  final int unpack;

  /// Bytes the rename into place needs beyond that — zero on one volume, and
  /// kept separate so a models folder on another volume is counted honestly.
  final int install;

  /// Purpose: Create a space budget.
  /// Inputs: [download], [unpack], [install].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SpaceBudget({
    required this.download,
    required this.unpack,
    required this.install,
  });

  /// The most the install has on disk at once.
  int get peak => download + unpack + install;
}

/// A running job's hold on a package.
class ArtifactLease {
  /// Purpose: Create a lease.
  /// Inputs: The [artifactId], and the [_release] callback.
  /// Returns: A new lease.
  /// Side effects: None.
  /// Notes: Created only by [ArtifactManager.lease].
  ArtifactLease._(this.artifactId, this._release);

  /// The package held.
  final String artifactId;

  final void Function() _release;
  bool _released = false;

  /// Purpose: Let go of the package.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Allows the package to be replaced or removed again.
  /// Notes: Idempotent.
  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}

/// Installs and removes model packages.
class ArtifactManager {
  /// Purpose: Create a manager.
  /// Inputs: Optional [modelsDir] resolver, [downloader], [freeSpace] probe,
  /// [platform] and [clock], all injectable for tests.
  /// Returns: A new manager.
  /// Side effects: None.
  /// Notes: [freeSpace] answers null when the platform gives no figure; the
  /// install then relies on the disk-full error of the write itself, which the
  /// downloader and the unpacker both turn into [ArtifactFailure.diskFull].
  ArtifactManager({
    Future<Directory> Function()? modelsDir,
    ArtifactDownloader? downloader,
    Future<int?> Function(Directory directory)? freeSpace,
    String? platform,
    DateTime Function()? clock,
  }) : _modelsDir = modelsDir ?? (() => TranscribeStorage.modelsDir()),
       _downloader = downloader ?? ArtifactDownloader(),
       _freeSpace = freeSpace ?? ((_) async => null),
       _platform = platform,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _modelsDir;
  final ArtifactDownloader _downloader;
  final Future<int?> Function(Directory) _freeSpace;
  final String? _platform;
  final DateTime Function() _clock;

  final _leases = <String, int>{};

  /// Purpose: Locate one package's folder.
  /// Inputs: [artifactId].
  /// Returns: `Future<Directory>`, which may not exist.
  /// Side effects: None.
  /// Notes: None.
  Future<Directory> artifactDir(String artifactId) async =>
      Directory(p.join((await _modelsDir()).path, _safeName(artifactId)));

  /// Purpose: Read an installed package's manifest.
  /// Inputs: [artifactId].
  /// Returns: The manifest, or null when the package is not installed or its
  /// manifest is unreadable.
  /// Side effects: Reads the file.
  /// Notes: A folder without a readable manifest counts as not installed — it
  /// is what a system purge of the caches directory leaves at worst.
  Future<ArtifactManifest?> installed(String artifactId) async {
    final file = File(p.join((await artifactDir(artifactId)).path, _manifest));
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      final manifest = ArtifactManifest.fromJson(json);
      return manifest.artifactId == artifactId ? manifest : null;
    } catch (_) {
      return null;
    }
  }

  /// Purpose: List every installed package.
  /// Inputs: None.
  /// Returns: Their manifests, sorted by id.
  /// Side effects: Reads the models directory.
  /// Notes: None.
  Future<List<ArtifactManifest>> installedAll() async {
    final dir = await _modelsDir();
    if (!await dir.exists()) return const [];
    final result = <ArtifactManifest>[];
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (name.startsWith('.')) continue;
      final manifest = await installed(name);
      if (manifest != null) result.add(manifest);
    }
    return result..sort((a, b) => a.artifactId.compareTo(b.artifactId));
  }

  /// Purpose: Work out how much room an install needs from here.
  /// Inputs: [manifest].
  /// Returns: A [SpaceBudget].
  /// Side effects: Reads the sizes of any partial downloads.
  /// Notes: A partial download already on disk is subtracted, so a resumed
  /// install is not refused for space it has already used.
  Future<SpaceBudget> spaceNeeded(ArtifactManifest manifest) async {
    var download = 0;
    var unpack = 0;
    for (final file in manifest.filesFor(_platform)) {
      final partial = await _partialFile(manifest, file);
      final have = await partial.exists() ? await partial.length() : 0;
      download += (file.bytes - have).clamp(0, file.bytes);
      if (file.unpack != ArchiveKind.none) {
        unpack += file.unpackedBytes ?? file.bytes;
      }
    }
    return SpaceBudget(download: download, unpack: unpack, install: 0);
  }

  /// Purpose: Hold a package so it cannot be replaced or removed.
  /// Inputs: [artifactId].
  /// Returns: An [ArtifactLease] to release when the job is done with it.
  /// Side effects: Counts the lease.
  /// Notes: Leases count, so two holders both have to let go.
  ArtifactLease lease(String artifactId) {
    _leases[artifactId] = (_leases[artifactId] ?? 0) + 1;
    return ArtifactLease._(artifactId, () {
      final left = (_leases[artifactId] ?? 1) - 1;
      if (left <= 0) {
        _leases.remove(artifactId);
      } else {
        _leases[artifactId] = left;
      }
    });
  }

  /// Purpose: Report whether a package is held.
  /// Inputs: [artifactId].
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool isLeased(String artifactId) => (_leases[artifactId] ?? 0) > 0;

  /// Purpose: Download, verify, unpack and install a package.
  /// Inputs: [manifest], optional [onProgress] and [cancel].
  /// Returns: The installed manifest, with what was installed hashed.
  /// Side effects: Downloads into `models/.downloads/`, assembles the package
  /// in a staging folder, renames it into `models/<artifactId>/`, and removes
  /// the version it replaced.
  /// Notes: Only the URLs in [manifest] are contacted. Each file is verified
  /// before it is moved into the staging folder, and an archive is unpacked
  /// only after its own hash matched. Partial downloads survive a failure or a
  /// cancel, so the next attempt resumes them.
  Future<ArtifactManifest> install(
    ArtifactManifest manifest, {
    void Function(InstallProgress progress)? onProgress,
    DownloadCancelToken? cancel,
  }) async {
    final id = manifest.artifactId;
    if (id.isEmpty || _safeName(id) != id || manifest.files.isEmpty) {
      throw const ArtifactException(
        ArtifactFailure.badManifest,
        'The package manifest names no files or has an unusable id.',
      );
    }
    _refuseIfLeased(id);
    final files = manifest.filesFor(_platform);
    final total = files.fold<int>(0, (sum, file) => sum + file.bytes);

    // ── Space ──
    onProgress?.call(InstallProgress(InstallStage.checkingSpace, 0, total));
    final models = await _modelsDir();
    await models.create(recursive: true);
    final budget = await spaceNeeded(manifest);
    final free = await _freeSpace(models);
    if (free != null && free < budget.peak) {
      throw ArtifactException(
        ArtifactFailure.diskFull,
        'This model needs ${budget.peak} bytes free (download '
        '${budget.download}, unpacking ${budget.unpack}, install '
        '${budget.install}); $free are free.',
      );
    }

    // ── Download, verify, stage ──
    final staging = Directory(
      p.join(models.path, modelDownloadsDirName, '$id.staging'),
    );
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    final installedFiles = <InstalledFile>[];
    var done = 0;
    try {
      for (final file in files) {
        final relative = _safeRelative(file.path);
        final partial = await _partialFile(manifest, file);
        await _downloader.download(
          file,
          partial,
          cancel: cancel,
          onProgress: (received, _) => onProgress?.call(
            InstallProgress(InstallStage.downloading, done + received, total),
          ),
        );
        done += file.bytes;
        if (cancel?.isCancelled ?? false) {
          throw const ArtifactException(
            ArtifactFailure.cancelled,
            'Cancelled.',
          );
        }

        if (file.unpack == ArchiveKind.none) {
          final target = File(p.join(staging.path, relative));
          await target.parent.create(recursive: true);
          await partial.rename(target.path);
          installedFiles.add(
            InstalledFile(
              path: file.path,
              bytes: file.bytes,
              sha256: file.sha256,
            ),
          );
        } else {
          onProgress?.call(
            InstallProgress(InstallStage.unpacking, done, total),
          );
          await _unpack(file, partial, staging);
          await partial.delete();
        }
      }

      // ── Measure what was unpacked ──
      onProgress?.call(InstallProgress(InstallStage.verifying, done, total));
      final direct = {for (final f in installedFiles) f.path};
      await for (final entry in staging.list(recursive: true)) {
        if (entry is! File) continue;
        final relative = p
            .relative(entry.path, from: staging.path)
            .replaceAll(r'\', '/');
        if (direct.contains(relative)) continue;
        installedFiles.add(
          InstalledFile(
            path: relative,
            bytes: await entry.length(),
            sha256: await hashFile(entry),
          ),
        );
      }
      installedFiles.sort((a, b) => a.path.compareTo(b.path));

      final result = manifest.asInstalled(installedFiles, _clock());
      await File(p.join(staging.path, _manifest)).writeAsString(
        const JsonEncoder.withIndent('  ').convert(result.toJson()),
      );

      // ── Rename into place ──
      onProgress?.call(InstallProgress(InstallStage.installing, done, total));
      _refuseIfLeased(id);
      final target = await artifactDir(id);
      final old = Directory(
        p.join(models.path, modelDownloadsDirName, '$id.old'),
      );
      if (await old.exists()) await old.delete(recursive: true);
      if (await target.exists()) await target.rename(old.path);
      await staging.rename(target.path);
      if (await old.exists()) await old.delete(recursive: true);

      onProgress?.call(InstallProgress(InstallStage.done, total, total));
      return result;
    } on FileSystemException catch (error) {
      throw diskFullOr(error);
    } finally {
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Purpose: Check an installed package against what was installed.
  /// Inputs: [artifactId].
  /// Returns: `true` when every installed file is present with its recorded
  /// size and hash.
  /// Side effects: Reads every file of the package.
  /// Notes: Slow for a large package — it hashes gigabytes — so it runs when
  /// the user asks or a load fails, not before every job.
  Future<bool> verify(String artifactId) async {
    final manifest = await installed(artifactId);
    if (manifest == null || manifest.installed.isEmpty) return false;
    final dir = await artifactDir(artifactId);
    for (final file in manifest.installed) {
      final onDisk = File(p.join(dir.path, _safeRelative(file.path)));
      if (!await onDisk.exists()) return false;
      if (await onDisk.length() != file.bytes) return false;
      if (await hashFile(onDisk) != file.sha256) return false;
    }
    return true;
  }

  /// Purpose: Remove an installed package and its partial downloads.
  /// Inputs: [artifactId].
  /// Returns: None.
  /// Side effects: Deletes the package folder and anything of it under
  /// `.downloads/`.
  /// Notes: Refused while a job holds the package.
  Future<void> remove(String artifactId) async {
    _refuseIfLeased(artifactId);
    final dir = await artifactDir(artifactId);
    if (await dir.exists()) await dir.delete(recursive: true);
    final partials = Directory(
      p.join(
        (await _modelsDir()).path,
        modelDownloadsDirName,
        _safeName(artifactId),
      ),
    );
    if (await partials.exists()) await partials.delete(recursive: true);
  }

  /// Purpose: Refuse to touch a leased package.
  /// Inputs: [artifactId].
  /// Returns: None; throws when leased.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  void _refuseIfLeased(String artifactId) {
    if (isLeased(artifactId)) {
      throw const ArtifactException(
        ArtifactFailure.leased,
        'A transcription is using this model; it can be changed when that '
        'finishes.',
      );
    }
  }

  /// Purpose: Locate a file's partial download.
  /// Inputs: [manifest], [file].
  /// Returns: `Future<File>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Keyed by the file's
  /// hash as well as its name, so a manifest that changed a file never resumes
  /// the old file's bytes.
  Future<File> _partialFile(
    ArtifactManifest manifest,
    ArtifactFile file,
  ) async {
    final models = await _modelsDir();
    final name =
        '${p.basename(_safeRelative(file.path))}.'
        '${file.sha256.length >= 12 ? file.sha256.substring(0, 12) : file.sha256}'
        '.part';
    return File(
      p.join(
        models.path,
        modelDownloadsDirName,
        _safeName(manifest.artifactId),
        name,
      ),
    );
  }

  /// Purpose: Unpack a verified archive into the staging folder.
  /// Inputs: The manifest [file], the downloaded [archive], the [staging]
  /// folder.
  /// Returns: None.
  /// Side effects: Writes the archive's contents.
  /// Notes: Internal helper used within this file only. The archive is given
  /// its real extension first because the unpacker chooses its decoder by
  /// name. Entries that would land outside the staging folder are refused by
  /// the unpacker; anything it could not write surfaces as a failure rather
  /// than a package with a file missing.
  Future<void> _unpack(
    ArtifactFile file,
    File archive,
    Directory staging,
  ) async {
    final extension = switch (file.unpack) {
      ArchiveKind.zip => '.zip',
      ArchiveKind.tarBz2 => '.tar.bz2',
      ArchiveKind.none => '',
    };
    final named = await archive.rename('${archive.path}$extension');
    try {
      await extractFileToDisk(named.path, staging.path);
    } on FileSystemException {
      rethrow;
    } catch (error) {
      throw ArtifactException(
        ArtifactFailure.unpackFailed,
        '${file.path}: $error',
      );
    } finally {
      if (await named.exists()) await named.rename(archive.path);
    }
  }
}

/// The name of the manifest inside an installed package folder.
const _manifest = 'manifest.json';

/// Purpose: Make an id safe to use as a folder name.
/// Inputs: [id].
/// Returns: The id with anything but letters, digits, dot, dash and
/// underscore replaced.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Artifact ids are ours,
/// but a manifest from a file the user added is not.
String _safeName(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// Purpose: Check a manifest path stays inside the package folder.
/// Inputs: [path], with forward slashes.
/// Returns: A relative path in the platform's form.
/// Side effects: None.
/// Notes: Internal helper used within this file only. An absolute path or a
/// `..` segment is refused rather than cleaned, because a manifest that tries
/// either is not one to trust with anything else.
String _safeRelative(String path) {
  final parts = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      p.isAbsolute(path) ||
      parts.any((part) => part == '..' || part.isEmpty)) {
    throw ArtifactException(
      ArtifactFailure.badManifest,
      'The manifest names an unsafe path: $path',
    );
  }
  return p.joinAll(parts);
}
