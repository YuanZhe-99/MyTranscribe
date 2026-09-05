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
  String get commonCopy => 'Copy';

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
  String get jobDeleteConfirm =>
      'Delete this transcription? The converted audio and the transcript files kept by this app go with it. The original recording is not touched.';

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
  String get jobPathCopied => 'Path copied';

  @override
  String get jobResume => 'Resume';

  @override
  String get jobRetry => 'Try again';

  @override
  String get jobRetryWithoutSpeakers => 'Try again without speaker names';

  @override
  String get jobSectionOutputs => 'Transcript files';

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
  String get settingsAbout => 'About';

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
      'Keep your sources and models on your own server';

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
}
