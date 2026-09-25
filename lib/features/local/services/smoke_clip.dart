/// Purpose: The clip every local route transcribes on this device before its
/// first job, taken from the app's assets.
/// Inputs: The bundled `assets/local_asr/jfk.wav`.
/// Returns: A `SmokeClip` backed by a file the engines can read.
/// Side effects: Writes the clip to the temporary directory once per run.
/// Notes: Engines read files, not assets, so the clip is copied out; the copy
/// is reused while it has the right size. The recording is the opening of
/// President Kennedy's 1961 inaugural address, in the public domain, as
/// whisper.cpp ships it for the same purpose. See
/// `doc/en-us/algorithms/engine-routing.md` for how the text is compared.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'route_smoke_test.dart';

/// The asset key of the check clip.
const smokeClipAsset = 'assets/local_asr/jfk.wav';

/// What is said in the check clip.
const smokeClipText =
    'And so, my fellow Americans, ask not what your country can do for you, '
    'ask what you can do for your country.';

/// How long the check clip runs, in seconds.
const smokeClipSeconds = 11.0;

/// Purpose: Load the check clip as a file.
/// Inputs: Optional [bundle] and [directory] for tests.
/// Returns: The [SmokeClip], or null when the asset is missing.
/// Side effects: Writes the clip to [directory] (the temporary directory by
/// default) when it is not there already.
/// Notes: A missing asset means a build that does not carry the clip; the
/// backend then runs an unchecked route unchecked, which the router still
/// guards with its other rules.
Future<SmokeClip?> loadSmokeClip({
  AssetBundle? bundle,
  Directory? directory,
}) async {
  final ByteData data;
  try {
    data = await (bundle ?? rootBundle).load(smokeClipAsset);
  } catch (_) {
    return null;
  }
  final dir = directory ?? await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'mytranscribe_check_clip.wav'));
  if (!file.existsSync() || file.lengthSync() != data.lengthInBytes) {
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }
  return SmokeClip(
    wav: file,
    expectedText: smokeClipText,
    seconds: smokeClipSeconds,
  );
}
