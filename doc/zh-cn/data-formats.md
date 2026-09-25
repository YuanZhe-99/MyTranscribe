# 数据格式

应用写入的每个文件、放在哪里，以及它会不会离开本机。

## 清单

除非用户设置了自定义存储路径，所有路径都相对于应用目录，即 `<documents>/MyTranscribe`。
`storage_config.json` 是例外：它始终位于平台默认目录，因为它正是记录自定义路径的那个文件。

| 文件 | 内容 | 是否同步 | 备份 / ZIP |
|---|---|---|---|
| `transcribe_settings.json` | 来源、模型、本地模型、默认值 | 是 —— 一个数据模块 | 是 |
| `transcribe_transcripts.json` | 每条已完成转写的记录和文本 | 是 —— 一个数据模块 | 是 |
| `transcribe_secrets.json` | API Key，每个来源一个 | 仅在安全端点下，通过单独的交换流程 | **否** |
| `storage_config.json` | 设备本地偏好 | 否 | 否 |
| `webdav_config.json` | 服务器地址、凭据、自动同步开关 | 否 | 否 |
| `.sync_base/` | 每个模块上次达成一致的副本、客户端 id、本地上传锁 | 否 | 否 |
| `backups/` | 备份包，以及按内容寻址的数据块存储 | 否 | 否 |
| `jobs/<id>/` | 一次转写任务：音频、分段、原始响应、转写稿、导出 | **否** —— 但记录和转写稿会被投影进上面那个模块 | **否**，同上 |
| `models/<artifactId>/` | 一个已安装的本地模型包及其 `manifest.json` | **否** | **否** |
| `models/.downloads/` | 未完成的下载，以及组装安装内容的暂存文件夹 | 否 | 否 |
| `local_engine_state.json` | 本设备的各路线检查、进行中标记、路线选择与回退策略 | 否 | 否 |

`models/` 在 Android 与 Windows 上位于应用目录下。在 iOS 与 macOS 上它改放在系统的缓存目录里，iCloud
备份和 Time Machine 都不包含那里；桌面用户还可以用 `modelsPath` 把它指到任何地方。无论哪种情况，它都绝不
是数据模块。

这些排除是结构性的。同步、备份与 ZIP 引擎只会接触 `lib/app/data_modules.dart` 中注册表里的文件名，这正是
几个小时的私人音频和每一个 API Key 都不会进入发往服务器的备份包的原因。转写的**文本**仍然能够传输，靠的
是转写模块：它是任务文件夹的投影，见下文。

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
    { "id": "local:whisper-large-v3-turbo", "kind": "localModel", "payload": { "...": "..." } },
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
| `localModel` | `displayName`、`family`（`whisper`、`parakeet`、`qwen`、`custom`）、`languages`（为空表示不限）、`maxDurationSeconds`、`diarization` / `wordTimestamps` / `segmentTimestamps`、`supportsPrompt`、`supportsKeywords`、`artifacts`（按适配器 id 列出的模型包 id）、`templateId`、`overriddenFields`、`templateVersion` —— 不含任何关于某一台设备的内容 |

`overriddenFields` 是模板刷新得以安全进行的原因：新版本的取值会到达**没有**列在其中的每个字段，而用户
改过的字段保持不动。`templateVersion` 记录该记录上次是从哪个版本的取值刷新而来的。

能力有**三**种状态，不是两种。对用户自行配置的端点来说，"尚未验证"是一个真实的答案，应用对它的处理也不同
于"不支持"：它会带着提示提供该功能，而不是把它藏起来。

该文档是**扁平的记录列表**，每条记录带一个不透明的 `payload`。同步引擎每条记录只需要一个 id 和一个时间
戳，因此把带类型的结构放在上一层，就意味着新版本写入的记录在这里依然能正确合并 —— 即便本版本无法理解它的
payload。无法识别的 `kind` 读作 `unknown`，会被原样带过而不是丢弃 —— 连同 kind 字符串本身，它会按读到时
的样子原封不动地写回。0.2.x 会在原处写入字面量 `unknown`；因此经过这类版本的本地模型记录到达时是
`kind: unknown`，而由于每个本地模型 id 都以 `local:` 开头，本版本会把它重新读作 `localModel`。

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

