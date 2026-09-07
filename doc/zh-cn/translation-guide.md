# 翻译指南

`doc/en-us/` 是权威版本。其他每个语言目录都与它逐一对应 —— 相同的文件、相同的标题、相同的表格、相同的示
例 —— 文档改动要在同一次提交中更新所有语言。

## 1. 范围

发布两种语言：简体中文（`zh`）与繁体中文（`zh_TW`）。**两者都由人工维护。** 繁体中文不是简体的字形转换：台湾
用法在词汇上有差异，转换出来的文件读起来就是一份没人校对过的译文。

## 2. 语气

为使用这个应用的人书写。句子要短，不用他们无法据以行动的术语，设置项副标题里不出现文件名或协议名。英文说
"recording"的地方，中文说"录音"，不说"音频文件" —— 用用户自己会用的那个具体词。

## 3. 不翻译的内容

- 模型标识（`gpt-transcribe`、`microsoft/mai-transcribe-2`）与服务方名称。
- 文件名、JSON 键、代码标识符，以及反引号内的一切。
- 许可证正文 —— 只有不翻译，它在每种语言里说的才是同一件事。
- 导出格式名称（SRT、VTT、CSV）。

## 4. 占位符

翻译后的消息插入的占位符必须与英文完全一致，名称也一致。`test/l10n_arb_test.dart` 会在不一致时失败，因为改
了名的占位符能通过编译，然后在运行时抛出异常。

## 5. 术语表

### 5.1 跨应用通用术语

与 MyAnime、MyDay、MyDevice、MyNihongo 及 MyApps-DATA 共用。这里新增的术语要在同一次改动中加入每个兄弟仓库
的 5.1 节。

| English | 简体 | 繁體 |
|---|---|---|
| sync | 同步 | 同步 |
| conflict | 冲突 | 衝突 |
| backup | 备份 | 備份 |
| restore | 恢复 | 還原 |
| export / import | 导出 / 导入 | 匯出 / 匯入 |
| settings | 设置 | 設定 |
| storage location | 存储位置 | 儲存位置 |
| data | 数据 | 資料 |
| file | 文件 | 檔案 |
| device | 设备 | 裝置 |
| local version / remote version | 本地版本 / 远程版本 | 本機版本 / 遠端版本 |
| server | 服务器 | 伺服器 |
| network | 网络 | 網路 |

### 5.2 本应用专有术语

| English | 简体 | 繁體 | 说明 |
|---|---|---|---|
| transcribe / transcription | 转写 | 轉寫 | 动作及其结果。不用"听写"，那带有口述记录的意味。 |
| transcript | 转写稿 | 逐字稿 | "逐字稿"是台湾的自然说法。 |
| recording | 录音 | 錄音 | |
| title (of a transcription) | 名称 | 名稱 | 用户为一次转写起的称呼；只是标签，不是文件名。 |
| source (a provider) | 来源 | 來源 | 用户自己对"一个端点加上它的模型"的叫法。 |
| model | 模型 | 模型 | |
| model library | 模型库 | 模型庫 | |
| chunk / window | 分段 | 分段 | 被切分的录音中的一块。 |
| overlap | 重叠 | 重疊 | |
| resume (a job) | 继续 | 繼續 | |
| speaker | 说话人 | 說話人 | |
| speaker identification | 说话人识别 | 說話人識別 | |
| speaker unification | 说话人统一 | 說話人統一 | 跨分段保持同一身份。 |
| known speaker reference | 已知说话人样本 | 已知說話人樣本 | |
| timestamp | 时间戳 | 時間戳 | |
| segment (of a transcript) | 片段 | 片段 | 与"分段"不同，后者指一块音频。 |
| API key | API 密钥 | API 金鑰 | |
| secure endpoint | 安全端点 | 安全端點 | |
| trusted host | 受信任主机 | 受信任主機 | |
| diarization | 说话人分离 | 說話人分離 | 面向用户的文案优先用"说话人识别"。 |
