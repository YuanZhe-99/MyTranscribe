/// Purpose: FluidAudio's Parakeet on the Apple Neural Engine, through the
/// prebuilt bridge, as a small synchronous API.
/// Inputs: A staged Core ML model folder; 16 kHz mono float samples.
/// Returns: `AppleAsrLibrary` and `AppleParakeetModel`.
/// Side effects: Loads native code and Core ML models; runs inference.
/// Notes: Every call blocks; the app's adapter runs them on a worker isolate
/// (decision D16 of the local-models plan). Only macOS and iOS have the
/// library; elsewhere [AppleAsrLibrary.version] answers null.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/apple_bindings.g.dart';

/// Why a bridge call failed.
class AppleAsrException implements Exception {
  /// What happened.
  final String message;

  /// Purpose: Create a failure.
  /// Inputs: [message].
  /// Returns: A new exception.
  /// Side effects: None.
  /// Notes: None.
  const AppleAsrException(this.message);

  /// Purpose: Render the failure.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  @override
  String toString() => 'AppleAsrException: $message';
}

/// The bridge library: whether this build has it.
class AppleAsrLibrary {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: None.
  const AppleAsrLibrary._();

  /// Purpose: The bridge's version, loading it.
  /// Inputs: None.
  /// Returns: e.g. `fluidaudio 0.17.4 lasr-apple 1`, or null when this target
  /// has no library.
  /// Side effects: Loads native code.
  /// Notes: A target the hook gave no asset throws [ArgumentError] at the
  /// first call; that is reported as null.
  static String? version() {
    try {
      return lasr_apple_version().cast<Utf8>().toDartString();
    } on ArgumentError {
      return null;
    }
  }
}

/// One token of a result: its text and times, in seconds.
typedef AppleToken = ({String piece, double start, double end});

/// A loaded Parakeet Core ML model.
class AppleParakeetModel {
  AppleParakeetModel._(this._handle);

  int _handle;

  /// Purpose: Load a staged Parakeet v3 Core ML folder.
  /// Inputs: The [folder] holding the `.mlmodelc` bundles and
  /// `parakeet_vocab.json`; whether to keep to the CPU ([cpuOnly]).
  /// Returns: The loaded model.
  /// Side effects: Loads the models; compiles nothing (they are compiled).
  /// Notes: Throws [AppleAsrException] when the folder does not load.
  static AppleParakeetModel load(String folder, {bool cpuOnly = false}) {
    final native = folder.toNativeUtf8();
    try {
      final handle = lasr_apple_load(native.cast(), cpuOnly ? 1 : 0);
      if (handle <= 0) {
        throw AppleAsrException('The models at $folder did not load.');
      }
      return AppleParakeetModel._(handle);
    } finally {
      calloc.free(native);
    }
  }

  /// Purpose: Transcribe samples.
  /// Inputs: 16 kHz mono [samples].
  /// Returns: The text and its tokens with times.
  /// Side effects: Runs the model.
  /// Notes: Blocks until done; throws [AppleAsrException] on failure.
  ({String text, List<AppleToken> tokens}) transcribe(Float32List samples) {
    if (_handle <= 0) throw const AppleAsrException('Released.');
    final buffer = calloc<Float>(samples.length);
    try {
      buffer.asTypedList(samples.length).setAll(0, samples);
      final result = lasr_apple_transcribe(_handle, buffer, samples.length);
      if (result == nullptr) {
        throw const AppleAsrException('The bridge returned nothing.');
      }
      final String json;
      try {
        json = result.cast<Utf8>().toDartString();
      } finally {
        lasr_apple_free(result);
      }
      final map = jsonDecode(json) as Map<String, dynamic>;
      if (map['error'] case final String error) {
        throw AppleAsrException(error);
      }
      return (
        text: '${map['text'] ?? ''}',
        tokens: [
          for (final token in (map['tokens'] as List? ?? const []))
            if (token case {
              't': final String t,
              's': final num s,
              'e': final num e,
            })
              (piece: t, start: s.toDouble(), end: e.toDouble()),
        ],
      );
    } finally {
      calloc.free(buffer);
    }
  }

  /// Purpose: Free the model.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees native memory.
  /// Notes: Safe to call more than once.
  void release() {
    if (_handle <= 0) return;
    lasr_apple_release(_handle);
    _handle = 0;
  }
}
