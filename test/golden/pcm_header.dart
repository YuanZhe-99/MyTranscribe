/// Purpose: The header every PCM window must start with, for the two media
/// tests that hold both FFmpeg backends to it.
/// Inputs: None.
/// Returns: `expectedPcmHeader`.
/// Side effects: None.
/// Notes: The external executable on the desktop
/// (`test/media_toolkit_live_test.dart`) and the linked library on a device
/// (`integration_test/media_toolkit_test.dart`) must write these bytes
/// exactly — no `LIST` chunk naming an FFmpeg version, nothing between the
/// format and the samples — so a local engine reads a window the same way
/// whichever one cut it.
library;

import 'dart:typed_data';

/// Purpose: Build the 44-byte header of a 16 kHz mono 16-bit WAV.
/// Inputs: The number of [samples].
/// Returns: The bytes.
/// Side effects: None.
/// Notes: None.
List<int> expectedPcmHeader(int samples) {
  final data = ByteData(44);
  void tag(int at, String text) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  return data.buffer.asUint8List();
}
