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
  String get jobsEmptyBody =>
      'Choose a recording to transcribe. Long files are split automatically and can be resumed if a run is interrupted.';

  @override
  String get jobsEmptyTitle => 'No transcriptions yet';

  @override
  String get jobsNew => 'New transcription';

  @override
  String get jobsTitle => 'Transcribe';

  @override
  String get libraryEmptyBody =>
      'A source is an API endpoint such as OpenAI or OpenRouter, together with the models it offers.';

  @override
  String get libraryEmptyTitle => 'No sources yet';

  @override
  String get libraryTitle => 'Library';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get navTranscribe => 'Transcribe';

  @override
  String get ok => 'OK';

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
