// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MyTranscribe!!!!!';

  @override
  String get backupAutoBackup => '自动备份';

  @override
  String get backupAutoBackupDesc => '每天首次启动应用时备份一次';

  @override
  String get backupCorrupt => '已损坏';

  @override
  String get backupCreate => '创建备份';

  @override
  String get backupCreated => '备份已创建';

  @override
  String get backupDeleteConfirm => '删除这个备份？';

  @override
  String get backupFailed => '无法创建备份';

  @override
  String get backupForceUploadDone => '远程副本已覆盖';

  @override
  String get backupForceUploadFailed => '上传失败';

  @override
  String get backupForceUploadPrompt => '是否用还原后的数据覆盖远程副本？';

  @override
  String get backupForceUploadSkip => '暂不';

  @override
  String backupHistory(int count) {
    return '历史记录（$count）';
  }

  @override
  String backupKeepDays(int days) {
    return '$days 天';
  }

  @override
  String get backupKeepForever => '永久保留';

  @override
  String get backupLocalOnlyNote => '备份仅保存在本机，不会上传到任何地方。';

  @override
  String get backupModuleSettings => '来源和模型';

  @override
  String get backupNoBackups => '暂无备份';

  @override
  String get backupRestore => '还原';

  @override
  String get backupRestoreConfirm => '这将用备份覆盖所选数据，是否继续？';

  @override
  String get backupRestoreFailed => '无法还原备份';

  @override
  String get backupRestoreModules => '还原内容';

  @override
  String get backupRestored => '备份已还原';

  @override
  String get backupRestoredSyncDisabled => '自动同步已关闭，以免还原的数据被误合并到服务器。';

  @override
  String get backupRetention => '保留期限';

  @override
  String get backupSelectAll => '全选';

  @override
  String get backupSubtitle => '来源和模型的副本，保存在本机';

  @override
  String get backupTitle => '备份';

  @override
  String get cancel => '取消';

  @override
  String get capabilitySupported => '支持';

  @override
  String get capabilityUnknown => '未验证';

  @override
  String get capabilityUnsupported => '不支持';

  @override
  String get commonAdd => '添加';

  @override
  String get commonClose => '关闭';

  @override
  String get commonCopy => '复制';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonRemove => '移除';

  @override
  String get commonRetry => '重试';

  @override
  String get commonShare => '分享';

  @override
  String get delete => '删除';

  @override
  String get exportData => '导出为 ZIP';

  @override
  String get importData => '从 ZIP 导入';

  @override
  String get jobDeleteConfirm => '删除这条转写记录？本应用保存的转换后音频和转写文件会一并删除，原始录音不受影响。';

  @override
  String get jobDeleted => '转写记录已删除';

  @override
  String jobDiskUsage(String size) {
    return '在本设备占用 $size';
  }

  @override
  String get jobFieldFinished => '完成于';

  @override
  String get jobFieldLength => '时长';

  @override
  String get jobFieldModel => '模型';

  @override
  String get jobFieldSize => '大小';

  @override
  String get jobFieldSource => '来源';

  @override
  String get jobFieldStarted => '开始于';

  @override
  String get jobOpenTranscript => '打开转写稿';

  @override
  String get jobPathCopied => '路径已复制';

  @override
  String get jobResume => '继续';

  @override
  String get jobRetry => '重试';

  @override
  String get jobRetryWithoutSpeakers => '不识别说话人再试一次';

  @override
  String get jobSectionOutputs => '转写文件';

  @override
  String get jobSectionPlan => '发送方式';

  @override
  String get jobSectionProblem => '出了什么问题';

  @override
  String get jobSectionRecording => '录音';

  @override
  String jobSegmentsDone(int done, int total) {
    return '已完成 $done / $total 段';
  }

  @override
  String jobSentInSegments(int count, String minutes, String overlap) {
    return '$count 段，每段约 $minutes 分钟，重叠 $overlap 秒';
  }

  @override
  String get jobSentWhole => '整段发送';

  @override
  String get jobStageCancelled => '已停止';

  @override
  String jobStageCutting(int index, int total) {
    return '正在切分第 $index 段，共 $total 段';
  }

  @override
  String get jobStageDone => '已完成';

  @override
  String get jobStageFailed => '未能完成';

  @override
  String get jobStageMerging => '正在合并分段';

  @override
  String get jobStageNormalizing => '正在转换音频';

  @override
  String get jobStagePlanning => '正在规划';

  @override
  String get jobStageProbing => '正在读取录音';

  @override
  String get jobStageQueued => '等待中';

  @override
  String get jobStageRendering => '正在写入转写稿';

  @override
  String get jobStageSpeakers => '正在匹配说话人';

  @override
  String jobStageUploading(int index, int total) {
    return '正在转写第 $index 段，共 $total 段';
  }

  @override
  String get jobStart => '开始';

  @override
  String get jobStop => '停止';

  @override
  String get jobsEmptyBody => '选择一个录音开始转写。长文件会自动分段，中断后可以继续。';

  @override
  String get jobsEmptyTitle => '还没有转写记录';

  @override
  String get jobsNew => '新建转写';

  @override
  String get jobsSelectPrompt => '选择一条转写记录，查看它的情况。';

  @override
  String get jobsTitle => '转写';

  @override
  String get libraryAddModel => '添加模型';

  @override
  String get libraryAddSource => '添加来源';

  @override
  String get libraryApiKey => 'API 密钥';

  @override
  String get libraryApiKeyClear => '删除密钥';

  @override
  String get libraryApiKeyMissing => '尚未设置';

  @override
  String get libraryApiKeyNotNeeded => '此来源不需要密钥';

  @override
  String get libraryApiKeyNote => '保存在本机。只会发送给此来源；连接安全时才会同步到你的 WebDAV 服务器。';

  @override
  String get libraryApiKeySave => '保存密钥';

  @override
  String get libraryApiKeySet => '已在本机设置';

  @override
  String get libraryAuth => '认证方式';

  @override
  String get libraryAuthBearer => 'API 密钥';

  @override
  String get libraryAuthHeader => '自定义请求头';

  @override
  String get libraryAuthHeaderName => '请求头名称';

  @override
  String get libraryAuthNone => '无';

  @override
  String get libraryBaseUrl => '地址';

  @override
  String get libraryCapabilities => '该模型支持';

  @override
  String get libraryDeleteModel => '删除此模型';

  @override
  String get libraryDeleteSource => '删除此来源';

  @override
  String get libraryDeleteSourceConfirm => '将同时删除该来源下的模型。录音和转写稿不受影响。';

  @override
  String get libraryDialect => '协议';

  @override
  String get libraryDiarization => '区分说话人';

  @override
  String get libraryDisplayName => '显示为';

  @override
  String get libraryEmptyBody =>
      '来源是一个 API 端点，例如 OpenAI 或 OpenRouter，以及它提供的模型。';

  @override
  String get libraryEmptyTitle => '还没有来源';

  @override
  String get libraryImportModels => '导入模型';

  @override
  String get libraryKeywords => '接受关键词';

  @override
  String get libraryLimits => '限制';

  @override
  String get libraryMaxDuration => '单次请求音频上限（秒）';

  @override
  String get libraryMaxFileSize => '单次上传上限（MB）';

  @override
  String get libraryMaxRequest => '网关请求上限（秒）';

  @override
  String get libraryModelName => '模型标识';

  @override
  String libraryModelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个模型',
      zero: '没有模型',
    );
    return '$_temp0';
  }

  @override
  String get libraryName => '名称';

  @override
  String get libraryNoNewModels => '没有可添加的新模型';

  @override
  String get libraryOverridden => '已被你修改';

  @override
  String get libraryPrompt => '接受上下文';

  @override
  String get libraryResetToTemplate => '恢复内置设定';

  @override
  String get librarySegmentTimestamps => '分段时间';

  @override
  String get librarySelectItem => '选择一个来源或模型';

  @override
  String get libraryTitle => '来源库';

  @override
  String get libraryUnlimited => '无限制';

  @override
  String get libraryUnverified => '未验证';

  @override
  String get libraryWordTimestamps => '逐词时间';

  @override
  String get navLibrary => '来源库';

  @override
  String get navSettings => '设置';

  @override
  String get navTranscribe => '转写';

  @override
  String get newJobChange => '重新选择';

  @override
  String get newJobChoose => '选择录音';

  @override
  String get newJobDiarize => '识别说话人';

  @override
  String get newJobDiarizeUnknown => '尚不清楚该模型是否标注说话人。若被拒绝，会提示你不带此选项重试。';

  @override
  String get newJobDiarizeUnsupported => '该模型不标注说话人。';

  @override
  String get newJobKeepChunks => '保留切分后的音频';

  @override
  String get newJobKeepChunksHint => '便于排查某一段为何出错，会占用更多空间。';

  @override
  String get newJobKeywords => '关键词';

  @override
  String get newJobKeywordsHint => '录音中可能出现的词语。';

  @override
  String get newJobLanguages => '语言提示';

  @override
  String get newJobLanguagesHint => '如 en 或 zh，可能性最高的放前面。留空则由模型自行判断。';

  @override
  String get newJobNoFile => '尚未选择录音';

  @override
  String get newJobNoKey => '该来源尚未设置 API Key。';

  @override
  String get newJobNoModels => '请先在库中添加来源。';

  @override
  String get newJobOpenLibrary => '打开库';

  @override
  String get newJobOptions => '选项';

  @override
  String get newJobPlanPending => '选择录音后即可看到发送方式。';

  @override
  String get newJobPlanTitle => '将如何发送';

  @override
  String get newJobPrompt => '上下文';

  @override
  String get newJobPromptHint => '人名、术语，或一句话说明录音内容。有助于模型按你的习惯书写。';

  @override
  String get newJobStart => '开始转写';

  @override
  String get newJobTitle => '新建转写';

  @override
  String get ok => '确定';

  @override
  String get planFitsWhole => '文件够小，可以整段发送。';

  @override
  String planOverlapForSpeakers(String seconds) {
    return '分段之间重叠 $seconds 秒，以便跨段匹配说话人。';
  }

  @override
  String get planSplitByDuration => '超过该模型单次请求可接受的时长。';

  @override
  String get planSplitByFormat => '这种格式需要先转换。';

  @override
  String get planSplitBySize => '文件过大，无法整段发送。';

  @override
  String planWindowByCeiling(String seconds) {
    return '为稳妥起见，分段长度上限为 $seconds 秒。';
  }

  @override
  String planWindowByModel(String seconds) {
    return '分段长度受模型 $seconds 秒的限制。';
  }

  @override
  String planWindowByProvider(String seconds) {
    return '分段长度受来源 $seconds 秒的限制。';
  }

  @override
  String get planWindowBySize => '分段长度按大小上限选定。';

  @override
  String get planWindowByUser => '分段长度由你指定。';

  @override
  String get save => '保存';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsData => '数据';

  @override
  String get settingsExportSubtitle => '把来源和模型保存为文件';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsImportSubtitle => '从文件载入来源和模型';

  @override
  String get settingsKeepChunks => '保留音频分段';

  @override
  String get settingsKeepChunksSubtitle => '转写结束后保留切分出的音频，占用空间与原录音相当';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLicense => '许可证 (GPLv3)';

  @override
  String get settingsLicenses => '开源许可证';

  @override
  String get settingsMediaTools => '音频工具';

  @override
  String get settingsMediaToolsBuiltIn => '已内置';

  @override
  String get settingsMediaToolsChoose => '选择文件…';

  @override
  String get settingsMediaToolsClear => '改为自动查找';

  @override
  String get settingsMediaToolsDownload => '下载';

  @override
  String get settingsMediaToolsDownloadFailed => '下载未能完成';

  @override
  String get settingsMediaToolsDownloaded => '音频工具已就绪';

  @override
  String get settingsMediaToolsDownloading => '正在下载…';

  @override
  String get settingsMediaToolsExplain =>
      '切分长录音需要 FFmpeg 这个免费的音频工具。可以让应用替你下载，也可以指定你已有的版本。';

  @override
  String get settingsMediaToolsMissing => '尚未设置';

  @override
  String get settingsMediaToolsReady => '已就绪';

  @override
  String get settingsMediaToolsSubtitleMissing => '切分长录音需要它';

  @override
  String get settingsMediaToolsSubtitleReady => '可以切分长录音后上传';

  @override
  String get settingsPrivacyPolicy => '隐私政策';

  @override
  String get settingsSelectItem => '从左侧列表中选择一项';

  @override
  String get settingsStorageLocation => '存储位置';

  @override
  String get settingsStorageLocationSubtitle => '录音和转写稿的存放位置';

  @override
  String get settingsSyncSubtitle => '把来源和模型同步到你自己的服务器';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsTranscription => '转写';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsWebDAVAutoSync => '自动同步';

  @override
  String get settingsWebDAVAutoSyncConflict => '自动同步发现冲突';

  @override
  String get settingsWebDAVAutoSyncDesc => '复习后和应用恢复时自动同步';

  @override
  String get settingsWebDAVAutoSyncFailed => '自动同步失败';

  @override
  String get settingsWebDAVConfigRemoved => '配置已移除';

  @override
  String get settingsWebDAVConfigSaved => '配置已保存';

  @override
  String get settingsWebDAVConnectionFailed => '连接失败';

  @override
  String get settingsWebDAVConnectionSuccess => '连接成功';

  @override
  String get settingsWebDAVDisconnect => '断开连接';

  @override
  String get settingsWebDAVForceDownload => '强制下载';

  @override
  String get settingsWebDAVForceDownloadConfirmBody =>
      '将用远程学习进度替换本地内容。上次同步后本地的更改将丢失。';

  @override
  String get settingsWebDAVForceDownloadConfirmTitle => '确认强制下载？';

  @override
  String get settingsWebDAVForceUpload => '强制上传';

  @override
  String get settingsWebDAVForceUploadConfirmBody =>
      '将用本地学习进度覆盖远程内容。上次同步后远程的更改将丢失。';

  @override
  String get settingsWebDAVForceUploadConfirmTitle => '确认强制上传？';

  @override
  String get settingsWebDAVLastSuccess => '上次成功同步';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud 预设';

  @override
  String get settingsWebDAVNotConfigured => '尚未连接';

  @override
  String get settingsWebDAVPassword => '密码';

  @override
  String get settingsWebDAVRemotePath => '远程路径';

  @override
  String get settingsWebDAVServerURL => '服务器地址';

  @override
  String get settingsWebDAVSync => 'WebDAV 同步';

  @override
  String get settingsWebDAVSyncFailed => '同步失败';

  @override
  String get settingsWebDAVSyncNow => '立即同步';

  @override
  String get settingsWebDAVSyncSuccess => '同步完成';

  @override
  String settingsWebDAVSyncWarnings(int count) {
    return '同步完成，但有 $count 条警告';
  }

  @override
  String get settingsWebDAVSyncing => '同步中…';

  @override
  String get settingsWebDAVTestConnection => '测试连接';

  @override
  String get settingsWebDAVUsername => '用户名';

  @override
  String get syncConflictDesc => '上次同步之后，两台设备都改过它。请保留其中一个版本。';

  @override
  String syncConflictTitle(Object name) {
    return '同步冲突：$name';
  }

  @override
  String get syncKeepLocal => '保留本地';

  @override
  String get syncKeepRemote => '保留远程';

  @override
  String get syncLocalVersion => '本地版本';

  @override
  String syncModifiedAt(Object time) {
    return '修改时间：$time';
  }

  @override
  String get syncPhaseConnecting => '正在连接…';

  @override
  String syncPhaseDownloadingData(Object file, int current, int total) {
    return '正在下载 $file（$current/$total）';
  }

  @override
  String syncPhaseMerging(Object file) {
    return '正在合并 $file…';
  }

  @override
  String syncPhaseUploadingData(Object file) {
    return '正在上传 $file…';
  }

  @override
  String get syncRemoteVersion => '远程版本';

  @override
  String get syncUnknownItem => '当前内容库中没有这一项。';

  @override
  String get viewerApproximate => '该模型没有返回时间，这里显示的是按分段起点估算的时间。';

  @override
  String get viewerAudioMissing => '本设备上已没有转换后的音频，无法播放。';

  @override
  String get viewerAutoScroll => '跟随播放';

  @override
  String get viewerCopied => '转写稿已复制';

  @override
  String get viewerCopyAll => '复制整份转写稿';

  @override
  String get viewerEditNobody => '不指定';

  @override
  String get viewerEditSegment => '编辑这一句';

  @override
  String get viewerEditSpeaker => '说话人';

  @override
  String get viewerEditText => '内容';

  @override
  String get viewerEmpty => '这次转写没有产生文本。';

  @override
  String get viewerExport => '导出';

  @override
  String get viewerExportNeedsTimes => '需要真实时间';

  @override
  String viewerExportSaved(String name) {
    return '已保存为 $name';
  }

  @override
  String get viewerFontSize => '字号';

  @override
  String get viewerGroupSpeakers => '按说话人合并';

  @override
  String get viewerModeSegments => '分句';

  @override
  String get viewerModeTranscript => '全文';

  @override
  String get viewerNoResults => '没有匹配项';

  @override
  String get viewerOptions => '显示';

  @override
  String viewerSearchCount(int index, int total) {
    return '第 $index / $total 条';
  }

  @override
  String get viewerSearchHint => '在这份转写稿中搜索';

  @override
  String get viewerShowTimestamps => '显示时间';

  @override
  String viewerSpeakerFallback(int number) {
    return '说话人 $number';
  }

  @override
  String viewerSpeakerLines(int count) {
    return '$count 句';
  }

  @override
  String get viewerSpeakerName => '名称';

  @override
  String get viewerSpeakers => '说话人';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'MyTranscribe!!!!!';

  @override
  String get backupAutoBackup => '自動備份';

  @override
  String get backupAutoBackupDesc => '每天首次啟動應用程式時備份一次';

  @override
  String get backupCorrupt => '已損壞';

  @override
  String get backupCreate => '建立備份';

  @override
  String get backupCreated => '備份已建立';

  @override
  String get backupDeleteConfirm => '刪除這個備份？';

  @override
  String get backupFailed => '無法建立備份';

  @override
  String get backupForceUploadDone => '遠端副本已覆蓋';

  @override
  String get backupForceUploadFailed => '上傳失敗';

  @override
  String get backupForceUploadPrompt => '是否用還原後的資料覆蓋遠端副本？';

  @override
  String get backupForceUploadSkip => '暫不';

  @override
  String backupHistory(int count) {
    return '歷史記錄（$count）';
  }

  @override
  String backupKeepDays(int days) {
    return '$days 天';
  }

  @override
  String get backupKeepForever => '永久保留';

  @override
  String get backupLocalOnlyNote => '備份僅儲存在本機，不會上傳到任何地方。';

  @override
  String get backupModuleSettings => '來源和模型';

  @override
  String get backupNoBackups => '暫無備份';

  @override
  String get backupRestore => '還原';

  @override
  String get backupRestoreConfirm => '這將用備份覆蓋所選資料，是否繼續？';

  @override
  String get backupRestoreFailed => '無法還原備份';

  @override
  String get backupRestoreModules => '還原內容';

  @override
  String get backupRestored => '備份已還原';

  @override
  String get backupRestoredSyncDisabled => '自動同步已關閉，以免還原的資料被誤合併到伺服器。';

  @override
  String get backupRetention => '保留期限';

  @override
  String get backupSelectAll => '全選';

  @override
  String get backupSubtitle => '來源和模型的副本，儲存在本機';

  @override
  String get backupTitle => '備份';

  @override
  String get cancel => '取消';

  @override
  String get capabilitySupported => '支援';

  @override
  String get capabilityUnknown => '未驗證';

  @override
  String get capabilityUnsupported => '不支援';

  @override
  String get commonAdd => '新增';

  @override
  String get commonClose => '關閉';

  @override
  String get commonCopy => '複製';

  @override
  String get commonEdit => '編輯';

  @override
  String get commonRemove => '移除';

  @override
  String get commonRetry => '重試';

  @override
  String get commonShare => '分享';

  @override
  String get delete => '刪除';

  @override
  String get exportData => '匯出為 ZIP';

  @override
  String get importData => '從 ZIP 匯入';

  @override
  String get jobDeleteConfirm => '刪除這筆轉寫記錄？本應用保存的轉換後音訊與轉寫檔案會一併刪除，原始錄音不受影響。';

  @override
  String get jobDeleted => '轉寫記錄已刪除';

  @override
  String jobDiskUsage(String size) {
    return '在本裝置佔用 $size';
  }

  @override
  String get jobFieldFinished => '完成於';

  @override
  String get jobFieldLength => '長度';

  @override
  String get jobFieldModel => '模型';

  @override
  String get jobFieldSize => '大小';

  @override
  String get jobFieldSource => '來源';

  @override
  String get jobFieldStarted => '開始於';

  @override
  String get jobOpenTranscript => '開啟轉寫稿';

  @override
  String get jobPathCopied => '路徑已複製';

  @override
  String get jobResume => '繼續';

  @override
  String get jobRetry => '重試';

  @override
  String get jobRetryWithoutSpeakers => '不辨識說話人再試一次';

  @override
  String get jobSectionOutputs => '轉寫檔案';

  @override
  String get jobSectionPlan => '傳送方式';

  @override
  String get jobSectionProblem => '出了什麼問題';

  @override
  String get jobSectionRecording => '錄音';

  @override
  String jobSegmentsDone(int done, int total) {
    return '已完成 $done / $total 段';
  }

  @override
  String jobSentInSegments(int count, String minutes, String overlap) {
    return '$count 段，每段約 $minutes 分鐘，重疊 $overlap 秒';
  }

  @override
  String get jobSentWhole => '整段傳送';

  @override
  String get jobStageCancelled => '已停止';

  @override
  String jobStageCutting(int index, int total) {
    return '正在切分第 $index 段，共 $total 段';
  }

  @override
  String get jobStageDone => '已完成';

  @override
  String get jobStageFailed => '未能完成';

  @override
  String get jobStageMerging => '正在合併分段';

  @override
  String get jobStageNormalizing => '正在轉換音訊';

  @override
  String get jobStagePlanning => '正在規劃';

  @override
  String get jobStageProbing => '正在讀取錄音';

  @override
  String get jobStageQueued => '等待中';

  @override
  String get jobStageRendering => '正在寫入轉寫稿';

  @override
  String get jobStageSpeakers => '正在比對說話人';

  @override
  String jobStageUploading(int index, int total) {
    return '正在轉寫第 $index 段，共 $total 段';
  }

  @override
  String get jobStart => '開始';

  @override
  String get jobStop => '停止';

  @override
  String get jobsEmptyBody => '選擇一個錄音開始轉寫。長檔案會自動分段，中斷後可以繼續。';

  @override
  String get jobsEmptyTitle => '還沒有轉寫紀錄';

  @override
  String get jobsNew => '新增轉寫';

  @override
  String get jobsSelectPrompt => '選擇一筆轉寫記錄，查看它的情況。';

  @override
  String get jobsTitle => '轉寫';

  @override
  String get libraryAddModel => '新增模型';

  @override
  String get libraryAddSource => '新增來源';

  @override
  String get libraryApiKey => 'API 金鑰';

  @override
  String get libraryApiKeyClear => '刪除金鑰';

  @override
  String get libraryApiKeyMissing => '尚未設定';

  @override
  String get libraryApiKeyNotNeeded => '此來源不需要金鑰';

  @override
  String get libraryApiKeyNote => '儲存在本機。只會傳送給此來源；連線安全時才會同步到你的 WebDAV 伺服器。';

  @override
  String get libraryApiKeySave => '儲存金鑰';

  @override
  String get libraryApiKeySet => '已在本機設定';

  @override
  String get libraryAuth => '驗證方式';

  @override
  String get libraryAuthBearer => 'API 金鑰';

  @override
  String get libraryAuthHeader => '自訂標頭';

  @override
  String get libraryAuthHeaderName => '標頭名稱';

  @override
  String get libraryAuthNone => '無';

  @override
  String get libraryBaseUrl => '位址';

  @override
  String get libraryCapabilities => '該模型支援';

  @override
  String get libraryDeleteModel => '刪除此模型';

  @override
  String get libraryDeleteSource => '刪除此來源';

  @override
  String get libraryDeleteSourceConfirm => '將同時刪除該來源下的模型。錄音和逐字稿不受影響。';

  @override
  String get libraryDialect => '協定';

  @override
  String get libraryDiarization => '區分說話人';

  @override
  String get libraryDisplayName => '顯示為';

  @override
  String get libraryEmptyBody =>
      '來源是一個 API 端點，例如 OpenAI 或 OpenRouter，以及它提供的模型。';

  @override
  String get libraryEmptyTitle => '還沒有來源';

  @override
  String get libraryImportModels => '匯入模型';

  @override
  String get libraryKeywords => '接受關鍵字';

  @override
  String get libraryLimits => '限制';

  @override
  String get libraryMaxDuration => '單次請求音訊上限（秒）';

  @override
  String get libraryMaxFileSize => '單次上傳上限（MB）';

  @override
  String get libraryMaxRequest => '閘道請求上限（秒）';

  @override
  String get libraryModelName => '模型識別碼';

  @override
  String libraryModelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個模型',
      zero: '沒有模型',
    );
    return '$_temp0';
  }

  @override
  String get libraryName => '名稱';

  @override
  String get libraryNoNewModels => '沒有可新增的模型';

  @override
  String get libraryOverridden => '已被你修改';

  @override
  String get libraryPrompt => '接受上下文';

  @override
  String get libraryResetToTemplate => '還原內建設定';

  @override
  String get librarySegmentTimestamps => '分段時間';

  @override
  String get librarySelectItem => '選擇一個來源或模型';

  @override
  String get libraryTitle => '來源庫';

  @override
  String get libraryUnlimited => '無限制';

  @override
  String get libraryUnverified => '未驗證';

  @override
  String get libraryWordTimestamps => '逐詞時間';

  @override
  String get navLibrary => '來源庫';

  @override
  String get navSettings => '設定';

  @override
  String get navTranscribe => '轉寫';

  @override
  String get newJobChange => '重新選擇';

  @override
  String get newJobChoose => '選擇錄音';

  @override
  String get newJobDiarize => '辨識說話人';

  @override
  String get newJobDiarizeUnknown => '尚不清楚該模型是否標註說話人。若被拒絕，會提示你不帶此選項重試。';

  @override
  String get newJobDiarizeUnsupported => '該模型不標註說話人。';

  @override
  String get newJobKeepChunks => '保留切分後的音訊';

  @override
  String get newJobKeepChunksHint => '便於釐清某一段為何出錯，會佔用更多空間。';

  @override
  String get newJobKeywords => '關鍵詞';

  @override
  String get newJobKeywordsHint => '錄音中可能出現的詞語。';

  @override
  String get newJobLanguages => '語言提示';

  @override
  String get newJobLanguagesHint => '如 en 或 zh，可能性最高的放前面。留空則由模型自行判斷。';

  @override
  String get newJobNoFile => '尚未選擇錄音';

  @override
  String get newJobNoKey => '該來源尚未設定 API Key。';

  @override
  String get newJobNoModels => '請先在資料庫中新增來源。';

  @override
  String get newJobOpenLibrary => '開啟資料庫';

  @override
  String get newJobOptions => '選項';

  @override
  String get newJobPlanPending => '選擇錄音後即可看到傳送方式。';

  @override
  String get newJobPlanTitle => '將如何傳送';

  @override
  String get newJobPrompt => '上下文';

  @override
  String get newJobPromptHint => '人名、術語，或一句話說明錄音內容。有助於模型依你的習慣書寫。';

  @override
  String get newJobStart => '開始轉寫';

  @override
  String get newJobTitle => '新增轉寫';

  @override
  String get ok => '確定';

  @override
  String get planFitsWhole => '檔案夠小，可以整段傳送。';

  @override
  String planOverlapForSpeakers(String seconds) {
    return '分段之間重疊 $seconds 秒，以便跨段比對說話人。';
  }

  @override
  String get planSplitByDuration => '超過該模型單次請求可接受的長度。';

  @override
  String get planSplitByFormat => '這種格式需要先轉換。';

  @override
  String get planSplitBySize => '檔案過大，無法整段傳送。';

  @override
  String planWindowByCeiling(String seconds) {
    return '為求穩妥，分段長度上限為 $seconds 秒。';
  }

  @override
  String planWindowByModel(String seconds) {
    return '分段長度受模型 $seconds 秒的限制。';
  }

  @override
  String planWindowByProvider(String seconds) {
    return '分段長度受來源 $seconds 秒的限制。';
  }

  @override
  String get planWindowBySize => '分段長度依大小上限選定。';

  @override
  String get planWindowByUser => '分段長度由你指定。';

  @override
  String get save => '儲存';

  @override
  String get settingsAbout => '關於';

  @override
  String get settingsData => '資料';

  @override
  String get settingsExportSubtitle => '把來源和模型儲存為檔案';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsImportSubtitle => '從檔案載入來源和模型';

  @override
  String get settingsKeepChunks => '保留音訊分段';

  @override
  String get settingsKeepChunksSubtitle => '轉寫結束後保留切分出的音訊，佔用空間與原錄音相當';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSystem => '跟隨系統';

  @override
  String get settingsLicense => '授權條款 (GPLv3)';

  @override
  String get settingsLicenses => '開源授權';

  @override
  String get settingsMediaTools => '音訊工具';

  @override
  String get settingsMediaToolsBuiltIn => '已內建';

  @override
  String get settingsMediaToolsChoose => '選擇檔案…';

  @override
  String get settingsMediaToolsClear => '改為自動尋找';

  @override
  String get settingsMediaToolsDownload => '下載';

  @override
  String get settingsMediaToolsDownloadFailed => '下載未能完成';

  @override
  String get settingsMediaToolsDownloaded => '音訊工具已就緒';

  @override
  String get settingsMediaToolsDownloading => '正在下載…';

  @override
  String get settingsMediaToolsExplain =>
      '切分長錄音需要 FFmpeg 這個免費的音訊工具。可以讓應用程式替你下載，也可以指定你已有的版本。';

  @override
  String get settingsMediaToolsMissing => '尚未設定';

  @override
  String get settingsMediaToolsReady => '已就緒';

  @override
  String get settingsMediaToolsSubtitleMissing => '切分長錄音需要它';

  @override
  String get settingsMediaToolsSubtitleReady => '可以切分長錄音後上傳';

  @override
  String get settingsPrivacyPolicy => '隱私政策';

  @override
  String get settingsSelectItem => '從左側清單中選擇一項';

  @override
  String get settingsStorageLocation => '儲存位置';

  @override
  String get settingsStorageLocationSubtitle => '錄音和逐字稿的存放位置';

  @override
  String get settingsSyncSubtitle => '把來源和模型同步到你自己的伺服器';

  @override
  String get settingsTheme => '主題';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeLight => '淺色';

  @override
  String get settingsThemeSystem => '跟隨系統';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsTranscription => '轉寫';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsWebDAVAutoSync => '自動同步';

  @override
  String get settingsWebDAVAutoSyncConflict => '自動同步發現衝突';

  @override
  String get settingsWebDAVAutoSyncDesc => '複習後和應用程式恢復時自動同步';

  @override
  String get settingsWebDAVAutoSyncFailed => '自動同步失敗';

  @override
  String get settingsWebDAVConfigRemoved => '設定已移除';

  @override
  String get settingsWebDAVConfigSaved => '設定已儲存';

  @override
  String get settingsWebDAVConnectionFailed => '連線失敗';

  @override
  String get settingsWebDAVConnectionSuccess => '連線成功';

  @override
  String get settingsWebDAVDisconnect => '中斷連線';

  @override
  String get settingsWebDAVForceDownload => '強制下載';

  @override
  String get settingsWebDAVForceDownloadConfirmBody =>
      '將用遠端學習進度替換本地內容。上次同步後本地的變更將遺失。';

  @override
  String get settingsWebDAVForceDownloadConfirmTitle => '確認強制下載？';

  @override
  String get settingsWebDAVForceUpload => '強制上傳';

  @override
  String get settingsWebDAVForceUploadConfirmBody =>
      '將用本地學習進度覆蓋遠端內容。上次同步後遠端的變更將遺失。';

  @override
  String get settingsWebDAVForceUploadConfirmTitle => '確認強制上傳？';

  @override
  String get settingsWebDAVLastSuccess => '上次成功同步';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud 預設';

  @override
  String get settingsWebDAVNotConfigured => '尚未連線';

  @override
  String get settingsWebDAVPassword => '密碼';

  @override
  String get settingsWebDAVRemotePath => '遠端路徑';

  @override
  String get settingsWebDAVServerURL => '伺服器位址';

  @override
  String get settingsWebDAVSync => 'WebDAV 同步';

  @override
  String get settingsWebDAVSyncFailed => '同步失敗';

  @override
  String get settingsWebDAVSyncNow => '立即同步';

  @override
  String get settingsWebDAVSyncSuccess => '同步完成';

  @override
  String settingsWebDAVSyncWarnings(int count) {
    return '同步完成，但有 $count 條警告';
  }

  @override
  String get settingsWebDAVSyncing => '同步中…';

  @override
  String get settingsWebDAVTestConnection => '測試連線';

  @override
  String get settingsWebDAVUsername => '使用者名稱';

  @override
  String get syncConflictDesc => '上次同步之後，兩台裝置都改過它。請保留其中一個版本。';

  @override
  String syncConflictTitle(Object name) {
    return '同步衝突：$name';
  }

  @override
  String get syncKeepLocal => '保留本地';

  @override
  String get syncKeepRemote => '保留遠端';

  @override
  String get syncLocalVersion => '本地版本';

  @override
  String syncModifiedAt(Object time) {
    return '修改時間：$time';
  }

  @override
  String get syncPhaseConnecting => '正在連線…';

  @override
  String syncPhaseDownloadingData(Object file, int current, int total) {
    return '正在下載 $file（$current/$total）';
  }

  @override
  String syncPhaseMerging(Object file) {
    return '正在合併 $file…';
  }

  @override
  String syncPhaseUploadingData(Object file) {
    return '正在上傳 $file…';
  }

  @override
  String get syncRemoteVersion => '遠端版本';

  @override
  String get syncUnknownItem => '目前內容庫中沒有這一項。';

  @override
  String get viewerApproximate => '該模型沒有回傳時間，這裡顯示的是依分段起點推估的時間。';

  @override
  String get viewerAudioMissing => '本裝置上已沒有轉換後的音訊，無法播放。';

  @override
  String get viewerAutoScroll => '跟隨播放';

  @override
  String get viewerCopied => '轉寫稿已複製';

  @override
  String get viewerCopyAll => '複製整份轉寫稿';

  @override
  String get viewerEditNobody => '不指定';

  @override
  String get viewerEditSegment => '編輯這一句';

  @override
  String get viewerEditSpeaker => '說話人';

  @override
  String get viewerEditText => '內容';

  @override
  String get viewerEmpty => '這次轉寫沒有產生文字。';

  @override
  String get viewerExport => '匯出';

  @override
  String get viewerExportNeedsTimes => '需要真實時間';

  @override
  String viewerExportSaved(String name) {
    return '已儲存為 $name';
  }

  @override
  String get viewerFontSize => '字級';

  @override
  String get viewerGroupSpeakers => '依說話人合併';

  @override
  String get viewerModeSegments => '分句';

  @override
  String get viewerModeTranscript => '全文';

  @override
  String get viewerNoResults => '沒有相符的項目';

  @override
  String get viewerOptions => '顯示';

  @override
  String viewerSearchCount(int index, int total) {
    return '第 $index / $total 筆';
  }

  @override
  String get viewerSearchHint => '在這份轉寫稿中搜尋';

  @override
  String get viewerShowTimestamps => '顯示時間';

  @override
  String viewerSpeakerFallback(int number) {
    return '說話人 $number';
  }

  @override
  String viewerSpeakerLines(int count) {
    return '$count 句';
  }

  @override
  String get viewerSpeakerName => '名稱';

  @override
  String get viewerSpeakers => '說話人';
}
