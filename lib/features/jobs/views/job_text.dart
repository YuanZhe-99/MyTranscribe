/// Purpose: Turn a job's machine-readable state into the sentences the pages
/// show.
/// Inputs: A job, a plan, and the localisations.
/// Returns: Strings.
/// Side effects: None.
/// Notes: Kept out of the pages so the jobs list, the detail page and the
/// new-job preview all describe the same plan the same way. A user who reads
/// "3 segments of about 23 minutes" before starting must see the same sentence
/// afterwards, or they will wonder what changed.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/chunk_plan.dart';
import '../models/transcription_job.dart';

/// Purpose: Name what a job is doing right now.
/// Inputs: [l10n], the [job].
/// Returns: One short phrase.
/// Side effects: None.
/// Notes: The window number is one-based here and zero-based in the record,
/// because "segment 0 of 3" is not something to show anybody.
String jobStageLabel(AppLocalizations l10n, TranscriptionJob job) {
  final total = job.plan?.windowCount ?? 0;
  final current = (job.currentChunk ?? 0) + 1;
  return switch (job.stage) {
    JobStage.queued => l10n.jobStageQueued,
    JobStage.probing => l10n.jobStageProbing,
    JobStage.planning => l10n.jobStagePlanning,
    JobStage.normalizing => l10n.jobStageNormalizing,
    JobStage.cutting => l10n.jobStageCutting(current, total),
    JobStage.uploading => l10n.jobStageUploading(current, total),
    JobStage.transcribing => l10n.jobStageTranscribing(current, total),
    JobStage.merging => l10n.jobStageMerging,
    JobStage.namingSpeakers => l10n.jobStageSpeakers,
    JobStage.rendering => l10n.jobStageRendering,
    JobStage.done => l10n.jobStageDone,
    JobStage.failed => l10n.jobStageFailed,
    JobStage.cancelled => l10n.jobStageCancelled,
  };
}

/// Purpose: Choose the icon that stands for a job's state.
/// Inputs: The [stage].
/// Returns: An [IconData].
/// Side effects: None.
/// Notes: A running job gets no icon here — the list shows a progress ring
/// instead, which says more than any icon could.
IconData jobStageIcon(JobStage stage) => switch (stage) {
  JobStage.done => Icons.check_circle_outline,
  JobStage.failed => Icons.error_outline,
  JobStage.cancelled => Icons.stop_circle_outlined,
  _ => Icons.graphic_eq_outlined,
};

/// Purpose: Say in one line how a recording is divided.
/// Inputs: [l10n], the [plan].
/// Returns: One sentence.
/// Side effects: None.
/// Notes: Minutes rather than seconds, because nobody thinks about a lecture in
/// seconds. The overlap stays in seconds for the same reason.
String planSummary(AppLocalizations l10n, ChunkPlan plan) {
  if (plan.windowCount <= 1) return l10n.jobSentWhole;
  final minutes = (plan.strideSeconds / 60).toStringAsFixed(
    plan.strideSeconds >= 600 ? 0 : 1,
  );
  return l10n.jobSentInSegments(
    plan.windowCount,
    minutes,
    plan.overlapSeconds.toStringAsFixed(0),
  );
}

/// Purpose: Explain one reason the plan is what it is.
/// Inputs: [l10n], the [reason].
/// Returns: One sentence.
/// Side effects: None.
/// Notes: These are what make the automatic choice inspectable. A user who
/// disagrees with the segment length can see which limit produced it before
/// overriding it, rather than guessing.
String planReasonText(AppLocalizations l10n, PlanReason reason) {
  final value = (reason.value ?? 0).round().toString();
  return switch (reason.code) {
    PlanReasonCode.fitsWhole => l10n.planFitsWhole,
    PlanReasonCode.splitBySize => l10n.planSplitBySize,
    PlanReasonCode.splitByDuration => l10n.planSplitByDuration,
    PlanReasonCode.splitByFormat => l10n.planSplitByFormat,
    PlanReasonCode.windowCappedBySize => l10n.planWindowBySize,
    PlanReasonCode.windowCappedByModel => l10n.planWindowByModel(value),
    PlanReasonCode.windowCappedByProvider => l10n.planWindowByProvider(value),
    PlanReasonCode.windowCappedByCeiling => l10n.planWindowByCeiling(value),
    PlanReasonCode.overlapForSpeakers => l10n.planOverlapForSpeakers(value),
    PlanReasonCode.windowChosenByUser => l10n.planWindowByUser,
    PlanReasonCode.windowCappedByEngine => l10n.planWindowByEngine(value),
    PlanReasonCode.windowCappedByMemory => l10n.planWindowByMemory(value),
  };
}

/// Purpose: Work out how far along a job is.
/// Inputs: The [job].
/// Returns: A fraction from 0 to 1, or null when it cannot be known.
/// Side effects: None.
/// Notes: Measured in finished windows, which is the only figure that is both
/// honest and monotonic. Converting has no progress of its own here, so the bar
/// is indeterminate until the first window lands.
double? jobProgress(TranscriptionJob job) {
  final total = job.plan?.windowCount ?? 0;
  if (total == 0) return null;
  if (job.stage == JobStage.done) return 1;
  return (job.chunks.length / total).clamp(0.0, 1.0);
}
