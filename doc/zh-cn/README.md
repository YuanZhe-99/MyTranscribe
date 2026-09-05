# MyTranscribe!!!!! 文档（概念）

> **本目录尚未完成翻译。** `doc/en-us/` 是权威版本，中文镜像按 `PLAN.md` 的 M7 里程碑补齐。
> 在补齐之前，请阅读 [`../en-us/README.md`](../en-us/README.md)。
>
> 这不是可以静悄悄接受的现状：`AGENTS.md` 要求两个语言目录逐文件、逐标题一一对应。此处记录下来，
> 是为了让缺口是**已知的**，而不是被忽略的。

**MyTranscribe!!!!!**（所有面向用户的名称都带五个感叹号）把录音转成文字，使用的是用户自己配置的转写
服务。文件太大无法一次上传时，它用 FFmpeg 切成互相重叠的分段，中断后可以继续，再把各段拼回一份完整
的转写稿；模型支持时还会标出谁在说话。配置通过共享的 `myapps_data` 引擎同步。

- **作者 / 包名：** `yuanzhe`、`com.yuanzhe.my_transcribe`
- **许可证：** GPL-3.0
- **平台：** Android、Windows、iOS、macOS（不支持 Linux 与 Web）
- **框架：** Flutter，Dart SDK `^3.11.3`

## 待翻译的页面

| 英文页面 | 内容 |
|---|---|
| `architecture.md` | 应用骨架、状态管理、导航、本地化、目录结构与核心规则 |
| `data-formats.md` | 应用写入的每个文件、哪些会同步、各自的结构 |
| `adaptive-layout.md` | 何时分栏、导航放在哪里、能放几列，以及每个页面用哪条规则 |
| `sync.md` | WebDAV 同步：数据模块、合并、冲突，以及单独的 API 密钥交换 |
| `backup-restore.md` | 本地备份与 ZIP 导入导出 |
| `platform-notes.md` | 各平台的 FFmpeg 方案、Android 构建状态、Apple 权限、Windows ARM64 |
| `ci-cd.md` | 验证命令、构建命令、全新克隆的步骤 |
| `version-history.md` | 逐版本的变更与原因 |
| `translation-guide.md` | 英中术语表 |
| `features/*.md` | 转写任务、来源库、转写稿查看器、说话人、媒体工具、密钥同步、数据页面 |
| `algorithms/*.md` | 分段规划、重叠合并、说话人统一、安全端点判定 |
| `functions/INDEX.md` | 逐文件的函数说明索引 |
