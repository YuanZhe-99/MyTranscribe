// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MyTranscribe!!!!!';

  @override
  String get backupAutoBackup => 'Automatic backup';

  @override
  String get backupAutoBackupDesc => 'Back up once a day when the app starts';

  @override
  String get backupCorrupt => 'Damaged';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get backupDeleteConfirm => 'Delete this backup?';

  @override
  String get backupFailed => 'Could not create the backup';

  @override
  String get backupForceUploadDone => 'Remote copy overwritten';

  @override
  String get backupForceUploadFailed => 'Upload failed';

  @override
  String get backupForceUploadPrompt =>
      'Overwrite the remote copy with the restored data?';

  @override
  String get backupForceUploadSkip => 'Not now';

  @override
  String backupHistory(int count) {
    return 'History ($count)';
  }

  @override
  String backupKeepDays(int days) {
    return '$days days';
  }

  @override
  String get backupKeepForever => 'Forever';

  @override
  String get backupLocalOnlyNote =>
      'Backups stay on this device. They are never uploaded anywhere.';

  @override
  String get backupModuleSettings => 'Sources and models';

  @override
  String get backupModuleTranscripts => 'Transcriptions';

  @override
  String get backupNoBackups => 'No backups yet';

  @override
  String get backupRestore => 'Restore';

  @override
  String get backupRestoreConfirm =>
      'This replaces the selected data with the backup. Continue?';

  @override
  String get backupRestoreFailed => 'Could not restore the backup';

  @override
  String get backupRestoreModules => 'What to restore';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backupRestoredSyncDisabled =>
      'Auto-sync has been turned off so the restored data is not merged into your server by accident.';

  @override
  String get backupRetention => 'Keep backups for';

  @override
  String get backupSelectAll => 'Select all';

  @override
  String get backupSubtitle =>
      'A copy of your sources and models, kept on this device';

  @override
  String get backupTitle => 'Backup';

  @override
  String get cancel => 'Cancel';

  @override
  String get capabilitySupported => 'Yes';

  @override
  String get capabilityUnknown => 'Not verified';

  @override
  String get capabilityUnsupported => 'No';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonClose => 'Close';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonShare => 'Share';

  @override
  String get delete => 'Delete';

  @override
  String get exportData => 'Export to ZIP';

  @override
  String get importData => 'Import from ZIP';

  @override
  String get jobAudioRemoved => 'Converted audio removed';

  @override
  String get jobDeleteConfirm =>
      'Delete this transcription? The converted audio and the transcript go with it, and it is removed from your other devices at the next sync. The original recording is not touched.';

  @override
  String get jobDeleted => 'Transcription deleted';

  @override
  String jobDiskUsage(String size) {
    return 'Uses $size on this device';
  }

  @override
  String get jobFieldFinished => 'Finished';

  @override
  String get jobFieldLength => 'Length';

  @override
  String get jobFieldModel => 'Model';

  @override
  String get jobFieldSize => 'Size';

  @override
  String get jobFieldSource => 'Source';

  @override
  String get jobFieldStarted => 'Started';

  @override
  String get jobOpenTranscript => 'Open the transcript';

  @override
  String get jobRemoveAudio => 'Remove converted audio';

  @override
  String get jobRemoveAudioConfirm =>
      'Remove this recording\'s converted copy from this device? The transcript stays, and still syncs. Playback falls back to the original recording while it can still be found. Sync will not download the copy again.';

  @override
  String get jobRename => 'Rename';

  @override
  String get jobRenameHint => 'Leave empty to use the recording\'s file name';

  @override
  String get jobRenameTitle => 'Name this transcription';

  @override
  String get jobResume => 'Resume';

  @override
  String get jobRetry => 'Try again';

  @override
  String get jobRetryWithoutSpeakers => 'Try again without speaker names';

  @override
  String get jobRunAgain => 'Run again';

  @override
  String get jobRunAgainConfirm =>
      'Transcribe this recording again? The transcript is built from scratch, so corrections made in the viewer — speaker names, edited lines — are lost.';

  @override
  String get jobSectionPlan => 'How it was sent';

  @override
  String get jobSectionProblem => 'What went wrong';

  @override
  String get jobSectionRecording => 'Recording';

  @override
  String jobSegmentsDone(int done, int total) {
    return '$done of $total segments';
  }

  @override
  String jobSentInSegments(int count, String minutes, String overlap) {
    return '$count segments of about $minutes minutes, overlapping by $overlap seconds';
  }

  @override
  String get jobSentWhole => 'Sent in one piece';

  @override
  String get jobStageCancelled => 'Stopped';

  @override
  String jobStageCutting(int index, int total) {
    return 'Cutting segment $index of $total';
  }

  @override
  String get jobStageDone => 'Finished';

  @override
  String get jobStageFailed => 'Did not finish';

  @override
  String get jobStageMerging => 'Joining the segments';

  @override
  String get jobStageNormalizing => 'Converting the audio';

  @override
  String get jobStagePlanning => 'Planning';

  @override
  String get jobStageProbing => 'Reading the recording';

  @override
  String get jobStageQueued => 'Waiting';

  @override
  String get jobStageRendering => 'Writing the transcript';

  @override
  String get jobStageSpeakers => 'Matching speakers';

  @override
  String jobStageUploading(int index, int total) {
    return 'Transcribing segment $index of $total';
  }

  @override
  String get jobStart => 'Start';

  @override
  String get jobStop => 'Stop';

  @override
  String get jobsEmptyBody =>
      'Choose a recording to transcribe. Long files are split automatically and can be resumed if a run is interrupted.';

  @override
  String get jobsEmptyTitle => 'No transcriptions yet';

  @override
  String get jobsNew => 'New transcription';

  @override
  String get jobsSelectPrompt => 'Select a transcription to see how it went.';

  @override
  String get jobsTitle => 'Transcribe';

  @override
  String get libraryAddModel => 'Add a model';

  @override
  String get libraryAddSource => 'Add a source';

  @override
  String get libraryApiKey => 'API key';

  @override
  String get libraryApiKeyClear => 'Remove key';

  @override
  String get libraryApiKeyMissing => 'Not set';

  @override
  String get libraryApiKeyNotNeeded => 'This source needs no key';

  @override
  String get libraryApiKeyNote =>
      'Stored on this device. Sent only to this source, and to your WebDAV server when the connection is safe.';

  @override
  String get libraryApiKeySave => 'Save key';

  @override
  String get libraryApiKeySet => 'Set on this device';

  @override
  String get libraryAuth => 'Authentication';

  @override
  String get libraryAuthBearer => 'API key';

  @override
  String get libraryAuthHeader => 'Custom header';

  @override
  String get libraryAuthHeaderName => 'Header name';

  @override
  String get libraryAuthNone => 'None';

  @override
  String get libraryBaseUrl => 'Address';

  @override
  String get libraryCapabilities => 'What this model can do';

  @override
  String get libraryDeleteModel => 'Delete this model';

  @override
  String get libraryDeleteSource => 'Delete this source';

  @override
  String get libraryDeleteSourceConfirm =>
      'This removes the source and its models. Your recordings and transcripts are not affected.';

  @override
  String get libraryDialect => 'Protocol';

  @override
  String get libraryDiarization => 'Tell speakers apart';

  @override
  String get libraryDisplayName => 'Shown as';

  @override
  String get libraryEmptyBody =>
      'A source is an API endpoint such as OpenAI or OpenRouter, together with the models it offers.';

  @override
  String get libraryEmptyTitle => 'No sources yet';

  @override
  String get libraryImportModels => 'Import models';

  @override
  String get libraryKeywords => 'Accepts keywords';

  @override
  String get libraryLimits => 'Limits';

  @override
  String get libraryMaxDuration => 'Longest recording per request (seconds)';

  @override
  String get libraryMaxFileSize => 'Largest upload (MB)';

  @override
  String get libraryMaxRequest => 'Gateway request limit (seconds)';

  @override
  String get libraryModelName => 'Model identifier';

  @override
  String libraryModelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
      zero: 'No models',
    );
    return '$_temp0';
  }

  @override
  String get libraryName => 'Name';

  @override
  String get libraryNoNewModels => 'No new models to add';

  @override
  String get libraryOverridden => 'Changed by you';

  @override
  String get libraryPrompt => 'Accepts context';

  @override
  String get libraryResetToTemplate => 'Reset to the built-in values';

  @override
  String get librarySegmentTimestamps => 'Times for each part';

  @override
  String get librarySelectItem => 'Choose a source or a model';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryUnlimited => 'No limit';

  @override
  String get libraryUnverified => 'Unverified';

  @override
  String get libraryWordTimestamps => 'Times for each word';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get navTranscribe => 'Transcribe';

  @override
  String get newJobChange => 'Choose another';

  @override
  String get newJobChoose => 'Choose a recording';

  @override
  String get newJobDiarize => 'Identify speakers';

  @override
  String get newJobDiarizeUnknown =>
      'It is not known whether this model labels speakers. If it refuses, you will be offered a run without them.';

  @override
  String get newJobDiarizeUnsupported => 'This model does not label speakers.';

  @override
  String get newJobKeepChunks => 'Keep the split audio';

  @override
  String get newJobKeepChunksHint =>
      'For working out why a segment came back wrong. Uses more space.';

  @override
  String get newJobKeywords => 'Keywords';

  @override
  String get newJobKeywordsHint => 'Terms the recording is likely to contain.';

  @override
  String get newJobLanguages => 'Language hints';

  @override
  String get newJobLanguagesHint =>
      'Codes such as en or zh, most likely first. Leave empty to let the model decide.';

  @override
  String get newJobNoFile => 'No recording chosen yet';

  @override
  String get newJobNoKey => 'No API key is set for this source.';

  @override
  String get newJobNoModels => 'Add a source in the library first.';

  @override
  String get newJobOpenLibrary => 'Open the library';

  @override
  String get newJobOptions => 'Options';

  @override
  String get newJobPlanPending =>
      'Choose a recording to see how it will be sent.';

  @override
  String get newJobPlanTitle => 'How it will be sent';

  @override
  String get newJobPrompt => 'Context';

  @override
  String get newJobPromptHint =>
      'Names, jargon, or a sentence about the recording. Helps the model spell things the way you would.';

  @override
  String get newJobStart => 'Start transcribing';

  @override
  String get newJobTitle => 'New transcription';

  @override
  String get ok => 'OK';

  @override
  String get planFitsWhole => 'Small enough to send in one piece.';

  @override
  String planOverlapForSpeakers(String seconds) {
    return 'Segments overlap by $seconds seconds so speakers can be matched across them.';
  }

  @override
  String get planSplitByDuration =>
      'Longer than this model accepts in one request.';

  @override
  String get planSplitByFormat => 'This format has to be converted first.';

  @override
  String get planSplitBySize => 'Too large to send in one piece.';

  @override
  String planWindowByCeiling(String seconds) {
    return 'Segment length capped at $seconds seconds for safety.';
  }

  @override
  String planWindowByModel(String seconds) {
    return 'Segment length set by the model\'s limit of $seconds seconds.';
  }

  @override
  String jobStageTranscribing(int index, int total) {
    return 'Transcribing segment $index of $total on this device';
  }

  @override
  String planWindowByEngine(String seconds) {
    return 'Segment length set by the local model\'s limit of $seconds seconds.';
  }

  @override
  String planWindowByMemory(String seconds) {
    return 'Segment length set by the memory this device has for the model: $seconds seconds.';
  }

  @override
  String planWindowByProvider(String seconds) {
    return 'Segment length set by the source\'s limit of $seconds seconds.';
  }

  @override
  String get planWindowBySize =>
      'Segment length chosen to stay under the size limit.';

  @override
  String get planWindowByUser => 'Segment length set by you.';

  @override
  String get save => 'Save';

  @override
  String get secretsBannerAllowed => 'API keys will sync to this server.';

  @override
  String get secretsBannerDenied =>
      'API keys stay on this device. Everything else still syncs.';

  @override
  String secretsKeyCount(int count) {
    return '$count stored on this device';
  }

  @override
  String get secretsReasonCgnat => 'A Tailscale address.';

  @override
  String get secretsReasonHttps => 'The connection is encrypted.';

  @override
  String get secretsReasonLinkLocal => 'A link-local address.';

  @override
  String get secretsReasonLoopback => 'The server is this device.';

  @override
  String get secretsReasonMdns => 'A name only this network can resolve.';

  @override
  String get secretsReasonPrivateIpv4 => 'A private network address.';

  @override
  String get secretsReasonPrivateIpv6 => 'A private IPv6 address.';

  @override
  String get secretsReasonPublicHttp =>
      'Plain HTTP to a host that could be anywhere, so a key would travel unencrypted.';

  @override
  String get secretsReasonScheme => 'That is not an HTTP or HTTPS address.';

  @override
  String get secretsReasonSingleLabel =>
      'A name only a local resolver can answer.';

  @override
  String get secretsReasonTailnet => 'A Tailscale name.';

  @override
  String get secretsReasonTrusted => 'You trusted this host on this device.';

  @override
  String get secretsReasonUnparseable => 'That address could not be read.';

  @override
  String get secretsReasonZerotier => 'A ZeroTier name.';

  @override
  String get secretsSectionTitle => 'API keys';

  @override
  String secretsSkippedKeys(String reason) {
    return 'API keys were not synced: $reason';
  }

  @override
  String get secretsSyncFailed => 'The API keys could not be synced.';

  @override
  String get secretsSyncedKeys => 'API keys synced';

  @override
  String get secretsTrustedHostAdd => 'Add a host';

  @override
  String get secretsTrustedHostHint => 'nas.example.com or *.example.com';

  @override
  String get secretsTrustedHostInvalid => 'That is not a host name.';

  @override
  String get secretsTrustedHosts => 'Trusted hosts';

  @override
  String get secretsTrustedHostsHelp =>
      'Plain HTTP addresses you allow keys to reach, for a server only your network can see. One host per entry; use *.example.com for subdomains. Kept on this device only.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsRemoveAllAudio => 'Remove converted audio';

  @override
  String get settingsRemoveAllAudioConfirm =>
      'Remove the converted audio of every finished transcription on this device? The transcripts stay and still sync. Sync will not download the removed audio again.';

  @override
  String settingsRemoveAllAudioDone(int count) {
    return 'Converted audio removed from $count transcriptions';
  }

  @override
  String get settingsRemoveAllAudioNothing => 'Nothing to remove';

  @override
  String settingsRemoveAllAudioSubtitle(String size) {
    return 'Keeps every transcript. Frees $size on this device';
  }

  @override
  String get settingsSpeakerNames => 'Speaker names';

  @override
  String get settingsSpeakerNamesAdd => 'Add a name';

  @override
  String get settingsSpeakerNamesEmpty =>
      'No names yet. Name a speaker in a transcript and it is offered here.';

  @override
  String get settingsSpeakerNamesSubtitle =>
      'People in your recordings, offered when you name a speaker';

  @override
  String get settingsAutoSaveTranscriptFiles =>
      'Save transcript files beside the recording';

  @override
  String get settingsAutoSaveTranscriptFilesSubtitle =>
      'Writes a Markdown and a text file next to the recording each time a transcription finishes';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsExportSubtitle => 'Save your sources and models to a file';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsImportSubtitle => 'Load sources and models from a file';

  @override
  String get settingsKeepChunks => 'Keep audio pieces';

  @override
  String get settingsKeepChunksSubtitle =>
      'Leaves the split-up audio on disk after a transcription. Uses as much space as the recording';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLicense => 'License (GPLv3)';

  @override
  String get settingsLicenses => 'Open Source Licenses';

  @override
  String get settingsMediaTools => 'Audio tools';

  @override
  String get settingsMediaToolsBuiltIn => 'Built in';

  @override
  String get settingsMediaToolsChoose => 'Choose a file…';

  @override
  String get settingsMediaToolsClear => 'Use the automatic search';

  @override
  String get settingsMediaToolsDownload => 'Download';

  @override
  String get settingsMediaToolsDownloadFailed => 'The download did not finish';

  @override
  String get settingsMediaToolsDownloaded => 'Audio tools are ready';

  @override
  String get settingsMediaToolsDownloading => 'Downloading…';

  @override
  String get settingsMediaToolsExplain =>
      'Splitting a long recording needs FFmpeg, a free audio tool. The app can download it for you, or use a copy you already have.';

  @override
  String get settingsMediaToolsMissing => 'Not set up';

  @override
  String get settingsMediaToolsReady => 'Ready';

  @override
  String get settingsMediaToolsSubtitleMissing =>
      'Needed to split long recordings';

  @override
  String get settingsMediaToolsSubtitleReady =>
      'Long recordings can be split for upload';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsSelectItem => 'Select an item from the list';

  @override
  String get settingsStorageLocation => 'Storage Location';

  @override
  String get settingsStorageLocationSubtitle =>
      'Where recordings and transcripts are kept';

  @override
  String get settingsSyncSubtitle =>
      'Keep your sources, models and transcripts on your own server';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTranscription => 'Transcription';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsWebDAVAutoSync => 'Auto-sync';

  @override
  String get settingsWebDAVAutoSyncConflict => 'Auto-sync found conflicts';

  @override
  String get settingsWebDAVAutoSyncDesc =>
      'Automatically sync after a review and when the app resumes';

  @override
  String get settingsWebDAVAutoSyncFailed => 'Auto-sync failed';

  @override
  String get settingsWebDAVConfigRemoved => 'Configuration removed';

  @override
  String get settingsWebDAVConfigSaved => 'Configuration saved';

  @override
  String get settingsWebDAVConnectionFailed => 'Connection failed';

  @override
  String get settingsWebDAVConnectionSuccess => 'Connection successful';

  @override
  String get settingsWebDAVDisconnect => 'Disconnect';

  @override
  String get settingsWebDAVForceDownload => 'Force Download';

  @override
  String get settingsWebDAVForceDownloadConfirmBody =>
      'This will replace your local progress with the remote copy. Local changes since the last sync will be lost.';

  @override
  String get settingsWebDAVForceDownloadConfirmTitle => 'Force download?';

  @override
  String get settingsWebDAVForceUpload => 'Force Upload';

  @override
  String get settingsWebDAVForceUploadConfirmBody =>
      'This will overwrite the remote progress with your local copy. Remote changes since the last sync will be lost.';

  @override
  String get settingsWebDAVForceUploadConfirmTitle => 'Force upload?';

  @override
  String get settingsWebDAVLastSuccess => 'Last successful sync';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud Preset';

  @override
  String get settingsWebDAVNotConfigured => 'Not connected';

  @override
  String get settingsWebDAVPassword => 'Password';

  @override
  String get settingsWebDAVRemotePath => 'Remote Path';

  @override
  String get settingsWebDAVServerURL => 'Server URL';

  @override
  String get settingsWebDAVSync => 'WebDAV Sync';

  @override
  String get settingsWebDAVSyncAudio => 'Also sync audio';

  @override
  String get settingsWebDAVSyncAudioDesc =>
      'Copies each transcription\'s converted audio to your server, and fetches what other devices uploaded';

  @override
  String get settingsWebDAVSyncFailed => 'Sync failed';

  @override
  String get settingsWebDAVSyncNow => 'Sync Now';

  @override
  String get settingsWebDAVSyncSuccess => 'Sync completed';

  @override
  String settingsWebDAVSyncWarnings(int count) {
    return 'Sync completed with $count warning(s)';
  }

  @override
  String get settingsWebDAVSyncing => 'Syncing…';

  @override
  String get settingsWebDAVTestConnection => 'Test Connection';

  @override
  String get settingsWebDAVUsername => 'Username';

  @override
  String syncAudioSummary(int uploaded, int downloaded) {
    return '$uploaded audio files sent, $downloaded received';
  }

  @override
  String get syncConflictDesc =>
      'This was changed on both devices since the last sync. Keep one version.';

  @override
  String syncConflictTitle(Object name) {
    return 'Sync conflict: $name';
  }

  @override
  String get syncKeepLocal => 'Keep Local';

  @override
  String get syncKeepRemote => 'Keep Remote';

  @override
  String get syncLocalVersion => 'Local version';

  @override
  String syncModifiedAt(Object time) {
    return 'Modified: $time';
  }

  @override
  String get syncPhaseConnecting => 'Connecting…';

  @override
  String syncPhaseDownloadingData(Object file, int current, int total) {
    return 'Downloading $file ($current/$total)';
  }

  @override
  String syncPhaseMerging(Object file) {
    return 'Merging $file…';
  }

  @override
  String syncPhaseUploadingData(Object file) {
    return 'Uploading $file…';
  }

  @override
  String get syncRemoteVersion => 'Remote version';

  @override
  String get syncUnknownItem =>
      'This item is not in the current content catalog.';

  @override
  String get viewerApproximate =>
      'This model returned no times, so the ones shown are estimated from where each segment started.';

  @override
  String get viewerAudioMissing =>
      'Neither the converted audio nor the original recording is on this device, so there is nothing to play.';

  @override
  String get viewerAutoScroll => 'Follow playback';

  @override
  String get viewerCopied => 'Transcript copied';

  @override
  String get viewerCopyAll => 'Copy the whole transcript';

  @override
  String get viewerEditSegment => 'Edit this line';

  @override
  String get viewerEditSpeaker => 'Who said it';

  @override
  String get viewerEditText => 'What was said';

  @override
  String get viewerEmpty => 'This transcription produced no text.';

  @override
  String get viewerExport => 'Export';

  @override
  String get viewerExportNeedsTimes => 'Needs real times';

  @override
  String viewerExportSaved(String name) {
    return 'Saved as $name';
  }

  @override
  String get viewerFontSize => 'Text size';

  @override
  String get viewerGroupSpeakers => 'Group by speaker';

  @override
  String get viewerModeSegments => 'Segments';

  @override
  String get viewerModeTranscript => 'Transcript';

  @override
  String get viewerNoResults => 'No matches';

  @override
  String get viewerOptions => 'View';

  @override
  String viewerSearchCount(int index, int total) {
    return '$index of $total';
  }

  @override
  String get viewerSearchHint => 'Search this transcript';

  @override
  String get viewerShowTimestamps => 'Show times';

  @override
  String get viewerSpeakerForget => 'Stop offering this name';

  @override
  String viewerSpeakerFallback(int number) {
    return 'Speaker $number';
  }

  @override
  String viewerSpeakerLines(int count) {
    return '$count lines';
  }

  @override
  String viewerSpeakerMarkedUnknown(String name) {
    return '$name is now unknown';
  }

  @override
  String get viewerSpeakerMerge => 'Merge into another speaker';

  @override
  String get viewerSpeakerMergeNobody => 'There is nobody else to merge into.';

  @override
  String viewerSpeakerMergeTitle(String name) {
    return 'Merge $name into';
  }

  @override
  String viewerSpeakerMerged(String from, String into) {
    return '$from is now part of $into';
  }

  @override
  String get viewerSpeakerName => 'Name';

  @override
  String get viewerSpeakerRename => 'Rename';

  @override
  String get viewerSpeakerSuggestions => 'Names you have used';

  @override
  String get viewerSpeakerUnassign => 'Mark as unknown';

  @override
  String get viewerSpeakerUncertain =>
      'Some of this speaker\'s lines were an uncertain match across a segment boundary.';

  @override
  String get viewerSpeakerUnknown => 'Unknown';

  @override
  String get viewerSpeakers => 'Speakers';

  @override
  String get libraryThisDevice => 'This device';

  @override
  String get libraryThisDeviceSubtitle => 'Models that run without a network';

  @override
  String get localStateNotDownloaded => 'Not downloaded';

  @override
  String localStateDownloading(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String get localStateUnpacking => 'Unpacking';

  @override
  String get localStateChecking => 'Checking this device';

  @override
  String get localStateReady => 'Ready';

  @override
  String localStateFailed(String reason) {
    return 'Failed: $reason';
  }

  @override
  String get localStateNoEngine => 'This build cannot run it on this device';

  @override
  String get localModelDownload => 'Download';

  @override
  String localModelDownloadTitle(String name) {
    return 'Download $name?';
  }

  @override
  String localModelDownloadBody(String size, String host) {
    return '$size from $host. It stays on this device: it is not synced and not backed up.';
  }

  @override
  String get localModelCancel => 'Cancel download';

  @override
  String get localModelRemove => 'Remove from this device';

  @override
  String localModelRemoveBody(String name) {
    return 'Remove $name from this device? You can download it again.';
  }

  @override
  String get localModelVerify => 'Verify files';

  @override
  String get localModelVerifyOk => 'The files are intact.';

  @override
  String get localModelVerifyBad =>
      'The files are damaged. Remove the model and download it again.';

  @override
  String get localModelSize => 'Download size';

  @override
  String get localModelLanguages => 'Languages';

  @override
  String get localModelLanguagesAny => 'Detects the language';

  @override
  String get localModelTimestamps => 'Timestamps';

  @override
  String get localModelLicence => 'Licence';

  @override
  String get localModelRoutes => 'Where it can run';

  @override
  String get localModelRoutesNone =>
      'Download the model to see where it can run on this device.';

  @override
  String get localRouteCpu => 'CPU';

  @override
  String localRouteGpu(String backend) {
    return 'GPU ($backend)';
  }

  @override
  String localRouteNpu(String backend) {
    return 'NPU ($backend)';
  }

  @override
  String get localRouteTested => 'Tested on this kind of device';

  @override
  String get localRouteUntested => 'Not yet tested on this kind of device';

  @override
  String get localEvidenceOfficial => 'Documented by the vendor';

  @override
  String get localEvidenceCommunity => 'Community results';

  @override
  String get localEvidenceExperimental => 'Experimental';

  @override
  String get localEvidenceNone => 'No published results';

  @override
  String get localCheckPassed => 'Passed its check here';

  @override
  String localCheckFailed(String reason) {
    return 'Failed its check here: $reason';
  }

  @override
  String get localCheckNotRun => 'Not checked yet';

  @override
  String get localCheckCrashed =>
      'The app stopped while using it here, so it is not used automatically';

  @override
  String get localCheckNow => 'Check now';

  @override
  String localCheckSpeed(String factor) {
    return '$factor× real time';
  }

  @override
  String localRouteUnavailable(String reason) {
    return 'Not available: $reason';
  }

  @override
  String get newJobThisDevice => 'This device';

  @override
  String get newJobDevice => 'Run on';

  @override
  String get newJobDeviceAuto => 'Automatic';

  @override
  String get newJobDeviceCpu => 'CPU (most compatible)';

  @override
  String newJobDeviceUntested(String route) {
    return '$route — not tested on this kind of device';
  }

  @override
  String get newJobLocalPrivacy => 'The audio stays on this device.';

  @override
  String newJobLocalNotDownloaded(String name) {
    return '$name is not downloaded. Download it in Library first.';
  }

  @override
  String newJobLocalLanguage(String name) {
    return '$name does not transcribe the languages entered here.';
  }

  @override
  String get jobFieldRanOn => 'Ran on';

  @override
  String jobFallback(String from, String to, String reason) {
    return 'Moved from $from to $to: $reason';
  }

  @override
  String jobPlacementWindows(String first, String last, String placement) {
    return 'Segments $first–$last: $placement';
  }

  @override
  String get placementCpu => 'CPU';

  @override
  String get placementGpu => 'GPU';

  @override
  String get placementNpu => 'NPU';

  @override
  String get placementMixed => 'CPU and accelerator';

  @override
  String get placementUnknown => 'Not reported';

  @override
  String get settingsLocalModels => 'Local models';

  @override
  String get settingsFallbackPolicy => 'If the chosen processor fails';

  @override
  String get settingsFallbackCpu => 'Use the same model on the CPU';

  @override
  String get settingsFallbackNone => 'Stop the transcription';

  @override
  String get settingsFallbackSystem =>
      'Use the system\'s speech recognition, on this device';

  @override
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String get settingsDiagnosticsSubtitle =>
      'What each local model can run on here';

  @override
  String get diagnosticsDevice => 'This device';

  @override
  String get diagnosticsEngine => 'Engine';

  @override
  String get diagnosticsEngineMissing => 'Not built for this device';

  @override
  String get diagnosticsRoutes => 'Routes';

  @override
  String get diagnosticsCopyReport => 'Copy report';

  @override
  String get diagnosticsCopied =>
      'Report copied. It holds no file names and no transcript text, and the app sends it nowhere.';
}
