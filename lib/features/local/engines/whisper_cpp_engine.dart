import 'package:myapps_ai_asr/myapps_ai_asr.dart';
import 'package:myapps_ai_asr_whisper/myapps_ai_asr_whisper.dart' as shared;

import '../services/shared_asr_adapter.dart';
import '../services/tested_here.dart';

export 'package:myapps_ai_asr_whisper/myapps_ai_asr_whisper.dart'
    show GgmlFamily, WhisperRuntimeInfo, parakeetMaxWindowSeconds;

/// Application facade over the shared whisper.cpp runtime.
class WhisperCppEngine extends SharedAsrAdapter {
  /// Purpose: Create a runtime. Inputs: family, threads. Returns: Engine.
  /// Side effects: None until use. Notes: Native binaries remain pinned.
  WhisperCppEngine({
    shared.GgmlFamily family = shared.GgmlFamily.whisper,
    int? threads,
  }) : super(
         shared.WhisperCppEngine(
           family: family,
           threads: threads,
           testedRoutes: TestedRouteTable(
             rows: testedRoutes,
             deviceClass: currentDeviceClass(),
           ),
         ),
       );

  /// Purpose: Read runtime diagnostics. Inputs: None. Returns: Runtime info.
  /// Side effects: Loads library. Notes: Contains no recording data.
  Future<shared.WhisperRuntimeInfo> runtime() =>
      (engine as shared.WhisperCppEngine).runtime();

  /// Purpose: Shut down the worker. Inputs: None. Returns: Completion.
  /// Side effects: Releases native resources. Notes: Cancels active work first.
  Future<void> dispose() => (engine as shared.WhisperCppEngine).dispose();
}
