# 数据格式

应用写入的每个文件、放在哪里，以及它会不会离开本机。

## 清单

除非用户设置了自定义存储路径，所有路径都相对于应用目录，即 `<documents>/MyTranscribe`。
`storage_config.json` 是例外：它始终位于平台默认目录，因为它正是记录自定义路径的那个文件。

| 文件 | 内容 | 是否同步 | 备份 / ZIP |
|---|---|---|---|
| `transcribe_settings.json` | 来源、模型、默认值 | 是 —— 唯一的数据模块 | 是 |
| `transcribe_secrets.json` | API Key，每个来源一个 | 仅在安全端点下，通过单独的交换流程 | **否** |
| `storage_config.json` | 设备本地偏好 | 否 | 否 |
| `webdav_config.json` | 服务器地址、凭据、自动同步开关 | 否 | 否 |
| `.sync_base/` | 每个模块上次达成一致的副本、客户端 id、本地上传锁 | 否 | 否 |
| `backups/` | 备份包，以及按内容寻址的数据块存储 | 否 | 否 |
| `jobs/<id>/` | 一次转写任务：音频、分段、原始响应、转写稿、导出 | **否** | **否** |

后三项排除是结构性的。同步、备份与 ZIP 引擎只会接触 `lib/app/data_modules.dart` 中注册表里的文件名，而
该注册表恰好只有一条。

## `transcribe_settings.json` —— 会同步的文档

```jsonc
{
  "records": [
    {
      "id": "provider:openai",
      "kind": "provider",
      "createdAt": "2026-09-05T10:00:00.000Z",
      "modifiedAt": "2026-09-05T10:00:00.000Z",
      "payload": { "name": "OpenAI", "baseUrl": "https://api.openai.com/v1", "...": "..." }
    },
    { "id": "model:openai:gpt-transcribe", "kind": "model", "payload": { "...": "..." } },
    { "id": "defaults", "kind": "defaults", "payload": { "...": "..." } }
  ]
}
```

### 各类 payload 的内容

| kind | payload |
|---|---|
| `provider` | `name`、`dialect`（`openai`、`openrouter`、`openaiCompatible`）、`baseUrl`、`authScheme`（`bearer`、`none`、`header`）与 `authHeaderName`、`extraHeaders`、`maxFileBytes`、`maxRequestSeconds`、`requestTimeoutSeconds`、`defaultModelId`、`templateId`、`overriddenFields`、`templateVersion` |
| `model` | `providerId`、`modelName`（实际发出的名称）、`displayName`、`maxFileBytes`、`maxDurationSeconds`、`diarization` / `wordTimestamps` / `segmentTimestamps`（各为 `supported`、`unsupported` 或 `unknown`）、`supportsPrompt`、`supportsKeywords`、`languageParamStyle`（`languages`、`language`、`none`）、`responseFormats`、`inputFormats`、`maxKnownSpeakers`、`requiresChunkingStrategy`、`templateId`、`overriddenFields`、`templateVersion` |
| `defaults` | `providerId`、`modelId`、`languages`、`prompt`、`keywords`、`diarize`（true、false，或缺省表示"照该模型最擅长的来"）、`plainOverlapSeconds`、`diarizedOverlapSeconds`、`enrollmentEnabled`、`knownSpeakerNames` |

`overriddenFields` 是模板刷新得以安全进行的原因：新版本的取值会到达**没有**列在其中的每个字段，而用户
改过的字段保持不动。`templateVersion` 记录该记录上次是从哪个版本的取值刷新而来的。

能力有**三**种状态，不是两种。对用户自行配置的端点来说，"尚未验证"是一个真实的答案，应用对它的处理也不同
于"不支持"：它会带着提示提供该功能，而不是把它藏起来。

该文档是**扁平的记录列表**，每条记录带一个不透明的 `payload`。同步引擎每条记录只需要一个 id 和一个时间
戳，因此把带类型的结构放在上一层，就意味着新版本写入的记录在这里依然能正确合并 —— 即便本版本无法理解它的
payload。无法识别的 `kind` 读作 `unknown`，会被原样带过而不是丢弃。

时间戳为 **UTC**。在另一个时区的设备上读到的本地时间值会悄悄打乱编辑顺序。所有编辑都经由
`SettingsRecord.touch`，那是设置 `modifiedAt` 的唯一途径，因此没有哪次编辑会忘记推进它、进而输给更旧的
远端副本。

顶层与每条记录上未知的字段都保存在 `extraJson` 中并写回，因此旧版本永远不会删掉新版本的数据。缺失或无法
解析的时间戳回落到 Unix 纪元，绝不回落到"现在" —— 那会让一条从未改动的记录在每次读取时都显得比远端更新，
从而赢下每一次合并。

