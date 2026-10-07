import 'package:myapps_ai_asr/myapps_ai_asr.dart';
import 'package:myapps_ai_asr_apple/myapps_ai_asr_apple.dart' as shared;

import '../services/shared_asr_adapter.dart';
import '../services/tested_here.dart';

/// Application facade over the shared Apple Neural Engine runtime.
class FluidAudioEngine extends SharedAsrAdapter {
  /// Purpose: Create a runtime. Inputs: None. Returns: Engine.
  /// Side effects: None until use. Notes: Registered only on Apple platforms.
  FluidAudioEngine()
    : super(
        shared.FluidAudioEngine(
          testedRoutes: TestedRouteTable(
            rows: testedRoutes,
            deviceClass: currentDeviceClass(),
          ),
        ),
      );
}

/// Purpose: Join timed tokens. Inputs: result, seconds. Returns: Segments.
/// Side effects: None. Notes: Delegates to the shared token parser.
List<AsrSegment> segmentsFrom(
  ({String text, List<({String piece, double start, double end})> tokens})
  result,
  double seconds,
) => shared.appleSegments(result, seconds);
