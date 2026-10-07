import 'package:myapps_ai_asr/myapps_ai_asr.dart';
import 'package:myapps_ai_asr_sherpa/myapps_ai_asr_sherpa.dart' as shared;

import '../services/shared_asr_adapter.dart';
import '../services/tested_here.dart';

export 'package:myapps_ai_asr_sherpa/myapps_ai_asr_sherpa.dart'
    show qwenMaxWindowSeconds;

/// Application facade over the shared sherpa-onnx runtime.
class SherpaOnnxEngine extends SharedAsrAdapter {
  /// Purpose: Create a runtime. Inputs: threads. Returns: Engine.
  /// Side effects: None until use. Notes: Preserves the application's tested table.
  SherpaOnnxEngine({int? threads})
    : super(
        shared.SherpaOnnxEngine(
          threads: threads,
          testedRoutes: TestedRouteTable(
            rows: testedRoutes,
            deviceClass: currentDeviceClass(),
          ),
        ),
      );

  /// Purpose: Shut down the worker. Inputs: None. Returns: Completion.
  /// Side effects: Releases native resources. Notes: Waits for active work.
  Future<void> dispose() => (engine as shared.SherpaOnnxEngine).dispose();
}
