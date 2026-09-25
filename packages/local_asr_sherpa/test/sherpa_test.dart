/// Purpose: Prove sherpa-onnx's prebuilt library loads on this host and, given
/// a Qwen3-ASR package, transcribes whisper.cpp's JFK sample.
/// Inputs: The `QWEN_TEST_DIR` environment variable: the unpacked
/// `sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25` folder. Without it the
/// transcription test skips.
/// Returns: None.
/// Side effects: The hook downloads the prebuilt libraries on first run.
/// Notes: Run with `dart test` in this package.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:local_asr_sherpa/local_asr_sherpa.dart';
import 'package:test/test.dart';

/// Purpose: Read a 16 kHz mono 16-bit WAV as floats.
/// Inputs: [file].
/// Returns: The samples.
/// Side effects: Reads the file.
/// Notes: Internal helper used within this file only; walks the chunks.
Float32List readWav(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, at, at + 4);
    final size = data.getUint32(at + 4, Endian.little);
    if (id == 'data') {
      return Float32List.fromList([
        for (var i = 0; i < size ~/ 2; i++)
          data.getInt16(at + 8 + i * 2, Endian.little) / 32768.0,
      ]);
    }
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw StateError('no samples');
}

void main() {
  test('loads, at the version the bindings describe', () {
    expect(SherpaLibrary.load(), sherpaVersion);
  });

  final diarization = Platform.environment['DIARIZATION_TEST_DIR'];
  test(
    'speaker diarization tells two speakers apart',
    () {
      final diarizer = SpeakerDiarizer.load(
        segmentation:
            '$diarization/sherpa-onnx-pyannote-segmentation-3-0/model.onnx',
        embedding: '$diarization/campplus.onnx',
      );
      try {
        // sherpa-onnx's own test clip: two English speakers, 16 kHz mono.
        final turns = diarizer.process(readWav(File('$diarization/two.wav')));
        expect(turns, isNotEmpty);
        expect(turns.map((t) => t.speaker).toSet(), hasLength(2));
        for (var i = 1; i < turns.length; i++) {
          expect(turns[i].start, greaterThanOrEqualTo(turns[i - 1].start));
        }
      } finally {
        diarizer.release();
      }
    },
    skip: diarization == null
        ? 'set DIARIZATION_TEST_DIR to the models and the two-speaker clip'
        : false,
  );

  final dir = Platform.environment['QWEN_TEST_DIR'];
  test(
    'Qwen3-ASR transcribes the JFK sample',
    () {
      final model = QwenAsrModel.load(
        QwenAsrFiles(
          convFrontend: '$dir/conv_frontend.onnx',
          encoder: '$dir/encoder.int8.onnx',
          decoder: '$dir/decoder.int8.onnx',
          tokenizer: '$dir/tokenizer',
        ),
      );
      try {
        final samples = readWav(File('../../assets/local_asr/jfk.wav'));
        final text = model.transcribe(samples).toLowerCase();
        expect(text, contains('ask not what your country can do for you'));
      } finally {
        model.release();
      }
    },
    skip: dir == null ? 'set QWEN_TEST_DIR to an unpacked model' : false,
  );
}
