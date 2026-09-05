/// Purpose: Test the parser for FFmpeg's machine-readable progress stream.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The samples are the shape FFmpeg actually writes: a block of
/// `key=value` lines terminated by `progress=continue`, then another, ending
/// with `progress=end`. Stdout arrives in arbitrary chunks, so the split
/// cases matter as much as the whole-block ones.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/media/services/ffmpeg_progress_parser.dart';

/// One complete block as FFmpeg writes it, at five seconds in.
const _block = '''
bitrate=  64.0kbits/s
total_size=40960
out_time_us=5120000
out_time_ms=5120000
out_time=00:00:05.120000
speed=48.2x
progress=continue
''';

void main() {
  group('a complete block', () {
    test('is reported once, when the progress key arrives', () {
      final parser = FfmpegProgressParser();
      final reports = parser.addChunk(_block);
      expect(reports, hasLength(1));
      expect(reports.single.processed, const Duration(seconds: 5, milliseconds: 120));
      expect(reports.single.finished, isFalse);
      expect(reports.single.totalSizeBytes, 40960);
      expect(reports.single.speed, 48.2);
    });

    test('is not reported before the progress key arrives', () {
      final parser = FfmpegProgressParser();
      expect(parser.addChunk('out_time_us=1000000\ntotal_size=8000\n'), isEmpty);
    });

    test('marks the final block as finished', () {
      final parser = FfmpegProgressParser();
      final reports = parser.addChunk(
        'out_time_us=9000000\nprogress=end\n',
      );
      expect(reports.single.finished, isTrue);
    });
  });

  group('chunk boundaries', () {
    test('a block split across two chunks still reports once', () {
      // stdout is a byte stream; a line can arrive in halves.
      final parser = FfmpegProgressParser();
      final half = _block.length ~/ 2;
      final first = parser.addChunk(_block.substring(0, half));
      final second = parser.addChunk(_block.substring(half));
      expect([...first, ...second], hasLength(1));
    });

    test('two blocks in one chunk report twice, in order', () {
      final parser = FfmpegProgressParser();
      final reports = parser.addChunk(
        'out_time_us=1000000\nprogress=continue\n'
        'out_time_us=2000000\nprogress=end\n',
      );
      expect(reports, hasLength(2));
      expect(reports.first.processed, const Duration(seconds: 1));
      expect(reports.last.processed, const Duration(seconds: 2));
      expect(reports.last.finished, isTrue);
    });

    test('keys do not leak from one block into the next', () {
      final parser = FfmpegProgressParser();
      final reports = parser.addChunk(
        'total_size=1234\nout_time_us=1000000\nprogress=continue\n'
        'out_time_us=2000000\nprogress=end\n',
      );
      expect(reports.first.totalSizeBytes, 1234);
      expect(reports.last.totalSizeBytes, isNull);
    });

    test('carriage returns are tolerated', () {
      final parser = FfmpegProgressParser();
      final reports = parser.addChunk(
        'out_time_us=3000000\r\nprogress=continue\r\n',
      );
      expect(reports.single.processed, const Duration(seconds: 3));
    });
  });

  group('values FFmpeg writes before it knows them', () {
    test('N/A reads as unknown rather than throwing', () {
      final parser = FfmpegProgressParser();
      final reports = parser.addChunk(
        'total_size=N/A\nout_time_us=N/A\nspeed=N/A\nprogress=continue\n',
      );
      expect(reports.single.processed, Duration.zero);
      expect(reports.single.totalSizeBytes, isNull);
      expect(reports.single.speed, isNull);
    });

    test('a formatted time is used when the microsecond key is absent', () {
      // Some builds omit out_time_us; the string form is the fallback.
      final parser = FfmpegProgressParser();
      final reports = parser.addChunk(
        'out_time=01:02:03.500000\nprogress=continue\n',
      );
      expect(
        reports.single.processed,
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500),
      );
    });
  });

  group('unexpected input', () {
    test('lines without an equals sign are ignored', () {
      final parser = FfmpegProgressParser();
      expect(parser.addChunk('\n  \nsomething else\n'), isEmpty);
    });

    test('a stray line does not stop the next block being reported', () {
      final parser = FfmpegProgressParser();
      final reports = parser.addChunk(
        'garbage\nout_time_us=1000000\nprogress=end\n',
      );
      expect(reports, hasLength(1));
    });
  });

  group('fractionOf', () {
    test('is null when the total is unknown or nonsense', () {
      const report = FfmpegProgress(
        processed: Duration(seconds: 30),
        finished: false,
      );
      expect(report.fractionOf(null), isNull);
      expect(report.fractionOf(0), isNull);
      expect(report.fractionOf(-5), isNull);
    });

    test('is the ratio, clamped at both ends', () {
      const report = FfmpegProgress(
        processed: Duration(seconds: 30),
        finished: false,
      );
      expect(report.fractionOf(60), closeTo(0.5, 1e-9));
      // FFmpeg can report a little past the declared duration; a progress bar
      // at 1.02 looks broken.
      expect(report.fractionOf(29), 1.0);
    });
  });

  group('parseDurationFromBanner', () {
    test('reads the duration FFmpeg prints on stderr', () {
      const banner =
          "Input #0, mp3, from 'lecture.mp3':\n"
          '  Duration: 01:23:45.67, start: 0.025057, bitrate: 128 kb/s\n';
      expect(parseDurationFromBanner(banner), closeTo(5025.67, 1e-6));
    });

    test('is null when there is no duration line', () {
      expect(parseDurationFromBanner('ffmpeg version 8.0\n'), isNull);
      expect(parseDurationFromBanner(''), isNull);
    });
  });
}
