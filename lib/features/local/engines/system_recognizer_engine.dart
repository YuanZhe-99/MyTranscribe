import 'package:myapps_ai_asr_apple/myapps_ai_asr_apple.dart' as shared;

import '../services/shared_asr_adapter.dart';

export 'package:myapps_ai_asr_apple/myapps_ai_asr_apple.dart'
    show systemRecognizerMaxWindowSeconds;

/// Application facade over the shared operating-system recognizer.
class SystemRecognizerEngine extends SharedAsrAdapter {
  /// Purpose: Create a recognizer. Inputs: None. Returns: Engine.
  /// Side effects: None until use. Notes: No model download.
  SystemRecognizerEngine() : super(shared.SystemRecognizerEngine());
}
