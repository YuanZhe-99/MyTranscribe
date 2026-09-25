/// Purpose: whisper.cpp for MyTranscribe!!!!!, as a small synchronous API.
/// Inputs: A model file path and 16 kHz mono float samples.
/// Returns: `WhisperModel`, `WhisperSegment`, `WhisperDevice` and helpers.
/// Side effects: Loads native libraries and models; runs inference.
/// Notes: Every call here blocks. The app's adapter runs them on a
/// long-lived background isolate that owns the model (decision D16 of the
/// local-models plan). Cancelling and progress go through two integers in
/// native memory ([WhisperControl]), which another isolate can reach by
/// address while a transcription runs.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/bindings.dart';

/// One timed piece of text, in seconds from the start of the samples.
class WhisperSegment {
  /// Where it starts.
  final double startSeconds;

  /// Where it ends.
  final double endSeconds;

  /// What was said.
  final String text;

  /// Purpose: Create a segment.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const WhisperSegment(this.startSeconds, this.endSeconds, this.text);
}

/// A compute device ggml found.
class WhisperDevice {
  /// Its name, e.g. `CPU` or `Metal`.
  final String name;

  /// What the backend says it is.
  final String description;

  /// 0 CPU, 1 GPU, 2 integrated GPU, 3 accelerator.
  final int type;

  /// Purpose: Create a device description.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const WhisperDevice(this.name, this.description, this.type);
}

/// Why a whisper call failed.
class WhisperException implements Exception {
  /// What happened.
  final String message;

  /// Purpose: Create a failure.
  /// Inputs: [message].
  /// Returns: A new exception.
  /// Side effects: None.
  /// Notes: None.
  const WhisperException(this.message);

  /// Purpose: Render the failure.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  @override
  String toString() => 'WhisperException: $message';
}

/// Thrown when a transcription stopped because it was cancelled.
class WhisperCancelled implements Exception {
  /// Purpose: Create the cancellation signal.
  /// Inputs: None.
  /// Returns: A new exception.
  /// Side effects: None.
  /// Notes: None.
  const WhisperCancelled();
}

/// The native library: whether it loads, and what it runs on.
class WhisperLibrary {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: None.
  const WhisperLibrary._();

  /// Purpose: Load the native library and ggml's backends.
  /// Inputs: None.
  /// Returns: The number of backends found, or null when this build or this
  /// target has no library.
  /// Side effects: Loads native code.
  /// Notes: A target the build hook skipped — a 32-bit phone — has no code
  /// asset; the first call then throws, and that is reported as null here
  /// rather than as a crash.
  static int? load() {
    try {
      return lasrLoadBackends();
    } on ArgumentError {
      return null;
    }
  }

  /// Purpose: Turn whisper.cpp's own log lines on or off.
  /// Inputs: [enabled].
  /// Returns: None.
  /// Side effects: Changes what the native side prints to stderr.
  /// Notes: Off by default; the live tests turn it on.
  static void setLogging(bool enabled) => lasrSetLogging(enabled ? 1 : 0);

  /// Purpose: whisper.cpp's version string.
  /// Inputs: None.
  /// Returns: e.g. `1.9.4`.
  /// Side effects: None.
  /// Notes: Call [load] first.
  static String version() => lasrVersion().toDartString();

  /// Purpose: How much memory this process could still use.
  /// Inputs: None.
  /// Returns: Bytes, or null when the platform gives no figure.
  /// Side effects: Reads OS counters.
  /// Notes: What the memory guard compares a model's documented need with.
  static int? availableMemory() {
    final bytes = lasrAvailableMemory();
    return bytes < 0 ? null : bytes;
  }

  /// Purpose: What the CPU backend was built with and what it found.
  /// Inputs: None.
  /// Returns: whisper.cpp's system-info line.
  /// Side effects: None.
  /// Notes: The evidence the placement is read from.
  static String systemInfo() => lasrSystemInfo().toDartString();

  /// Purpose: List the compute devices ggml found.
  /// Inputs: None.
  /// Returns: One [WhisperDevice] per device.
  /// Side effects: None.
  /// Notes: None.
  static List<WhisperDevice> devices() => [
    for (var i = 0; i < lasrDeviceCount(); i++)
      WhisperDevice(
        lasrDeviceName(i).toDartString(),
        lasrDeviceDescription(i).toDartString(),
        lasrDeviceType(i),
      ),
  ];
}