## `transcribe_transcripts.json` —— 转写投影

第二个数据模块，也是唯一一个没有任何代码直接往里写的模块。它是 `jobs/` 的**投影**：在同步、备份或导出 ZIP
之前从任务文件夹重新生成，之后再写回去。`jobs/` 始终是真相所在，这个文件只是传输用的中间产物。

```jsonc
{ "records": [ { "id": "<jobId>",
                 "createdAt": "2026-09-01T09:00:00.000Z",
                 "modifiedAt": "2026-09-09T11:30:00.000Z",
                 "job":        { /* 整个 job.json */ },
                 "transcript": { /* 整个 transcript.json */ } } ] }
```

记录按 id 排序，并以两空格缩进美化输出，这样持有相同数据的两台设备会得到逐字节一致的文件，命中同步引擎的
原始相等快速路径。`modifiedAt` 取记录自身时间和转写稿 `editedAt` 中较晚的一个，因为重命名说话人并不会改动
任务记录，却恰恰是必须传播出去的那类改动。

`job` 和 `transcript` 是**原始 map**，原样携带、不做解析。任务记录内部的嵌套类型 —— 选项、切分方案、每个
分段的结果、媒体探测信息 —— 都没有自己的 `extraJson`，所以解析新版本写出的记录再写回去，会丢掉那个版本新增
的字段；两台设备接着就会轮流剥掉对方的字段并永远重新上传。

哪些内容会被投影、写回时又被允许对文件夹做什么，见 [`sync.md`](sync.md)：只有已完成的转写才会被重新投影，
正在重跑的任务会被冻结而不是丢弃，删除只来自三方合并，读不出来的记录会中止投影而不是在其中留下缺口。

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
| `autoSaveTranscriptFiles` | 任务完成后在录音旁写入一个 Markdown 和一个文本文件；默认关闭 |
| `syncIncludesAudio` | 同时把每条转写转换后的音频同步到服务器；默认关闭 |
| `ffmpegPath`、`ffprobePath` | 用户自己的工具路径 |
| `modelsPath` | 用户把下载的模型挪走后它们所在的位置；改动它时不会搬移任何东西 |
| `secretsTrustedHosts` | 用户标记为可用明文 HTTP 传输密钥的主机 |
| `autoBackupEnabled`、`backupRetentionDays` | 由共享备份引擎拥有 |

这里的一切按设计都是设备本地的。在桌面上存在的工具路径在手机上什么也不是；同一个受信任主机在这里解析到本
网络的一台机器，在另一台设备上可能完全是别的东西；而窗口偏好是设备的属性，不是账号的属性。

## `jobs/<id>/` —— 一次转写

由任务引擎写入。永不同步、永不备份、永不进入 ZIP 导出：几小时的私人录音不该出现在一个要发往服务器的
备份包里。

| 条目 | 内容 |
|---|---|
| `job.json` | 任务记录：来源、用户给它起的名字、选项、切分方案、每段结果、阶段、错误；本地模型还有 `options.device`、`route`、`artifactRevision`、`fallbacks`，以及每个分段的 `placement` 与 `routeKey` |
| `audio.mp3` | 转换后的录音，单声道 16 kHz 64 kbps —— 也是查看器用来播放的副本；转写稿读完后可在详情页删除 |
| `source.<ext>` | 仅移动端，所选文件的一份副本 |
| `chunks/chunk_0000.mp3` | 一个分段窗口，任务完成后删除，除非用户选择保留；因文件被占用而残留的，会在下次启动时清扫 |
| `chunks/chunk_0000.wav` | 本地模型的一个窗口：16 kHz 单声道 16 位 PCM，与 MP3 窗口一样被删除 |
| `chunks/chunk_0000.response.json` | 服务方的原始回复，会保留 —— 正是它让断点续传和重新进行说话人统一无需再次上传 |
| `speakers/<id>.wav` | 每位说话人的一小段样本，用于接受已知说话人参考的 API |
| `transcript.json` | 分句、说话人、窗口内标签与全局说话人的对应关系，以及用户的修正 |
| `audio.discarded` | 标记文件，说明转换后的音频是被有意移除的，同步不会再把它取回 |
| `exports/` | 渲染出的 Markdown、纯文本、字幕等 |

