/// Purpose: The raw FFI bindings to the `lasr_whisper` shim.
/// Inputs: The code asset the build hook reports under this library's URI.
/// Returns: `external` functions, resolved on first call.
/// Side effects: Loading the asset loads whisper.cpp and ggml.
/// Notes: Hand-written against `src/lasr_whisper.h`, which takes plain types
/// only — there is no struct layout here to fall out of step with upstream.
/// Every call blocks; the caller runs them on a background isolate.
@DefaultAsset('package:local_asr_whisper/src/bindings.dart')
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// An opaque whisper context.
final class LasrContext extends Opaque {}

@Native<Int32 Function()>(symbol: 'lasr_load_backends')
external int lasrLoadBackends();

@Native<Void Function(Int32)>(symbol: 'lasr_set_logging')
external void lasrSetLogging(int enabled);

@Native<Int64 Function()>(symbol: 'lasr_available_memory')
external int lasrAvailableMemory();

@Native<Pointer<Utf8> Function()>(symbol: 'lasr_version')
external Pointer<Utf8> lasrVersion();

@Native<Pointer<Utf8> Function()>(symbol: 'lasr_system_info')
external Pointer<Utf8> lasrSystemInfo();

@Native<Int32 Function()>(symbol: 'lasr_device_count')
external int lasrDeviceCount();

@Native<Pointer<Utf8> Function(Int32)>(symbol: 'lasr_device_name')
external Pointer<Utf8> lasrDeviceName(int index);

@Native<Pointer<Utf8> Function(Int32)>(symbol: 'lasr_device_description')
external Pointer<Utf8> lasrDeviceDescription(int index);

@Native<Int32 Function(Int32)>(symbol: 'lasr_device_type')
external int lasrDeviceType(int index);

@Native<Pointer<LasrContext> Function(Pointer<Utf8>, Int32, Int32)>(
  symbol: 'lasr_load',
)
external Pointer<LasrContext> lasrLoad(
  Pointer<Utf8> modelPath,
  int useGpu,
  int flashAttn,
);

@Native<Void Function(Pointer<LasrContext>)>(symbol: 'lasr_free')
external void lasrFree(Pointer<LasrContext> context);

@Native<
  Int32 Function(
    Pointer<LasrContext>,
    Pointer<Float>,
    Int32,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Int32,
    Pointer<Int32>,
    Pointer<Int32>,
  )
>(symbol: 'lasr_transcribe')
external int lasrTranscribe(
  Pointer<LasrContext> context,
  Pointer<Float> samples,
  int sampleCount,
  Pointer<Utf8> language,
  Pointer<Utf8> prompt,
  int threads,
  Pointer<Int32> abortFlag,
  Pointer<Int32> progress,
);

@Native<Int32 Function(Pointer<LasrContext>)>(symbol: 'lasr_n_segments')
external int lasrSegmentCount(Pointer<LasrContext> context);

@Native<Int64 Function(Pointer<LasrContext>, Int32)>(symbol: 'lasr_segment_t0')
external int lasrSegmentStart(Pointer<LasrContext> context, int index);

@Native<Int64 Function(Pointer<LasrContext>, Int32)>(symbol: 'lasr_segment_t1')
external int lasrSegmentEnd(Pointer<LasrContext> context, int index);

@Native<Pointer<Utf8> Function(Pointer<LasrContext>, Int32)>(
  symbol: 'lasr_segment_text',
)
external Pointer<Utf8> lasrSegmentText(Pointer<LasrContext> context, int index);

@Native<Pointer<Utf8> Function(Pointer<LasrContext>)>(
  symbol: 'lasr_detected_language',
)
external Pointer<Utf8> lasrDetectedLanguage(Pointer<LasrContext> context);