/// Two integers in native memory that steer a running transcription: an
/// abort flag it polls, and the percentage it reports.
class WhisperControl {
  /// Purpose: Allocate the control block.
  /// Inputs: None.
  /// Returns: A new control block.
  /// Side effects: Allocates eight bytes of native memory.
  /// Notes: Free it with [dispose] once nothing uses it.
  WhisperControl() : _memory = calloc<Int32>(2);

  /// Purpose: Wrap a control block another isolate allocated.
  /// Inputs: Its [address].
  /// Returns: A view of the same memory.
  /// Side effects: None.
  /// Notes: Never dispose a view; the owner does.
  WhisperControl.fromAddress(int address)
    : _memory = Pointer<Int32>.fromAddress(address);

  final Pointer<Int32> _memory;

  /// Its address, to hand to another isolate.
  int get address => _memory.address;

  /// Ask the running transcription to stop at its next check.
  void cancel() => _memory[0] = 1;

  /// Clear the abort flag and the progress before a new run.
  void reset() {
    _memory[0] = 0;
    _memory[1] = 0;
  }

  /// Whether a stop was asked for.
  bool get isCancelled => _memory[0] != 0;

  /// How far the running transcription is, from 0 to 100.
  int get progress => _memory[1];

  /// Purpose: Free the memory.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees native memory.
  /// Notes: Only the allocating side calls this.
  void dispose() => calloc.free(_memory);
}

/// A loaded model.
class WhisperModel {
  WhisperModel._(this._context);

  Pointer<LasrContext> _context;

  /// Purpose: Load a model file.
  /// Inputs: The GGML [path]; whether to allow a GPU backend.
  /// Returns: The loaded model.
  /// Side effects: Reads the file; allocates the model's memory.
  /// Notes: Throws [WhisperException] when the file does not load — a missing
  /// file, a damaged one, or not enough memory, which whisper.cpp does not
  /// tell apart.
  static WhisperModel load(String path, {bool useGpu = false}) {
    final native = path.toNativeUtf8();
    try {
      final context = lasrLoad(native, useGpu ? 1 : 0, 0);
      if (context == nullptr) {
        throw WhisperException('The model at $path did not load.');
      }
      return WhisperModel._(context);
    } finally {
      calloc.free(native);
    }
  }

  /// Purpose: Transcribe samples.
  /// Inputs: 16 kHz mono [samples] from -1 to 1; the [language] code or null
  /// to detect; an optional [prompt]; the [threads]; the [control] block.
  /// Returns: The segments, in order.
  /// Side effects: Runs the model; writes progress into [control].
  /// Notes: Blocks until done. Throws [WhisperCancelled] when [control] was
  /// cancelled, [WhisperException] on any other failure.
  List<WhisperSegment> transcribe(
    Float32List samples, {
    String? language,
    String? prompt,
    int threads = 4,
    WhisperControl? control,
  }) {
    if (_context == nullptr) throw const WhisperException('Released.');
    final buffer = calloc<Float>(samples.length);
    final lang = (language ?? '').toNativeUtf8();
    final context = (prompt ?? '').toNativeUtf8();
    try {
      buffer.asTypedList(samples.length).setAll(0, samples);
      final result = lasrTranscribe(
        _context,
        buffer,
        samples.length,
        lang,
        context,
        threads,
        control == null ? nullptr : Pointer<Int32>.fromAddress(control.address),
        control == null
            ? nullptr
            : Pointer<Int32>.fromAddress(control.address + 4),
      );
      if (result == 1) throw const WhisperCancelled();
      if (result != 0) {
        throw WhisperException('whisper_full failed with code $result.');
      }
      final count = lasrSegmentCount(_context);
      return [
        for (var i = 0; i < count; i++)
          WhisperSegment(
            lasrSegmentStart(_context, i) / 100,
            lasrSegmentEnd(_context, i) / 100,
            lasrSegmentText(_context, i).toDartString(),
          ),
      ];
    } finally {
      calloc.free(buffer);
      calloc.free(lang);
      calloc.free(context);
    }
  }

  /// Purpose: The language the last run detected.
  /// Inputs: None.
  /// Returns: A code such as `en`, or empty.
  /// Side effects: None.
  /// Notes: None.
  String detectedLanguage() => lasrDetectedLanguage(_context).toDartString();

  /// Purpose: Free the model.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees native memory.
  /// Notes: Safe to call more than once; only after a transcription returned.
  void release() {
    if (_context == nullptr) return;
    lasrFree(_context);
    _context = nullptr;
  }
}
