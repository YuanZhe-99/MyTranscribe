# Translation guide

`doc/en-us/` is authoritative. Every other language directory mirrors it exactly — same files, same
headings, same tables, same examples — and a documentation change updates all of them in the same
commit.

## 1. Scope

Two languages ship: Simplified Chinese (`zh`) and Traditional Chinese (`zh_TW`). **Both are
hand-maintained.** Traditional Chinese is not a character conversion of Simplified: Taiwan usage
differs by vocabulary, and a converted file reads as a translation nobody checked.

## 2. Register

Write for the person using the app. Short sentences, no jargon they cannot act on, no file names or
protocol names in a settings subtitle. Where the English says "recording", the Chinese says 录音,
not 音频文件 — the concrete word the user would use.

## 3. What is not translated

- Model identifiers (`gpt-transcribe`, `microsoft/mai-transcribe-2`) and provider names.
- File names, JSON keys, code identifiers, and anything inside backticks.
- The licence text, which says the same thing in every language only if it is not translated.
- Export format names (SRT, VTT, CSV).

## 4. Placeholders

A translated message interpolates exactly the placeholders the English one does, with the same
names. `test/l10n_arb_test.dart` fails when it does not, because a renamed placeholder compiles and
then throws at run time.

## 5. Glossary

### 5.1 Cross-cutting terms

Shared with MyAnime, MyDay, MyDevice, MyNihongo and MyApps-DATA. A new term here is added to every
sibling repository's Section 5.1 in the same change.

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

### 5.2 App-specific terms

| English | 简体 | 繁體 | Note |
|---|---|---|---|
| transcribe / transcription | 转写 | 轉寫 | The act and its result. Not 听写, which implies dictation. |
| transcript | 转写稿 | 逐字稿 | 逐字稿 is the natural Taiwan word. |
| recording | 录音 | 錄音 | |
| title (of a transcription) | 名称 | 名稱 | What the user calls one transcription; a label, not a file name. |
| source (a provider) | 来源 | 來源 | The user's own word for an endpoint plus its models. |
| model | 模型 | 模型 | |
| model library | 模型库 | 模型庫 | |
| chunk / window | 分段 | 分段 | One piece of a split recording. |
| overlap | 重叠 | 重疊 | |
| resume (a job) | 继续 | 繼續 | |
| speaker | 说话人 | 說話人 | |
| unknown speaker | 未知 | 未知 | A line nobody is credited with. English `Unknown` in files written without an interface language. |
| speaker names (the saved list) | 说话人名称 | 說話者名稱 | Names offered when naming a speaker. |
| speaker identification | 说话人识别 | 說話人識別 | |
| speaker unification | 说话人统一 | 說話人統一 | Keeping one identity across segments. |
| known speaker reference | 已知说话人样本 | 已知說話人樣本 | |
| timestamp | 时间戳 | 時間戳 | |
| segment (of a transcript) | 片段 | 片段 | Distinct from 分段, which is a piece of audio. |
| API key | API 密钥 | API 金鑰 | |
| transcripts projection | 转写投影 | 轉寫投影 | The syncable file built from the job folders. |
| converted audio | 转换后的音频 | 轉換後的音訊 | The listening copy, not the original recording. |
| secure endpoint | 安全端点 | 安全端點 | |
| trusted host | 受信任主机 | 受信任主機 | |
| diarization | 说话人分离 | 說話人分離 | Prefer 说话人识别 in user-facing text. |
