import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MyTranscribe!!!!!'**
  String get appTitle;

  /// No description provided for @backupAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get backupAutoBackup;

  /// No description provided for @backupAutoBackupDesc.
  ///
  /// In en, this message translates to:
  /// **'Back up once a day when the app starts'**
  String get backupAutoBackupDesc;

  /// No description provided for @backupCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get backupCorrupt;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupCreate;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupCreated;

  /// No description provided for @backupDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this backup?'**
  String get backupDeleteConfirm;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the backup'**
  String get backupFailed;

  /// No description provided for @backupForceUploadDone.
  ///
  /// In en, this message translates to:
  /// **'Remote copy overwritten'**
  String get backupForceUploadDone;

  /// No description provided for @backupForceUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get backupForceUploadFailed;

  /// No description provided for @backupForceUploadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Overwrite the remote copy with the restored data?'**
  String get backupForceUploadPrompt;

  /// No description provided for @backupForceUploadSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get backupForceUploadSkip;

  /// No description provided for @backupHistory.
  ///
  /// In en, this message translates to:
  /// **'History ({count})'**
  String backupHistory(int count);

  /// No description provided for @backupKeepDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String backupKeepDays(int days);

  /// No description provided for @backupKeepForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get backupKeepForever;

  /// No description provided for @backupLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Backups stay on this device. They are never uploaded anywhere.'**
  String get backupLocalOnlyNote;

  /// No description provided for @backupModuleSettings.
  ///
  /// In en, this message translates to:
  /// **'Sources and models'**
  String get backupModuleSettings;

  /// No description provided for @backupNoBackups.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get backupNoBackups;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestore;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'This replaces the selected data with the backup. Continue?'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the backup'**
  String get backupRestoreFailed;

  /// No description provided for @backupRestoreModules.
  ///
  /// In en, this message translates to:
  /// **'What to restore'**
  String get backupRestoreModules;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestored;

  /// No description provided for @backupRestoredSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync has been turned off so the restored data is not merged into your server by accident.'**
  String get backupRestoredSyncDisabled;

  /// No description provided for @backupRetention.
  ///
  /// In en, this message translates to:
  /// **'Keep backups for'**
  String get backupRetention;

  /// No description provided for @backupSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get backupSelectAll;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A copy of your sources and models, kept on this device'**
  String get backupSubtitle;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @capabilitySupported.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get capabilitySupported;

  /// No description provided for @capabilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get capabilityUnknown;

  /// No description provided for @capabilityUnsupported.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get capabilityUnsupported;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export to ZIP'**
  String get exportData;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import from ZIP'**
  String get importData;

  /// No description provided for @jobDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this transcription? The converted audio and the transcript files kept by this app go with it. The original recording is not touched.'**
  String get jobDeleteConfirm;

  /// No description provided for @jobDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transcription deleted'**
  String get jobDeleted;

  /// No description provided for @jobDiskUsage.
  ///
  /// In en, this message translates to:
  /// **'Uses {size} on this device'**
  String jobDiskUsage(String size);

  /// No description provided for @jobFieldFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get jobFieldFinished;

  /// No description provided for @jobFieldLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get jobFieldLength;

  /// No description provided for @jobFieldModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get jobFieldModel;

  /// No description provided for @jobFieldSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get jobFieldSize;

  /// No description provided for @jobFieldSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get jobFieldSource;

  /// No description provided for @jobFieldStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get jobFieldStarted;

  /// No description provided for @jobOpenTranscript.
  ///
  /// In en, this message translates to:
  /// **'Open the transcript'**
  String get jobOpenTranscript;

  /// No description provided for @jobPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get jobPathCopied;

  /// No description provided for @jobResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get jobResume;

  /// No description provided for @jobRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get jobRetry;

  /// No description provided for @jobRetryWithoutSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Try again without speaker names'**
  String get jobRetryWithoutSpeakers;

  /// No description provided for @jobSectionOutputs.
  ///
  /// In en, this message translates to:
  /// **'Transcript files'**
  String get jobSectionOutputs;

  /// No description provided for @jobSectionPlan.
  ///
  /// In en, this message translates to:
  /// **'How it was sent'**
  String get jobSectionPlan;

  /// No description provided for @jobSectionProblem.
  ///
  /// In en, this message translates to:
  /// **'What went wrong'**
  String get jobSectionProblem;

  /// No description provided for @jobSectionRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get jobSectionRecording;

  /// No description provided for @jobSegmentsDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} segments'**
  String jobSegmentsDone(int done, int total);

  /// No description provided for @jobSentInSegments.
  ///
  /// In en, this message translates to:
  /// **'{count} segments of about {minutes} minutes, overlapping by {overlap} seconds'**
  String jobSentInSegments(int count, String minutes, String overlap);

  /// No description provided for @jobSentWhole.
  ///
  /// In en, this message translates to:
  /// **'Sent in one piece'**
  String get jobSentWhole;

  /// No description provided for @jobStageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get jobStageCancelled;

  /// No description provided for @jobStageCutting.
  ///
  /// In en, this message translates to:
  /// **'Cutting segment {index} of {total}'**
  String jobStageCutting(int index, int total);

  /// No description provided for @jobStageDone.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get jobStageDone;

  /// No description provided for @jobStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Did not finish'**
  String get jobStageFailed;

  /// No description provided for @jobStageMerging.
  ///
  /// In en, this message translates to:
  /// **'Joining the segments'**
  String get jobStageMerging;

  /// No description provided for @jobStageNormalizing.
  ///
  /// In en, this message translates to:
  /// **'Converting the audio'**
  String get jobStageNormalizing;

  /// No description provided for @jobStagePlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get jobStagePlanning;

  /// No description provided for @jobStageProbing.
  ///
  /// In en, this message translates to:
  /// **'Reading the recording'**
  String get jobStageProbing;

  /// No description provided for @jobStageQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get jobStageQueued;

  /// No description provided for @jobStageRendering.
  ///
  /// In en, this message translates to:
  /// **'Writing the transcript'**
  String get jobStageRendering;

  /// No description provided for @jobStageSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Matching speakers'**
  String get jobStageSpeakers;

  /// No description provided for @jobStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Transcribing segment {index} of {total}'**
  String jobStageUploading(int index, int total);

  /// No description provided for @jobStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get jobStart;

  /// No description provided for @jobStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get jobStop;

  /// No description provided for @jobsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a recording to transcribe. Long files are split automatically and can be resumed if a run is interrupted.'**
  String get jobsEmptyBody;

  /// No description provided for @jobsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No transcriptions yet'**
  String get jobsEmptyTitle;

  /// No description provided for @jobsNew.
  ///
  /// In en, this message translates to:
  /// **'New transcription'**
  String get jobsNew;

  /// No description provided for @jobsSelectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a transcription to see how it went.'**
  String get jobsSelectPrompt;

  /// No description provided for @jobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get jobsTitle;

  /// No description provided for @libraryAddModel.
  ///
  /// In en, this message translates to:
  /// **'Add a model'**
  String get libraryAddModel;

  /// No description provided for @libraryAddSource.
  ///
  /// In en, this message translates to:
  /// **'Add a source'**
  String get libraryAddSource;

  /// No description provided for @libraryApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get libraryApiKey;

  /// No description provided for @libraryApiKeyClear.
  ///
  /// In en, this message translates to:
  /// **'Remove key'**
  String get libraryApiKeyClear;

  /// No description provided for @libraryApiKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get libraryApiKeyMissing;

  /// No description provided for @libraryApiKeyNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'This source needs no key'**
  String get libraryApiKeyNotNeeded;

  /// No description provided for @libraryApiKeyNote.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device. Sent only to this source, and to your WebDAV server when the connection is safe.'**
  String get libraryApiKeyNote;

  /// No description provided for @libraryApiKeySave.
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get libraryApiKeySave;

  /// No description provided for @libraryApiKeySet.
  ///
  /// In en, this message translates to:
  /// **'Set on this device'**
  String get libraryApiKeySet;

  /// No description provided for @libraryAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get libraryAuth;

  /// No description provided for @libraryAuthBearer.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get libraryAuthBearer;

  /// No description provided for @libraryAuthHeader.
  ///
  /// In en, this message translates to:
  /// **'Custom header'**
  String get libraryAuthHeader;

  /// No description provided for @libraryAuthHeaderName.
  ///
  /// In en, this message translates to:
  /// **'Header name'**
  String get libraryAuthHeaderName;

  /// No description provided for @libraryAuthNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get libraryAuthNone;

  /// No description provided for @libraryBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get libraryBaseUrl;

  /// No description provided for @libraryCapabilities.
  ///
  /// In en, this message translates to:
  /// **'What this model can do'**
  String get libraryCapabilities;

  /// No description provided for @libraryDeleteModel.
  ///
  /// In en, this message translates to:
  /// **'Delete this model'**
  String get libraryDeleteModel;

  /// No description provided for @libraryDeleteSource.
  ///
  /// In en, this message translates to:
  /// **'Delete this source'**
  String get libraryDeleteSource;

  /// No description provided for @libraryDeleteSourceConfirm.
  ///
  /// In en, this message translates to:
  /// **'This removes the source and its models. Your recordings and transcripts are not affected.'**
  String get libraryDeleteSourceConfirm;

  /// No description provided for @libraryDialect.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get libraryDialect;

  /// No description provided for @libraryDiarization.
  ///
  /// In en, this message translates to:
  /// **'Tell speakers apart'**
  String get libraryDiarization;

  /// No description provided for @libraryDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Shown as'**
  String get libraryDisplayName;

  /// No description provided for @libraryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A source is an API endpoint such as OpenAI or OpenRouter, together with the models it offers.'**
  String get libraryEmptyBody;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sources yet'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryImportModels.
  ///
  /// In en, this message translates to:
  /// **'Import models'**
  String get libraryImportModels;

  /// No description provided for @libraryKeywords.
  ///
  /// In en, this message translates to:
  /// **'Accepts keywords'**
  String get libraryKeywords;

  /// No description provided for @libraryLimits.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get libraryLimits;

  /// No description provided for @libraryMaxDuration.
  ///
  /// In en, this message translates to:
  /// **'Longest recording per request (seconds)'**
  String get libraryMaxDuration;

  /// No description provided for @libraryMaxFileSize.
  ///
  /// In en, this message translates to:
  /// **'Largest upload (MB)'**
  String get libraryMaxFileSize;

  /// No description provided for @libraryMaxRequest.
  ///
  /// In en, this message translates to:
  /// **'Gateway request limit (seconds)'**
  String get libraryMaxRequest;

  /// No description provided for @libraryModelName.
  ///
  /// In en, this message translates to:
  /// **'Model identifier'**
  String get libraryModelName;

  /// How many models a source offers, shown under its name in the library list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No models} =1{1 model} other{{count} models}}'**
  String libraryModelsCount(int count);

  /// No description provided for @libraryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get libraryName;

  /// No description provided for @libraryNoNewModels.
  ///
  /// In en, this message translates to:
  /// **'No new models to add'**
  String get libraryNoNewModels;

  /// No description provided for @libraryOverridden.
  ///
  /// In en, this message translates to:
  /// **'Changed by you'**
  String get libraryOverridden;

  /// No description provided for @libraryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Accepts context'**
  String get libraryPrompt;

  /// No description provided for @libraryResetToTemplate.
  ///
  /// In en, this message translates to:
  /// **'Reset to the built-in values'**
  String get libraryResetToTemplate;

  /// No description provided for @librarySegmentTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Times for each part'**
  String get librarySegmentTimestamps;

  /// No description provided for @librarySelectItem.
  ///
  /// In en, this message translates to:
  /// **'Choose a source or a model'**
  String get librarySelectItem;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @libraryUnlimited.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get libraryUnlimited;

  /// No description provided for @libraryUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get libraryUnverified;

  /// No description provided for @libraryWordTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Times for each word'**
  String get libraryWordTimestamps;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get navTranscribe;

  /// No description provided for @newJobChange.
  ///
  /// In en, this message translates to:
  /// **'Choose another'**
  String get newJobChange;

  /// No description provided for @newJobChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a recording'**
  String get newJobChoose;

  /// No description provided for @newJobDiarize.
  ///
  /// In en, this message translates to:
  /// **'Identify speakers'**
  String get newJobDiarize;

  /// No description provided for @newJobDiarizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'It is not known whether this model labels speakers. If it refuses, you will be offered a run without them.'**
  String get newJobDiarizeUnknown;

  /// No description provided for @newJobDiarizeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This model does not label speakers.'**
  String get newJobDiarizeUnsupported;

  /// No description provided for @newJobKeepChunks.
  ///
  /// In en, this message translates to:
  /// **'Keep the split audio'**
  String get newJobKeepChunks;

  /// No description provided for @newJobKeepChunksHint.
  ///
  /// In en, this message translates to:
  /// **'For working out why a segment came back wrong. Uses more space.'**
  String get newJobKeepChunksHint;

  /// No description provided for @newJobKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get newJobKeywords;

  /// No description provided for @newJobKeywordsHint.
  ///
  /// In en, this message translates to:
  /// **'Terms the recording is likely to contain.'**
  String get newJobKeywordsHint;

  /// No description provided for @newJobLanguages.
  ///
  /// In en, this message translates to:
  /// **'Language hints'**
  String get newJobLanguages;

  /// No description provided for @newJobLanguagesHint.
  ///
  /// In en, this message translates to:
  /// **'Codes such as en or zh, most likely first. Leave empty to let the model decide.'**
  String get newJobLanguagesHint;

  /// No description provided for @newJobNoFile.
  ///
  /// In en, this message translates to:
  /// **'No recording chosen yet'**
  String get newJobNoFile;

  /// No description provided for @newJobNoKey.
  ///
  /// In en, this message translates to:
  /// **'No API key is set for this source.'**
  String get newJobNoKey;

  /// No description provided for @newJobNoModels.
  ///
  /// In en, this message translates to:
  /// **'Add a source in the library first.'**
  String get newJobNoModels;

  /// No description provided for @newJobOpenLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open the library'**
  String get newJobOpenLibrary;

  /// No description provided for @newJobOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get newJobOptions;

  /// No description provided for @newJobPlanPending.
  ///
  /// In en, this message translates to:
  /// **'Choose a recording to see how it will be sent.'**
  String get newJobPlanPending;

  /// No description provided for @newJobPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'How it will be sent'**
  String get newJobPlanTitle;

  /// No description provided for @newJobPrompt.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get newJobPrompt;

  /// No description provided for @newJobPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Names, jargon, or a sentence about the recording. Helps the model spell things the way you would.'**
  String get newJobPromptHint;

  /// No description provided for @newJobStart.
  ///
  /// In en, this message translates to:
  /// **'Start transcribing'**
  String get newJobStart;

  /// No description provided for @newJobTitle.
  ///
  /// In en, this message translates to:
  /// **'New transcription'**
  String get newJobTitle;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @planFitsWhole.
  ///
  /// In en, this message translates to:
  /// **'Small enough to send in one piece.'**
  String get planFitsWhole;

  /// No description provided for @planOverlapForSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Segments overlap by {seconds} seconds so speakers can be matched across them.'**
  String planOverlapForSpeakers(String seconds);

  /// No description provided for @planSplitByDuration.
  ///
  /// In en, this message translates to:
  /// **'Longer than this model accepts in one request.'**
  String get planSplitByDuration;

  /// No description provided for @planSplitByFormat.
  ///
  /// In en, this message translates to:
  /// **'This format has to be converted first.'**
  String get planSplitByFormat;

  /// No description provided for @planSplitBySize.
  ///
  /// In en, this message translates to:
  /// **'Too large to send in one piece.'**
  String get planSplitBySize;

  /// No description provided for @planWindowByCeiling.
  ///
  /// In en, this message translates to:
  /// **'Segment length capped at {seconds} seconds for safety.'**
  String planWindowByCeiling(String seconds);

  /// No description provided for @planWindowByModel.
  ///
  /// In en, this message translates to:
  /// **'Segment length set by the model\'s limit of {seconds} seconds.'**
  String planWindowByModel(String seconds);

  /// No description provided for @planWindowByProvider.
  ///
  /// In en, this message translates to:
  /// **'Segment length set by the source\'s limit of {seconds} seconds.'**
  String planWindowByProvider(String seconds);

  /// No description provided for @planWindowBySize.
  ///
  /// In en, this message translates to:
  /// **'Segment length chosen to stay under the size limit.'**
  String get planWindowBySize;

  /// No description provided for @planWindowByUser.
  ///
  /// In en, this message translates to:
  /// **'Segment length set by you.'**
  String get planWindowByUser;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your sources and models to a file'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Load sources and models from a file'**
  String get settingsImportSubtitle;

  /// No description provided for @settingsKeepChunks.
  ///
  /// In en, this message translates to:
  /// **'Keep audio pieces'**
  String get settingsKeepChunks;

  /// No description provided for @settingsKeepChunksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leaves the split-up audio on disk after a transcription. Uses as much space as the recording'**
  String get settingsKeepChunksSubtitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLicense.
  ///
  /// In en, this message translates to:
  /// **'License (GPLv3)'**
  String get settingsLicense;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsMediaTools.
  ///
  /// In en, this message translates to:
  /// **'Audio tools'**
  String get settingsMediaTools;

  /// No description provided for @settingsMediaToolsBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get settingsMediaToolsBuiltIn;

  /// No description provided for @settingsMediaToolsChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a file…'**
  String get settingsMediaToolsChoose;

  /// No description provided for @settingsMediaToolsClear.
  ///
  /// In en, this message translates to:
  /// **'Use the automatic search'**
  String get settingsMediaToolsClear;

  /// No description provided for @settingsMediaToolsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get settingsMediaToolsDownload;

  /// No description provided for @settingsMediaToolsDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download did not finish'**
  String get settingsMediaToolsDownloadFailed;

  /// No description provided for @settingsMediaToolsDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Audio tools are ready'**
  String get settingsMediaToolsDownloaded;

  /// No description provided for @settingsMediaToolsDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get settingsMediaToolsDownloading;

  /// No description provided for @settingsMediaToolsExplain.
  ///
  /// In en, this message translates to:
  /// **'Splitting a long recording needs FFmpeg, a free audio tool. The app can download it for you, or use a copy you already have.'**
  String get settingsMediaToolsExplain;

  /// No description provided for @settingsMediaToolsMissing.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get settingsMediaToolsMissing;

  /// No description provided for @settingsMediaToolsReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get settingsMediaToolsReady;

  /// No description provided for @settingsMediaToolsSubtitleMissing.
  ///
  /// In en, this message translates to:
  /// **'Needed to split long recordings'**
  String get settingsMediaToolsSubtitleMissing;

  /// No description provided for @settingsMediaToolsSubtitleReady.
  ///
  /// In en, this message translates to:
  /// **'Long recordings can be split for upload'**
  String get settingsMediaToolsSubtitleReady;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsSelectItem.
  ///
  /// In en, this message translates to:
  /// **'Select an item from the list'**
  String get settingsSelectItem;

  /// No description provided for @settingsStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage Location'**
  String get settingsStorageLocation;

  /// No description provided for @settingsStorageLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where recordings and transcripts are kept'**
  String get settingsStorageLocationSubtitle;

  /// No description provided for @settingsSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your sources and models on your own server'**
  String get settingsSyncSubtitle;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get settingsTranscription;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsWebDAVAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync'**
  String get settingsWebDAVAutoSync;

  /// No description provided for @settingsWebDAVAutoSyncConflict.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync found conflicts'**
  String get settingsWebDAVAutoSyncConflict;

  /// No description provided for @settingsWebDAVAutoSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync after a review and when the app resumes'**
  String get settingsWebDAVAutoSyncDesc;

  /// No description provided for @settingsWebDAVAutoSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync failed'**
  String get settingsWebDAVAutoSyncFailed;

  /// No description provided for @settingsWebDAVConfigRemoved.
  ///
  /// In en, this message translates to:
  /// **'Configuration removed'**
  String get settingsWebDAVConfigRemoved;

  /// No description provided for @settingsWebDAVConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get settingsWebDAVConfigSaved;

  /// No description provided for @settingsWebDAVConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get settingsWebDAVConnectionFailed;

  /// No description provided for @settingsWebDAVConnectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get settingsWebDAVConnectionSuccess;

  /// No description provided for @settingsWebDAVDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get settingsWebDAVDisconnect;

  /// No description provided for @settingsWebDAVForceDownload.
  ///
  /// In en, this message translates to:
  /// **'Force Download'**
  String get settingsWebDAVForceDownload;

  /// No description provided for @settingsWebDAVForceDownloadConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace your local progress with the remote copy. Local changes since the last sync will be lost.'**
  String get settingsWebDAVForceDownloadConfirmBody;

  /// No description provided for @settingsWebDAVForceDownloadConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Force download?'**
  String get settingsWebDAVForceDownloadConfirmTitle;

  /// No description provided for @settingsWebDAVForceUpload.
  ///
  /// In en, this message translates to:
  /// **'Force Upload'**
  String get settingsWebDAVForceUpload;

  /// No description provided for @settingsWebDAVForceUploadConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite the remote progress with your local copy. Remote changes since the last sync will be lost.'**
  String get settingsWebDAVForceUploadConfirmBody;

  /// No description provided for @settingsWebDAVForceUploadConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Force upload?'**
  String get settingsWebDAVForceUploadConfirmTitle;

  /// No description provided for @settingsWebDAVLastSuccess.
  ///
  /// In en, this message translates to:
  /// **'Last successful sync'**
  String get settingsWebDAVLastSuccess;

  /// No description provided for @settingsWebDAVNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud Preset'**
  String get settingsWebDAVNextcloud;

  /// No description provided for @settingsWebDAVNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get settingsWebDAVNotConfigured;

  /// No description provided for @settingsWebDAVPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsWebDAVPassword;

  /// No description provided for @settingsWebDAVRemotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote Path'**
  String get settingsWebDAVRemotePath;

  /// No description provided for @settingsWebDAVServerURL.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsWebDAVServerURL;

  /// No description provided for @settingsWebDAVSync.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get settingsWebDAVSync;

  /// No description provided for @settingsWebDAVSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get settingsWebDAVSyncFailed;

  /// No description provided for @settingsWebDAVSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get settingsWebDAVSyncNow;

  /// No description provided for @settingsWebDAVSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get settingsWebDAVSyncSuccess;

  /// No description provided for @settingsWebDAVSyncWarnings.
  ///
  /// In en, this message translates to:
  /// **'Sync completed with {count} warning(s)'**
  String settingsWebDAVSyncWarnings(int count);

  /// No description provided for @settingsWebDAVSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get settingsWebDAVSyncing;

  /// No description provided for @settingsWebDAVTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get settingsWebDAVTestConnection;

  /// No description provided for @settingsWebDAVUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsWebDAVUsername;

  /// No description provided for @syncConflictDesc.
  ///
  /// In en, this message translates to:
  /// **'This was changed on both devices since the last sync. Keep one version.'**
  String get syncConflictDesc;

  /// No description provided for @syncConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync conflict: {name}'**
  String syncConflictTitle(Object name);

  /// No description provided for @syncKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep Local'**
  String get syncKeepLocal;

  /// No description provided for @syncKeepRemote.
  ///
  /// In en, this message translates to:
  /// **'Keep Remote'**
  String get syncKeepRemote;

  /// No description provided for @syncLocalVersion.
  ///
  /// In en, this message translates to:
  /// **'Local version'**
  String get syncLocalVersion;

  /// No description provided for @syncModifiedAt.
  ///
  /// In en, this message translates to:
  /// **'Modified: {time}'**
  String syncModifiedAt(Object time);

  /// No description provided for @syncPhaseConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get syncPhaseConnecting;

  /// No description provided for @syncPhaseDownloadingData.
  ///
  /// In en, this message translates to:
  /// **'Downloading {file} ({current}/{total})'**
  String syncPhaseDownloadingData(Object file, int current, int total);

  /// No description provided for @syncPhaseMerging.
  ///
  /// In en, this message translates to:
  /// **'Merging {file}…'**
  String syncPhaseMerging(Object file);

  /// No description provided for @syncPhaseUploadingData.
  ///
  /// In en, this message translates to:
  /// **'Uploading {file}…'**
  String syncPhaseUploadingData(Object file);

  /// No description provided for @syncRemoteVersion.
  ///
  /// In en, this message translates to:
  /// **'Remote version'**
  String get syncRemoteVersion;

  /// No description provided for @syncUnknownItem.
  ///
  /// In en, this message translates to:
  /// **'This item is not in the current content catalog.'**
  String get syncUnknownItem;

  /// No description provided for @viewerApproximate.
  ///
  /// In en, this message translates to:
  /// **'This model returned no times, so the ones shown are estimated from where each segment started.'**
  String get viewerApproximate;

  /// No description provided for @viewerAudioMissing.
  ///
  /// In en, this message translates to:
  /// **'The converted audio is no longer on this device, so there is nothing to play.'**
  String get viewerAudioMissing;

  /// No description provided for @viewerAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Follow playback'**
  String get viewerAutoScroll;

  /// No description provided for @viewerCopied.
  ///
  /// In en, this message translates to:
  /// **'Transcript copied'**
  String get viewerCopied;

  /// No description provided for @viewerCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy the whole transcript'**
  String get viewerCopyAll;

  /// No description provided for @viewerEditNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody in particular'**
  String get viewerEditNobody;

  /// No description provided for @viewerEditSegment.
  ///
  /// In en, this message translates to:
  /// **'Edit this line'**
  String get viewerEditSegment;

  /// No description provided for @viewerEditSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Who said it'**
  String get viewerEditSpeaker;

  /// No description provided for @viewerEditText.
  ///
  /// In en, this message translates to:
  /// **'What was said'**
  String get viewerEditText;

  /// No description provided for @viewerEmpty.
  ///
  /// In en, this message translates to:
  /// **'This transcription produced no text.'**
  String get viewerEmpty;

  /// No description provided for @viewerExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get viewerExport;

  /// No description provided for @viewerExportNeedsTimes.
  ///
  /// In en, this message translates to:
  /// **'Needs real times'**
  String get viewerExportNeedsTimes;

  /// No description provided for @viewerExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved as {name}'**
  String viewerExportSaved(String name);

  /// No description provided for @viewerFontSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get viewerFontSize;

  /// No description provided for @viewerGroupSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Group by speaker'**
  String get viewerGroupSpeakers;

  /// No description provided for @viewerModeSegments.
  ///
  /// In en, this message translates to:
  /// **'Segments'**
  String get viewerModeSegments;

  /// No description provided for @viewerModeTranscript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get viewerModeTranscript;

  /// No description provided for @viewerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get viewerNoResults;

  /// No description provided for @viewerOptions.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewerOptions;

  /// No description provided for @viewerSearchCount.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String viewerSearchCount(int index, int total);

  /// No description provided for @viewerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search this transcript'**
  String get viewerSearchHint;

  /// No description provided for @viewerShowTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Show times'**
  String get viewerShowTimestamps;

  /// No description provided for @viewerSpeakerFallback.
  ///
  /// In en, this message translates to:
  /// **'Speaker {number}'**
  String viewerSpeakerFallback(int number);

  /// No description provided for @viewerSpeakerLines.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String viewerSpeakerLines(int count);

  /// No description provided for @viewerSpeakerMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge into another speaker'**
  String get viewerSpeakerMerge;

  /// No description provided for @viewerSpeakerMergeNobody.
  ///
  /// In en, this message translates to:
  /// **'There is nobody else to merge into.'**
  String get viewerSpeakerMergeNobody;

  /// No description provided for @viewerSpeakerMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge {name} into'**
  String viewerSpeakerMergeTitle(String name);

  /// No description provided for @viewerSpeakerMerged.
  ///
  /// In en, this message translates to:
  /// **'{from} is now part of {into}'**
  String viewerSpeakerMerged(String from, String into);

  /// No description provided for @viewerSpeakerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get viewerSpeakerName;

  /// No description provided for @viewerSpeakerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get viewerSpeakerRename;

  /// No description provided for @viewerSpeakerUncertain.
  ///
  /// In en, this message translates to:
  /// **'Some of this speaker\'s lines were an uncertain match across a segment boundary.'**
  String get viewerSpeakerUncertain;

  /// No description provided for @viewerSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get viewerSpeakers;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
