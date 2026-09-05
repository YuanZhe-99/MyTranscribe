# MyTranscribe!!!!! 文档（概念）

**MyTranscribe!!!!!**（所有面向用户的名称都带五个感叹号 —— 应用标题、启动器标签、安装程序元数据与
bundle 名称）使用用户自行配置的转写服务把录音转成文字。文件大到无法一次上传时，它用 FFmpeg 切成互相重叠的
窗口，能从被打断的运行继续，把各片拼回一份完整的转写稿，在模型支持时标出谁在说话，并通过共享的
`myapps_data` 引擎同步自己的配置。

- **作者 / 包名：** `yuanzhe`、`com.yuanzhe.my_transcribe`
- **许可证：** GPL-3.0
- **平台：** Android、Windows、iOS、macOS（不面向 Linux 与 Web）
- **框架：** Flutter，Dart SDK `^3.11.3`；针对 Flutter `3.44.2` 开发

本目录存放**概念**文档 —— 架构、数据格式、布局规则与各功能的行为 —— 面向需要理解应用**为什么**这样表现的人
与智能体。逐函数的 API 文档单独放在 [`functions/`](functions/)，翻译说明在
[`translation-guide.md`](translation-guide.md)。

**这些文档是对代码的权威描述。** 仓库的 `AGENTS.md` 有意只限于给智能体的指示 —— 工作流、写作规则、行为契约
与发布流程 —— 其余一律指向这里。代码改动时先更新这些页面；文档与代码不一致时，以代码为准核实，然后修正页面。

共享的 WebDAV 同步、备份与 ZIP 引擎不在本仓库。它们位于嵌入在 `packages/myapps_data` 的 `myapps_data` 包
中，文档在 `packages/myapps_data/doc/en-us/`。

## 目录

### 核心概念

- [`architecture.md`](architecture.md) —— 应用外壳、状态管理、导航、本地化、仓库结构，以及整个代码库遵循的
  核心架构规则。
- [`data-formats.md`](data-formats.md) —— 应用写入的每个文件、哪些会同步哪些不会，以及各自的结构。
- [`adaptive-layout.md`](adaptive-layout.md) —— 布局何时可以分栏、导航放在哪里、能放下几列，以及每个页面用
  哪条规则。
- [`sync.md`](sync.md) —— 共享 WebDAV 引擎在这里的配置：唯一的数据模块、它的合并、冲突如何到达用户，以及单
  独的 API 密钥交换。
- [`backup-restore.md`](backup-restore.md) —— 本地备份与 ZIP 导出导入在这里的配置。
- [`platform-notes.md`](platform-notes.md) —— 各平台的 FFmpeg 方案、Android 构建状态、Apple 权限、
  Windows on ARM64。
- [`ci-cd.md`](ci-cd.md) —— 验证命令集、构建命令与全新克隆的步骤。
- [`version-history.md`](version-history.md) —— 逐版本的摘要。

### 功能领域

- [`features/transcription-jobs.md`](features/transcription-jobs.md) —— 什么是一个任务、它的各个阶段，以及
  它如何继续。
- [`features/chunking-and-resume.md`](features/chunking-and-resume.md) —— 长录音为什么要切分，以及一次被打
  断的运行要付出什么。
- [`features/provider-library.md`](features/provider-library.md) —— 来源、模型及其能力字段。
- [`features/transcript-viewer.md`](features/transcript-viewer.md) —— 阅读、修正与导出一份转写稿。
- [`features/exports.md`](features/exports.md) —— 转写稿可以用哪六种格式离开，以及某份转写稿能用其中哪几
  种。
- [`features/diarization-and-speakers.md`](features/diarization-and-speakers.md) —— 谁在说话，以及这个答案
  如何在各窗口之间保持一致。
- [`features/media-tools.md`](features/media-tools.md) —— 应用如何找到或获取 FFmpeg。
- [`features/secure-secrets-sync.md`](features/secure-secrets-sync.md) —— API Key 存放在哪里，以及它们何时
  被允许离开本机。
- [`features/sync-and-backup.md`](features/sync-and-backup.md) —— 设置 · 数据 下的各个界面。

### 算法

- [`algorithms/chunk-planner.md`](algorithms/chunk-planner.md) —— 录音如何被切分。
- [`algorithms/overlap-merge.md`](algorithms/overlap-merge.md) —— 各片如何被拼回去。
- [`algorithms/speaker-unification.md`](algorithms/speaker-unification.md) —— 一位说话人如何在各窗口之间保
  持同一身份。
- [`algorithms/secure-endpoint.md`](algorithms/secure-endpoint.md) —— 什么算是可以发送 API Key 的安全去处。

### 参考

- [`functions/INDEX.md`](functions/INDEX.md) —— 每个源文件一页。
- [`translation-guide.md`](translation-guide.md) —— 英译中术语。

## 状态

里程碑 M0 到 M6 已完成：外壳与约定、两种后端的媒体工具、来源与模型库、带规划器与续传的转写引擎、带导出的转写
稿查看器、跨窗口的说话人匹配，以及带端点规则的 API 密钥交换。

剩下的是发布准备，以及一件没有付费密钥就无法核实的事：一份超过上传上限的真实录音，端到端地对着 OpenAI 与
OpenRouter 跑通。其余一切都由测试套件验证，而它在没有密钥、没有网络、没有 FFmpeg 的情况下运行。见仓库根目录
的 `PLAN.md`。