任务记录在每个分段之后原子重写，断点续传读的就是它。当某个分段保存的结果与磁盘上分段文件的大小一致时，该
分段会被复用；而当切分方案的指纹 —— 来源、模型、窗口长度、重叠、提示词、关键词 —— 不再匹配时，整个缓存会
被丢弃，因为在不同设置下产生的结果不是用户此刻要的结果。本地任务的指纹用本地模型、模型包修订版和所要求
的设备代替来源。

## `models/<artifactId>/` —— 一个已安装的模型包

由模型包管理器写入，绝不手工编辑。文件夹里存放模型包的文件和 `manifest.json`：

| 字段 | 含义 |
|---|---|
| `artifactId`、`modelId`、`adapterId` | 模型包本身、它服务的本地模型、加载它的适配器 |
| `format`、`quantization`、`revision` | `ggml`、`onnx`、`coreml` 或 `qnn`；如 `f16`、`q5_0`、`int8`；各 URL 所固定的上游修订版 |
| `files[]` | 下载了什么：`path`、`bytes`、`sha256`、`sourceUrl`，以及可选的 `platforms`、`unpack`（`zip`、`tarBz2`）和 `unpackedBytes` |
| `installed[]` | 解包后磁盘上有什么：`path`、`bytes`，以及在本设备上测得的 `sha256` |
| `licenseId`、`licenseUrl`、`attribution` | 模型的许可证，以及它要求的署名 |
| `minimumRamBytes`、`ramEstimateSource` | 加载后的会话所需的内存，以及这个数字是 `measured`、`documented` 还是 `unknown` |
| `installedAt` | 安装时间，UTC |

没有可读清单的文件夹视为未安装。未完成的下载放在 `models/.downloads/<artifactId>/`，以文件名加上其哈希的
开头命名，因此清单一旦改变，就绝不会续传旧文件的字节。

## `local_engine_state.json` —— 本设备的引擎

由引擎状态存储写入，原子写，一次只进行一个读-改-写。

| 键 | 含义 |
|---|---|
| `smokeTests` | 每条路线在本设备上的检查，键由适配器版本、模型哈希、操作系统版本、驱动版本、处理器和精度以 `\|` 连接而成：`routeKey`、`outcome`（`notRun`、`passed`、`failed`、`crashed`）、`text`、`similarity`、`realTimeFactor`、`reason`、`checkedAt` |
| `inFlight` | 当前正在运行的原生调用（如果有）：`routeKey`、`smokeKey`、`jobId`、`startedAt`；启动时发现的标记会把那条路线记为 `crashed` |
| `routeChoices` | 用户为每个本地模型 id 选择的路线：`cpu` 或一个路线键；缺省表示自动 |
| `fallbackPolicy` | `none` 或 `systemRecognizer`；缺省表示默认值，即同一模型在 CPU 上运行 |
| `allowServerSpeechRecognition` | 系统语音识别是否可以把音频发给其厂商；缺省表示否 |

## 原子性

所有写入都经由共享包的 `atomicWriteString`：在目标旁写一个临时文件，落盘，然后重命名。写到一半崩溃留下的
是原来完整的文件，而不是写了一半的文件。两空格缩进不是装饰 —— 同步在合并前会比较原始字符串，因此某个引擎
写出的格式若与存储中枢不同，该文件在每次同步时都会显得已改动而反复上传。

任务记录和转写稿还会**重试**。原子替换本质上是一次重命名，而在 Windows 上只要有别的东西打开着该文件 ——
杀毒软件、搜索索引器、正在读它的列表 —— 重命名就会直接失败。这种冲突只持续几毫秒，却可能让一小时的任务或
一整页修正付诸东流，所以 `retryingFileOperation` 会在约十分之一秒内重试六次才放弃。
