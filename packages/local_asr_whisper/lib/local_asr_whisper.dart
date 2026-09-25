/// Purpose: whisper.cpp for MyTranscribe!!!!!, as a small synchronous API.
/// Inputs: A model file path and 16 kHz mono float samples.
/// Returns: `WhisperModel`, `WhisperSegment`, `WhisperDevice` and helpers.
/// Side effects: Loads native libraries and models; runs inference.
/// Notes: Every call here blocks. The app's adapter runs them on a
/// long-lived background isolate that owns the model (decision D16 of the
/// local-models plan). Cancelling and progress go through two integers in
/// native memory ([WhisperControl]), which another isolate can reach by
/// address while a transcription runs. The libraries are upstream's own
/// prebuilt ones, or this project's build of the same version, bound directly
/// through bindings generated from that version's headers (decision D21).
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/native.dart';
import 'src/whisper_bindings.g.dart';

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

  static bool _loaded = false;

  /// Purpose: Load the native library and ggml's backends, and check that
  /// the library is the one these bindings were generated for.
  /// Inputs: None.
  /// Returns: The number of backends found, or null when this build or this
  /// target has no library.
  /// Side effects: Loads native code.
  /// Notes: A target the build hook skipped — a 32-bit phone — has no code
  /// asset; the first call then throws, and that is reported as null here
  /// rather than as a crash. Throws [WhisperException] when the layout check
  /// fails: calling into a library whose structs differ from the bindings
  /// would corrupt memory, so nothing is called after that.
  static int? load() {
    try {
      whisper_version();
    } on ArgumentError {
      return null;
    }
    if (!_loaded) {
      _checkLayout();
      // Apple's binary has its backends linked in; elsewhere the CPU
      // variants are libraries beside this one, and ggml would otherwise look
      // beside the executable.
      final dir = libraryDirectory();
      if (dir != null && !Platform.isMacOS && !Platform.isIOS) {
        final native = dir.toNativeUtf8();
        try {
          ggml().ggml_backend_load_all_from_path(native.cast());
        } finally {
          calloc.free(native);
        }
      }
      _loaded = true;
    }
    return ggml().ggml_backend_reg_count();
  }

  /// Purpose: whisper.cpp's version string.
  /// Inputs: None.
  /// Returns: e.g. `1.9.4`.
  /// Side effects: None.
  /// Notes: Call [load] first.
  static String version() => whisper_version().cast<Utf8>().toDartString();

  /// Purpose: How much memory this process could still use.
  /// Inputs: None.
  /// Returns: Bytes, or null when the platform gives no figure.
  /// Side effects: Reads OS counters.
  /// Notes: What the memory guard compares a model's documented need with.
  static int? availableMemory() => availableMemoryBytes();

  /// Purpose: What the CPU backend was built with and what it found.
  /// Inputs: None.
  /// Returns: whisper.cpp's system-info line.
  /// Side effects: None.
  /// Notes: The evidence the placement is read from. Call [load] first.
  static String systemInfo() =>
      whisper_print_system_info().cast<Utf8>().toDartString();

  /// Purpose: List the compute devices ggml found.
  /// Inputs: None.
  /// Returns: One [WhisperDevice] per device.
  /// Side effects: None.
  /// Notes: Call [load] first.
  static List<WhisperDevice> devices() {
    final bindings = ggml();
    return [
      for (var i = 0; i < bindings.ggml_backend_dev_count(); i++)
        if (bindings.ggml_backend_dev_get(i) case final device)
          WhisperDevice(
            bindings.ggml_backend_dev_name(device).cast<Utf8>().toDartString(),
            bindings
                .ggml_backend_dev_description(device)
                .cast<Utf8>()
                .toDartString(),
            bindings.ggml_backend_dev_type$1(device).value,
          ),
    ];
  }

  /// Purpose: Compare whisper.cpp's default parameters, read through the
  /// generated structs, with the values its source documents.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Calls two functions that only return values.
  /// Notes: The structs travel by value, so a library whose layout differs
  /// from the bindings — a different version than `native/binaries.json`
  /// pins — would read and write the wrong fields. Fields at the start, the
  /// middle and the end of each struct are checked, so a shift anywhere shows.
  static void _checkLayout() {
    final full = whisper_full_default_params(
      whisper_sampling_strategy.WHISPER_SAMPLING_GREEDY,
    );
    final context = whisper_context_default_params();
    bool near(double value, double expected) => (value - expected).abs() < 1e-6;
    final checks = <String, bool>{
      'strategy': full.strategyAsInt == 0,
      'n_max_text_ctx': full.n_max_text_ctx == 16384,
      'no_context': full.no_context && !full.translate,
      'thold_pt': near(full.thold_pt, 0.01),
      'language':
          full.language != nullptr &&
          full.language.cast<Utf8>().toDartString() == 'en',
      'temperature_inc': near(full.temperature_inc, 0.2),
      'entropy_thold': near(full.entropy_thold, 2.4),
      'no_speech_thold': near(full.no_speech_thold, 0.6),
      'greedy.best_of': full.greedy.best_of == 5,
      'beam_search':
          full.beam_search.beam_size == -1 &&
          near(full.beam_search.patience, -1),
      'grammar_penalty': near(full.grammar_penalty, 100),
      'vad_params':
          !full.vad &&
          near(full.vad_params.threshold, 0.5) &&
          full.vad_params.min_speech_duration_ms == 250 &&
          full.vad_params.speech_pad_ms == 30,
      'context.use_gpu': context.use_gpu && context.gpu_device == 0,
      'context.dtw':
          context.dtw_n_top == -1 && context.dtw_mem_size == 1024 * 1024 * 128,
    };
    final wrong = [
      for (final MapEntry(:key, :value) in checks.entries)
        if (!value) key,
    ];
    if (wrong.isNotEmpty) {
      throw WhisperException(
        'The whisper.cpp library does not match its bindings '
        '(${wrong.join(', ')}); it is not used.',
      );
    }
  }
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

