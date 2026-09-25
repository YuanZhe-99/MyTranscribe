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
| unknown speaker | 未知 | 未知 | 没有人被记名的句子。在没有界面语言可用时写出的文件里用英文 `Unknown`。 |
| speaker names (the saved list) | 说话人名称 | 說話者名稱 | 命名说话人时提供的候选名称。 |
| speaker identification | 说话人识别 | 說話人識別 | |
| speaker unification | 说话人统一 | 說話人統一 | 跨分段保持同一身份。 |
| known speaker reference | 已知说话人样本 | 已知說話人樣本 | |
| timestamp | 时间戳 | 時間戳 | |
| segment (of a transcript) | 片段 | 片段 | 与"分段"不同，后者指一块音频。 |
| API key | API 密钥 | API 金鑰 | |
| transcripts projection | 转写投影 | 轉寫投影 | 由任务文件夹生成的、可同步的文件。 |
| converted audio | 转换后的音频 | 轉換後的音訊 | 供回放的副本，不是原始录音。 |
| secure endpoint | 安全端点 | 安全端點 | |
| trusted host | 受信任主机 | 受信任主機 | |
| diarization | 说话人分离 | 說話人分離 | 面向用户的文案优先用"说话人识别"。 |
| local model | 本地模型 | 本機模型 | 在设备上运行的模型。台湾用"本機"指"这台机器"。 |
| hotwords | 热词 | 熱詞 | 告诉模型优先识别的词；Qwen3-ASR 把任务的关键词当作热词。 |
| engine | 引擎 | 引擎 | 运行本地模型的运行时；很少出现在面向用户的文案里。 |
| download (a model) | 下载 | 下載 | |
| compute device | 计算设备 | 運算裝置 | 模型运行所在的 CPU、GPU 或 NPU。台湾用"裝置"，不用"設備"。 |
| on this device | 在本机 | 在本機 | |
| verified / unverified / experimental | 已验证 / 未验证 / 实验性 | 已驗證 / 未驗證 / 實驗性 | 用于路线。"未验证"是一种发布状态，不是错误。 |
| tested on this kind of device | 已在此类设备上测试 | 已在此類裝置上測試 | "已验证"对用户的含义。 |
| smoke test (a route's check on this device) | 本机检查 | 本機檢查 | 面向用户的文案说"检查"，不说"冒烟测试"。 |
| placement | 运行位置 | 執行位置 | 一个分段实际运行的位置：CPU、GPU、NPU。 |
| fallback | 回退 | 備援 | 可见地改用另一条路线；绝不是悄悄替换。 |
| system recogniser | 系统语音识别 | 系統語音辨識 | 操作系统自带的识别器。台湾把语音识别说成"辨識"。 |
| artifact (the downloaded package) | 模型包 | 模型套件 | 一个本地模型要下载的文件。 |
| diagnostics report | 诊断报告 | 診斷報告 | 用户复制的文本；应用不会把它发送到任何地方。 |
