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
  String get jobsEmptyBody => '选择一个录音开始转写。长文件会自动分段，中断后可以继续。';

  @override
  String get jobsEmptyTitle => '还没有转写记录';

  @override
  String get jobsNew => '新建转写';

  @override
  String get jobsTitle => '转写';

  @override
  String get libraryEmptyBody =>
      '来源是一个 API 端点，例如 OpenAI 或 OpenRouter，以及它提供的模型。';

  @override
  String get libraryEmptyTitle => '还没有来源';

  @override
  String get libraryTitle => '来源库';

  @override
  String get navLibrary => '来源库';

  @override
  String get navSettings => '设置';

  @override
  String get navTranscribe => '转写';

  @override
  String get ok => '确定';

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
  String get jobsEmptyBody => '選擇一個錄音開始轉寫。長檔案會自動分段，中斷後可以繼續。';

  @override
  String get jobsEmptyTitle => '還沒有轉寫紀錄';

  @override
  String get jobsNew => '新增轉寫';

  @override
  String get jobsTitle => '轉寫';

  @override
  String get libraryEmptyBody =>
      '來源是一個 API 端點，例如 OpenAI 或 OpenRouter，以及它提供的模型。';

  @override
  String get libraryEmptyTitle => '還沒有來源';

  @override
  String get libraryTitle => '來源庫';

  @override
  String get navLibrary => '來源庫';

  @override
  String get navSettings => '設定';

  @override
  String get navTranscribe => '轉寫';

  @override
  String get ok => '確定';

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
}