/// Purpose: whisper.cpp's abort check: whether the control block asks to stop.
/// Inputs: The control block's address, as whisper.cpp's user data.
/// Returns: `true` to stop.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Called on the thread
/// that called `whisper_full` — whisper.cpp's own loop, and ggml's CPU backend
/// only on thread 0, which is the caller — so an isolate-local callable is
/// legal here, and the flag it reads is written by another isolate.
bool _shouldAbort(Pointer<Void> control) => control.cast<Int32>()[0] != 0;

/// Purpose: whisper.cpp's progress report, written into the control block.
/// Inputs: The context, the state, the [progress] percentage, and the control
/// block's address.
/// Returns: None.
/// Side effects: Writes the percentage where another isolate reads it.
/// Notes: Internal helper used within this file only; same thread as
/// [_shouldAbort].
void _reportProgress(
  Pointer<whisper_context> context,
  Pointer<whisper_state> state,
  int progress,
  Pointer<Void> control,
) => control.cast<Int32>()[1] = progress;

/// The two callables, created once per isolate on first use.
final _abortCallback =
    NativeCallable<Bool Function(Pointer<Void>)>.isolateLocal(
      _shouldAbort,
      exceptionalReturn: false,
    );
final _progressCallback =
    NativeCallable<
      Void Function(
        Pointer<whisper_context>,
        Pointer<whisper_state>,
        Int,
        Pointer<Void>,
      )
    >.isolateLocal(_reportProgress);

/// A loaded model.
class WhisperModel {
  WhisperModel._(this._context);

  Pointer<whisper_context> _context;

  /// Purpose: Load a model file.
  /// Inputs: The GGML [path]; whether to allow a GPU backend.
  /// Returns: The loaded model.
  /// Side effects: Reads the file; allocates the model's memory.
  /// Notes: Throws [WhisperException] when the file does not load — a missing
  /// file, a damaged one, or not enough memory, which whisper.cpp does not
  /// tell apart. Flash attention stays off, as the routes were measured.
  static WhisperModel load(String path, {bool useGpu = false}) {
    WhisperLibrary.load();
    final params = whisper_context_default_params()
      ..use_gpu = useGpu
      ..flash_attn = false;
    final native = path.toNativeUtf8();
    try {
      final context = whisper_init_from_file_with_params(native.cast(), params);
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
    final lang = (language == null || language.isEmpty ? 'auto' : language)
        .toNativeUtf8();
    final context = prompt == null || prompt.isEmpty
        ? nullptr
        : prompt.toNativeUtf8();
    final user = control == null
        ? nullptr
        : Pointer<Void>.fromAddress(control.address);
    try {
      buffer.asTypedList(samples.length).setAll(0, samples);
      final params =
          whisper_full_default_params(
              whisper_sampling_strategy.WHISPER_SAMPLING_GREEDY,
            )
            ..n_threads = threads > 0 ? threads : 4
            ..print_progress = false
            ..print_realtime = false
            ..print_timestamps = false
            ..print_special = false
            ..translate = false
            ..no_context = true
            ..language = lang.cast()
            ..detect_language = false
            ..initial_prompt = context.cast();
      if (user != nullptr) {
        params
          ..abort_callback = _abortCallback.nativeFunction
          ..abort_callback_user_data = user
          ..progress_callback = _progressCallback.nativeFunction
          ..progress_callback_user_data = user;
      }
      final result = whisper_full(_context, params, buffer, samples.length);
      if (result != 0 && (control?.isCancelled ?? false)) {
        throw const WhisperCancelled();
      }
      if (result != 0) {
        throw WhisperException('whisper_full failed with code $result.');
      }
      final count = whisper_full_n_segments(_context);
      return [
        for (var i = 0; i < count; i++)
          WhisperSegment(
            whisper_full_get_segment_t0(_context, i) / 100,
            whisper_full_get_segment_t1(_context, i) / 100,
            whisper_full_get_segment_text(
              _context,
              i,
            ).cast<Utf8>().toDartString(),
          ),
      ];
    } finally {
      calloc.free(buffer);
      calloc.free(lang);
      if (context != nullptr) calloc.free(context);
    }
  }

  /// Purpose: The language the last run detected.
  /// Inputs: None.
  /// Returns: A code such as `en`, or empty.
  /// Side effects: None.
  /// Notes: None.
  String detectedLanguage() {
    if (_context == nullptr) return '';
    final id = whisper_full_lang_id(_context);
    return id < 0 ? '' : whisper_lang_str(id).cast<Utf8>().toDartString();
  }

  /// Purpose: Free the model.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees native memory.
  /// Notes: Safe to call more than once; only after a transcription returned.
  void release() {
    if (_context == nullptr) return;
    whisper_free(_context);
    _context = nullptr;
  }
}
