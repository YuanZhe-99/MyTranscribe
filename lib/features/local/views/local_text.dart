/// Purpose: Turn routes, evidence, checks and placements into the words the
/// pages show.
/// Inputs: The localisations and the values to describe.
/// Returns: Strings.
/// Side effects: None.
/// Notes: Kept in one place so the library, the new-job page, the job detail
/// and the diagnostics page say the same thing about the same route. The
/// wording follows the glossary: "tested on this kind of device", never
/// "verified"; "check", never "smoke test".
library;

import '../../../l10n/app_localizations.dart';
import '../models/engine_capability.dart';
import '../models/local_model_config.dart';
import '../services/artifact_manager.dart';
import '../services/local_models_controller.dart';

/// Purpose: Name a route.
/// Inputs: [l10n], the [route].
/// Returns: e.g. `CPU` or `GPU (metal)`.
/// Side effects: None.
/// Notes: None.
String routeLabel(AppLocalizations l10n, EngineRoute route) =>
    switch (route.device) {
      ComputeDevice.cpu => l10n.localRouteCpu,
      ComputeDevice.gpu => l10n.localRouteGpu(route.backend),
      ComputeDevice.npu => l10n.localRouteNpu(route.backend),
    };

/// Purpose: Name a route from its key alone.
/// Inputs: [l10n], the route [key] (`adapter:artifact:backend`).
/// Returns: A short label.
/// Side effects: None.
/// Notes: For a job record, which keeps the key and not the route; the
/// backend is what tells a reader where it ran.
String routeKeyLabel(AppLocalizations l10n, String key) {
  final backend = key.split(':').last;
  return backend == 'cpu' ? l10n.localRouteCpu : backend;
}

/// Purpose: Describe a route's evidence grade.
/// Inputs: [l10n], the [evidence].
/// Returns: One short phrase.
/// Side effects: None.
/// Notes: None.
String evidenceLabel(AppLocalizations l10n, EvidenceLevel evidence) =>
    switch (evidence) {
      EvidenceLevel.official => l10n.localEvidenceOfficial,
      EvidenceLevel.community => l10n.localEvidenceCommunity,
      EvidenceLevel.experimental => l10n.localEvidenceExperimental,
      EvidenceLevel.none => l10n.localEvidenceNone,
    };

/// Purpose: Describe a route's check on this device.
/// Inputs: [l10n], the [check].
/// Returns: One sentence.
/// Side effects: None.
/// Notes: None.
String checkLabel(AppLocalizations l10n, SmokeTestSummary check) =>
    switch (check.outcome) {
      SmokeTestOutcome.passed => l10n.localCheckPassed,
      SmokeTestOutcome.failed => l10n.localCheckFailed(check.reason ?? '—'),
      SmokeTestOutcome.notRun => l10n.localCheckNotRun,
      SmokeTestOutcome.crashed => l10n.localCheckCrashed,
    };

/// Purpose: Say how fast a route ran in its check.
/// Inputs: [l10n], the [check].
/// Returns: e.g. `12.3× real time`, or null when it was not measured.
/// Side effects: None.
/// Notes: Shown as times faster than real time, which is what a person can
/// picture; the stored figure is its inverse.
String? speedLabel(AppLocalizations l10n, SmokeTestSummary check) {
  final rtf = check.realTimeFactor;
  if (rtf == null || rtf <= 0) return null;
  final factor = 1 / rtf;
  return l10n.localCheckSpeed(
    factor >= 10 ? factor.toStringAsFixed(0) : factor.toStringAsFixed(1),
  );
}

/// Purpose: Name where a window ran.
/// Inputs: [l10n], the [placement].
/// Returns: One word or two.
/// Side effects: None.
/// Notes: None.
String placementLabel(AppLocalizations l10n, PlacementKind placement) =>
    switch (placement) {
      PlacementKind.cpu => l10n.placementCpu,
      PlacementKind.gpu => l10n.placementGpu,
      PlacementKind.npu => l10n.placementNpu,
      PlacementKind.mixed => l10n.placementMixed,
      PlacementKind.unknown => l10n.placementUnknown,
    };

/// Purpose: Say what state a local model is in on this device.
/// Inputs: [l10n], the [model], whether its packages are [installed], its
/// [activity], and whether this build [canRun] it.
/// Returns: One short phrase for a list row.
/// Side effects: None.
/// Notes: None.
String localModelStateLabel(
  AppLocalizations l10n,
  LocalModelConfig model, {
  required bool installed,
  required bool canRun,
  LocalModelActivity? activity,
}) {
  final progress = activity?.progress;
  if (progress != null) {
    return switch (progress.stage) {
      InstallStage.unpacking ||
      InstallStage.verifying ||
      InstallStage.installing => l10n.localStateUnpacking,
      _ => l10n.localStateDownloading(
        ((progress.fraction ?? 0) * 100).floor().toString(),
      ),
    };
  }
  if (activity?.checking ?? false) return l10n.localStateChecking;
  if (activity?.error case final error?) return l10n.localStateFailed(error);
  if (!canRun) return l10n.localStateNoEngine;
  return installed ? l10n.localStateReady : l10n.localStateNotDownloaded;
}
