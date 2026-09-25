/// Purpose: The routes this project has verified on real hardware, by device
/// class, and the question an adapter asks of it.
/// Inputs: A route, and this device's class.
/// Returns: Whether the route is "tested on this kind of device".
/// Side effects: None beyond reading the OS's processor identifier.
/// Notes: The same table as the one in
/// `doc/en-us/algorithms/engine-routing.md`; a row is added only with a
/// verification record in `doc/en-us/local-asr-support-matrix.md`, and never
/// from a report about somebody else's hardware (decision D20 of the
/// local-models plan). Everything not listed is unverified support.
library;

import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

import '../../../shared/utils/platform_capabilities.dart';
import '../models/engine_capability.dart';

/// One verified route: a device class, an adapter and a backend.
typedef TestedRoute = ({String deviceClass, String adapterId, String backend});

/// Every route this project has verified. See the support matrix for the
/// records behind each row.
const testedRoutes = <TestedRoute>[];

/// Purpose: Name this device's class.
/// Inputs: None.
/// Returns: The class, as `localDeviceClass` spells it.
/// Side effects: Reads the processor identifier from the environment.
/// Notes: Windows puts the processor's vendor in `PROCESSOR_IDENTIFIER`.
String currentDeviceClass() => localDeviceClass(
  architecture: switch (Abi.current()) {
    Abi.windowsArm64 ||
    Abi.macosArm64 ||
    Abi.iosArm64 ||
    Abi.androidArm64 ||
    Abi.linuxArm64 => 'arm64',
    Abi.windowsX64 ||
    Abi.macosX64 ||
    Abi.iosX64 ||
    Abi.androidX64 ||
    Abi.linuxX64 => 'x64',
    final other => other.toString(),
  },
  processor: Platform.environment['PROCESSOR_IDENTIFIER'] ?? '',
);

/// Purpose: Say whether a route was verified on this device's class.
/// Inputs: The [route], and the [deviceClass] (this device's by default).
/// Returns: `bool`.
/// Side effects: None.
/// Notes: None.
bool isTestedHere(EngineRoute route, {String? deviceClass}) {
  final here = deviceClass ?? currentDeviceClass();
  for (final tested in testedRoutes) {
    if (tested.deviceClass == here &&
        tested.adapterId == route.adapterId &&
        tested.backend == route.backend) {
      return true;
    }
  }
  return false;
}

/// Purpose: The evidence grade of whisper.cpp's CPU route on this device.
/// Inputs: None.
/// Returns: **B** everywhere the survey found reproducible results, **E** on
/// Android until the SoC can be told apart.
/// Side effects: None.
/// Notes: The survey graded Snapdragon phones B and Tensor and MediaTek E;
/// with every Android device one class, the weaker grade is the honest one.
/// The CPU route is Auto's floor either way, so this changes what the page
/// says, not what runs.
EvidenceLevel get cpuEvidence => currentDeviceClass() == 'android'
    ? EvidenceLevel.experimental
    : EvidenceLevel.community;

/// Purpose: Name a GPU route's backend from the device name ggml reports.
/// Inputs: The device [name], e.g. `Vulkan0`, `GPUOpenCL` or `MTL0`.
/// Returns: `vulkan`, `opencl`, `metal`, or the name in lower case with only
/// letters and digits kept.
/// Side effects: None.
/// Notes: The backend is part of the route key the smoke results and the
/// tested-here table use, so it must not depend on how a device happens to be
/// numbered.
String gpuBackendName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('vulkan')) return 'vulkan';
  if (lower.contains('opencl')) return 'opencl';
  if (lower.startsWith('mtl') || lower.contains('metal')) return 'metal';
  return lower.replaceAll(RegExp('[^a-z0-9]'), '');
}

/// Purpose: The evidence grade of a whisper.cpp GPU route on this device.
/// Inputs: The [backend], as [gpuBackendName] spells it; whether the route
/// runs [parakeet] rather than Whisper; the [deviceClass], this device's by
/// default.
/// Returns: The grade the support matrix gives it.
/// Side effects: None.
/// Notes: Metal is upstream's own documented Whisper route (**B**); its
/// Parakeet runtime shows no GPU evidence yet (**E**). Vulkan on a Windows x64
/// GPU is **B**; everywhere else — Android's Adreno and Tensor GPUs, OpenCL on
/// any Adreno — it is **E**, which Auto never picks untested (decision D20).
/// A backend the survey did not grade is **U**.
EvidenceLevel gpuEvidence(
  String backend, {
  bool parakeet = false,
  String? deviceClass,
}) {
  if (parakeet) {
    return backend == 'metal' || backend == 'vulkan' || backend == 'opencl'
        ? EvidenceLevel.experimental
        : EvidenceLevel.none;
  }
  return switch (backend) {
    'metal' => EvidenceLevel.community,
    'vulkan' when (deviceClass ?? currentDeviceClass()) == 'windows-x64' =>
      EvidenceLevel.community,
    'vulkan' || 'opencl' => EvidenceLevel.experimental,
    _ => EvidenceLevel.none,
  };
}
