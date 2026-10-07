import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:myapps_ai_models/myapps_ai_models.dart' as shared;

import '../models/artifact_manifest.dart';

export 'package:myapps_ai_models/myapps_ai_models.dart'
    show
        ArtifactFailure,
        ArtifactException,
        DownloadCancelToken,
        DownloadProgress;

/// Application download facade using the shared verified downloader.
class ArtifactDownloader {
  final shared.ArtifactDownloader sharedDownloader;

  /// Purpose: Create a downloader. Inputs: HTTP factory and timeouts.
  /// Returns: Downloader. Side effects: None. Notes: Downloads remain explicit.
  ArtifactDownloader({
    http.Client Function()? clientFactory,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration stallTimeout = const Duration(seconds: 60),
  }) : sharedDownloader = shared.ArtifactDownloader(
         clientFactory: clientFactory ?? http.Client.new,
         connectTimeout: connectTimeout,
         stallTimeout: stallTimeout,
       );

  /// Purpose: Fetch and verify a file. Inputs: file, partial, progress, cancel.
  /// Returns: Verified partial. Side effects: HTTP and disk. Notes: Resumes safely.
  Future<File> download(
    ArtifactFile file,
    File partial, {
    shared.DownloadProgress? onProgress,
    shared.DownloadCancelToken? cancel,
  }) => sharedDownloader.download(
    shared.ArtifactFile.fromJson(file.toJson()),
    partial,
    onProgress: onProgress,
    cancel: cancel,
  );
}