记录 id 是一份兼容性契约：跨设备是按 id 来指代一条记录的，模板记录使用派生 id
（`provider:openai`、`model:openai:gpt-transcribe`），这样两台全新设备生成的是同一批 id，首次同步会合并
而不是产生重复。

删除是真正的删除，不是墓碑。共享合并引擎从基线快照读取删除：出现在基线中而本地没有的记录，就是本设备做出
的删除，它会传播出去。

## `transcribe_secrets.json` —— 密钥

```jsonc
{
  "version": 1,
  "keys": {
    "provider:openai": { "apiKey": "sk-...", "updatedAt": "2026-09-05T10:00:00.000Z" },
    "provider:removed": { "apiKey": null, "updatedAt": "2026-09-06T10:00:00.000Z" }
  }
}
```

有意不作为数据模块。以来源的记录 id 为键，因此密钥跟随它的来源。`apiKey` 为 `null` 是墓碑：没有它，在一
台设备上删除密钥，下一次交换就会让另一台设备的副本回来。

按键以 `updatedAt` 合并，后写者胜。这里没有三路合并，也没有基线快照，正因如此该交换在同步锁之外运行也是
安全的 —— 参见 [`features/secure-secrets-sync.md`](features/secure-secrets-sync.md)。

## `storage_config.json` —— 设备本地偏好

由存储中枢通过强类型访问器读写。**默认值以缺省键的形式保存**，这样后续版本改变某个默认值时，对所有从未
动过该设置的人都会生效。类型不对的值读作未设置，因此手工改坏的文件不会让应用崩溃。

| 键 | 含义 |
|---|---|
| `storagePath` | 自定义应用目录；缺省表示平台默认位置 |
| `themeMode` | `light` 或 `dark`；缺省表示跟随系统 |
| `locale` | `language` 或 `language_COUNTRY`；缺省表示跟随系统 |
| `lastTab` | 启动时打开的标签页 |
| `viewerFontSize`、`viewerShowTimestamps`、`viewerGroupSpeakers` | 转写稿查看器的偏好 |
| `keepChunkFiles` | 任务完成后保留切分后的音频 |
| `ffmpegPath`、`ffprobePath` | 用户自己的工具路径 |
| `secretsTrustedHosts` | 用户标记为可用明文 HTTP 传输密钥的主机 |
| `autoBackupEnabled`、`backupRetentionDays` | 由共享备份引擎拥有 |

这里的一切按设计都是设备本地的。在桌面上存在的工具路径在手机上什么也不是；同一个受信任主机在这里解析到本
网络的一台机器，在另一台设备上可能完全是别的东西；而窗口偏好是设备的属性，不是账号的属性。

## `jobs/<id>/` —— 一次转写

由任务引擎写入。永不同步、永不备份、永不进入 ZIP 导出：几小时的私人录音不该出现在一个要发往服务器的
备份包里。

| 条目 | 内容 |
|---|---|
| `job.json` | 任务记录：来源、用户给它起的名字、选项、切分方案、每段结果、阶段、错误 |
| `audio.mp3` | 转换后的录音，单声道 16 kHz 64 kbps —— 也是查看器用来播放的副本；转写稿读完后可在详情页删除 |
| `source.<ext>` | 仅移动端，所选文件的一份副本 |
| `chunks/chunk_0000.mp3` | 一个分段窗口，任务完成后删除，除非用户选择保留；因文件被占用而残留的，会在下次启动时清扫 |
| `chunks/chunk_0000.response.json` | 服务方的原始回复，会保留 —— 正是它让断点续传和重新进行说话人统一无需再次上传 |
| `speakers/<id>.wav` | 每位说话人的一小段样本，用于接受已知说话人参考的 API |
| `transcript.json` | 分句、说话人、窗口内标签与全局说话人的对应关系，以及用户的修正 |
| `exports/` | 渲染出的 Markdown、纯文本、字幕等 |

任务记录在每个分段之后原子重写，断点续传读的就是它。当某个分段保存的结果与磁盘上分段文件的大小一致时，该
分段会被复用；而当切分方案的指纹 —— 来源、模型、窗口长度、重叠、提示词、关键词 —— 不再匹配时，整个缓存会
被丢弃，因为在不同设置下产生的结果不是用户此刻要的结果。

## 原子性

所有写入都经由共享包的 `atomicWriteString`：在目标旁写一个临时文件，落盘，然后重命名。写到一半崩溃留下的
是原来完整的文件，而不是写了一半的文件。两空格缩进不是装饰 —— 同步在合并前会比较原始字符串，因此某个引擎
写出的格式若与存储中枢不同，该文件在每次同步时都会显得已改动而反复上传。
