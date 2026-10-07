/// Purpose: Cut one window of the normalized recording as the PCM a local
/// engine takes, and read it back.
/// Inputs: The media toolkit, the normalized file, a window.
/// Returns: A `PcmWindow` describing the file written, and its samples.
/// Side effects: Runs FFmpeg; reads the WAV it wrote.
/// Notes: Every local engine receives 16 kHz mono 16-bit PCM cut by FFmpeg,
/// never the original file (decision D5 of the local-models plan). The header
/// is checked here rather than trusted, because an engine fed the wrong rate
/// transcribes nonsense without an error. See
/// `doc/en-us/features/media-tools.md`.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:myapps_ai_asr/myapps_ai_asr.dart' as shared;

import '../../media/services/media_toolkit.dart';

/// The sample rate every local engine takes.
const pcmSampleRate = 16000;

/// A window written as PCM.
class PcmWindow {
  /// The WAV file.
  final File file;

  /// Samples per second; always [pcmSampleRate] once checked.
  final int sampleRate;

  /// Channels; always one once checked.
  final int channels;

  /// Bits per sample; always 16 once checked.
  final int bitsPerSample;

  /// Where the samples start in the file, in bytes.
  final int dataOffset;

  /// How many samples there are.
  final int sampleCount;

  /// Purpose: Create a window description.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const PcmWindow({
    required this.file,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.sampleCount,
  });

  /// Its length, in seconds.
  double get seconds => sampleRate == 0 ? 0 : sampleCount / sampleRate;

  /// Purpose: Read the samples as floats from -1 to 1.
  /// Inputs: None.
  /// Returns: A [Float32List] of [sampleCount] samples.
  /// Side effects: Reads the file.
  /// Notes: The form whisper.cpp and sherpa-onnx both take. A ten-minute
  /// window is 9.6 million samples — 38 MB as floats — which is why windows
  /// are bounded and not whole recordings.
  Future<Float32List> readSamples() async {
    final bytes = await file.readAsBytes();
    final data = ByteData.sublistView(bytes, dataOffset);
    final samples = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}

/// Purpose: Read and check the header of a 16 kHz mono 16-bit WAV.
/// Inputs: [file].
/// Returns: A [PcmWindow].
/// Side effects: Reads the file.
/// Notes: Walks the RIFF chunks rather than assuming a 44-byte header, since
/// an FFmpeg build may add a chunk before the samples. Throws
/// [MediaException] with [MediaFailureKind.toolError] for anything that is not
/// exactly the format local engines take.
Future<PcmWindow> readPcmWindow(File file) async {
  try {
    final window = await shared.readPcmWindow(file);
    return PcmWindow(
      file: window.file,
      sampleRate: window.sampleRate,
      channels: window.channels,
      bitsPerSample: window.bitsPerSample,
      dataOffset: window.dataOffset,
      sampleCount: window.sampleCount,
    );
  } on shared.PcmFormatException catch (error) {
    throw MediaException(MediaFailureKind.toolError, error.message);
  }
}

/// Cuts PCM windows.
class PcmWindowCutter {
  /// The toolkit that runs FFmpeg.
  final MediaToolkit toolkit;

  /// Purpose: Create a cutter.
  /// Inputs: [toolkit].
  /// Returns: A new cutter.
  /// Side effects: None.
  /// Notes: None.
  const PcmWindowCutter(this.toolkit);

  /// Purpose: Write one window as PCM and check what was written.
  /// Inputs: The normalized [source], the window's [startSeconds] and
  /// [lengthSeconds], the [destination], and optional [cancel].
  /// Returns: The checked [PcmWindow].
  /// Side effects: Runs FFmpeg; writes [destination]; deletes it when the
  /// check fails.
  /// Notes: A window already on disk that passes the check is reused, which is
  /// what makes a resumed job skip re-cutting.
  Future<PcmWindow> cut(
    String source,
    double startSeconds,
    double lengthSeconds,
    File destination, {
    MediaCancelToken? cancel,
  }) async {
    if (await destination.exists()) {
      try {
        return await readPcmWindow(destination);
      } on MediaException {
        await destination.delete();
      }
    }
    await toolkit.extractWindow(
      source,
      startSeconds,
      lengthSeconds,
      destination.path,
      cancel: cancel,
      format: WindowFormat.pcm16kMono,
    );
    try {
      return await readPcmWindow(destination);
    } on MediaException {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }
}
