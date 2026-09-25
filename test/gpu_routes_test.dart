/// Purpose: The GPU routes whisper.cpp offers are named and graded as the
/// support matrix says (L3 of the local-models plan).
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Pure functions; no native library is loaded.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_asr_whisper/local_asr_whisper.dart';
import 'package:my_transcribe/features/local/engines/whisper_cpp_engine.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/tested_here.dart';

void main() {
  test('backend names do not depend on how a device is numbered', () {
    expect(gpuBackendName('Vulkan0'), 'vulkan');
    expect(gpuBackendName('Vulkan1'), 'vulkan');
    expect(gpuBackendName('GPUOpenCL'), 'opencl');
    expect(gpuBackendName('MTL0'), 'metal');
    expect(gpuBackendName('CUDA0'), 'cuda0');
  });

  test('every GPU gets a route, in the order whisper.cpp counts them', () {
    const info = WhisperRuntimeInfo(
      loaded: true,
      devices: [
        WhisperDevice('CPU', 'Snapdragon', 0),
        WhisperDevice('Vulkan0', 'Radeon', 1),
        WhisperDevice('Vulkan1', 'Intel UHD', 2),
        WhisperDevice('GPUOpenCL', 'Adreno', 2),
      ],
    );
    expect(info.gpus.map((d) => d.description), [
      'Radeon',
      'Intel UHD',
      'Adreno',
    ]);
    expect(info.gpuBackends(), ['vulkan', 'vulkan1', 'opencl']);
  });

  test('grades follow the support matrix', () {
    expect(gpuEvidence('metal'), EvidenceLevel.community);
    expect(gpuEvidence('metal', parakeet: true), EvidenceLevel.experimental);
    expect(
      gpuEvidence('vulkan', deviceClass: 'windows-x64'),
      EvidenceLevel.community,
    );
    expect(
      gpuEvidence('vulkan', deviceClass: 'android'),
      EvidenceLevel.experimental,
    );
    expect(
      gpuEvidence('opencl', deviceClass: 'windows-arm64-qualcomm'),
      EvidenceLevel.experimental,
    );
    expect(gpuEvidence('cuda0'), EvidenceLevel.none);
  });
}
