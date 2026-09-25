# 平台说明

生成并配置了四个平台：Android、Windows、iOS 与 macOS。不面向 Linux 与 Web。

| 项目 | 取值 |
|---|---|
| Android 命名空间与应用 id | `com.yuanzhe.my_transcribe` |
| iOS 与 macOS bundle id | `com.yuanzhe.myTranscribe` |
| MSIX 标识 | `com.yuanzhe.mytranscribe` |
| 各处显示名称 | `MyTranscribe!!!!!` |
| 发布者 | `yuanzhe` |

## FFmpeg：两种后端，一个接口

切分录音需要 FFmpeg，而应用获得它的方式因平台而异。两种后端实现同一个 `MediaToolkit` 接口，由
`lib/shared/utils/platform_capabilities.dart` 决定调用哪一个。

| 平台 | 后端 | 方式 |
|---|---|---|
| Android、iOS、macOS | `embedded` | FFmpeg 库链接进应用，在进程内运行。在无法派生子进程的沙盒平台上，这是唯一可行的路线。 |
| Windows | `externalBinaries` | `ffmpeg.exe` 与 `ffprobe.exe` 是独立可执行文件，应用去找它们，或提供下载。 |

**Windows 为什么不一样。** 在维护中的 FFmpeg 插件只发布 x86_64 的 Windows 预编译库，而本项目的开发机是
Windows on **ARM64**。声明支持 Windows 的插件会被拉进 Windows 构建，并在配置阶段因为找不到并不存在的
ARM64 归档而失败。Flutter 没有应用级的"在某平台排除某插件"，而 `generated_plugins.cmake` 每次构建都会重新
生成，因此改它不会留住。于是该插件被**内置**到 `packages/ffmpeg_kit_flutter_new_audio/`，是一份删去
Windows 与 Linux 平台条目的精简副本，按 path 依赖使用。旁边的 `VENDORED.md` 记录了上游版本以及究竟删了
什么；升级它意味着重新内置，而不是改一个版本号。应用的 `analysis_options.yaml` 排除了这份副本，因为它的
代码风格属于上游，不该由我们去纠正。

在添加任何带原生代码的插件之前，有两个后果值得知道。其一，在 `android.builtInKotlin=false` 的前提下，每个
插件必须自行应用 Kotlin Gradle Plugin；构建会打印一条警告列出这样做的插件，今天是内置的 FFmpeg 副本、
`file_picker`、`package_info_plus` 与 `wakelock_plus`。其二，Android 与 Apple 的构建会**在构建时下载原生
归档**，因此离线的机器无法从干净状态构建这些目标。

Windows 上二进制的完整查找顺序：用户在设置中指定的路径，然后是应用自己的 support 目录（下载助手放置的位
置），然后是可执行文件所在目录及其 `bin/` 子目录，然后是工作目录，最后是 `PATH` 的每一项。在 Windows 上，
候选项是通过检查文件是否存在来探测的，而不是运行它，因为运行一个可执行文件来测试会闪出一个控制台窗口。

下载助手会按主机架构把已发布的构建取到应用 support 目录，只解出那两个可执行文件，并记录下载了什么。它之所
以存在，是因为 Windows 没有一台机器上必然已有的包管理器。Linux 被有意排除在助手之外：每个发行版都提供
FFmpeg，在那里下载一个来路不同的二进制文件，还不如在错误信息里给出一行安装命令。

子进程以带管道的方式附加启动，Dart 在 Windows 上这样创建不会带控制台窗口。进度从 FFmpeg 自身在 stdout 上
的机器可读进度流读取；stderr 的最后若干行会保留，以便失败时能说出出了什么问题。

## Android

从兄弟应用继承而来、且是承重的 Gradle 状态：

- AGP 9.1.1、Kotlin Gradle Plugin 2.2.20，在 `settings.gradle.kts` 中声明
- `android.builtInKotlin=false` —— 应用自己不应用 KGP，但若干插件仍会应用，并从那里解析版本。**加入本应用
  的任何插件都必须自行应用 KGP**；`file_picker` 正是因此被固定到精确版本，`pubspec.yaml` 里的固定处写有
  这条说明。
- `android.newDsl=false`
- Java 17，启用核心库脱糖；Kotlin 的 `jvmTarget` 显式设为 17，否则 Kotlin 会默认使用当前运行 JDK 的目标，
  构建会以 JVM 目标不一致失败。
- `minSdk = flutter.minSdkVersion`（24），这也正是内置 FFmpeg 库所要求的。

发布签名在 `android/key.properties` 存在时读取它，不存在时回落到 debug 配置，因此全新克隆无需任何机密即可
构建。`key.properties` 与 `*.jks` 已被 gitignore，永不提交。

**权限只有 `INTERNET`，此外没有。** 录音通过系统文件选择器进入，它只授予用户所选的那一个文件的访问权，因此
不需要存储权限。应用不录音，也不请求麦克风权限。

`android:usesCleartextTraffic="true"` —— 家庭网络里的 WebDAV 服务器，以及用户自建的转写服务器，通常都是明文
HTTP。即便如此，除非是私有地址，API Key 仍然不会发往明文 HTTP 端点；见
[`features/secure-secrets-sync.md`](features/secure-secrets-sync.md)。

`android:configChanges` 带有 `screenLayout|screenSize|smallestScreenSize|density`，因此折叠或展开只会改变窗口
尺寸而不重建 Activity。见 [`adaptive-layout.md`](adaptive-layout.md)。

## iOS

- 部署目标 **14.0**，从 Flutter 默认值上调，因为 FFmpeg 库有此要求。
- `UIFileSharingEnabled` 与 `LSSupportsOpeningDocumentsInPlace` 均为真，这使应用的目录在"文件"中可见。没有
  它们，一份完成的转写稿就只能通过分享面板取到。
- App Transport Security 允许本地网络与任意加载，与 Android 的明文标志相对应，理由相同。这是提交 App Store
  之前需要重新审视的决定：只允许本地网络更容易说明理由，但那会让通过 Tailscale 地址访问的 WebDAV 服务器无法
  使用。
- 没有麦克风或语音识别的用途说明字符串，因为应用两者都不做。

## macOS

沙盒运行，debug 与 release 两套配置各有三项权限：

- `app-sandbox`
- `network.client` —— 访问转写服务与用户的 WebDAV 服务器
- `files.user-selected.read-write` —— 用户选择一份录音，并选择转写稿保存到哪里；沙盒恰好授予这些文件的访问权

在进程内运行 FFmpeg 而不是作为子进程，避免了派生可执行文件会带来的沙盒问题。

## Windows

runner 的资源与窗口标题都改名为 `MyTranscribe!!!!!`。MSIX 的打包元数据在 `pubspec.yaml`，安装程序的在
`installer.iss`；两者都各带一份版本号，`AGENTS.md` 列出了版本号出现的每一处。

今天在 ARM64 上构建无需额外工具。发布 x86_64 预编译 Windows 二进制的插件则不行 —— 这正是上面 FFmpeg 那套
安排要满足的约束；在添加任何带原生 Windows 代码的插件之前先核对这一点。

音频播放器是这条约束第二次决定依赖选择的地方。选用 `audioplayers` 而不是 `just_audio` 或 `media_kit`，是
因为它的 Windows 后端是从源码编译的 Media Foundation，可以在 ARM64 上构建；另外两个附带只有 x86_64 的
libmpv，会以与 FFmpeg 插件相同的方式失败。这一点是在 ARM64 机器上真正跑一次 `flutter build windows` 验证
的，不是从文档里读来的。

## 本地模型

下载的模型放在哪里因平台而异，由 `platform_capabilities.dart` 决定（`modelsLiveInCachesDirectory`）：

| 平台 | `models/` 在哪里 | 原因 |
|---|---|---|
| iOS、macOS | 应用的缓存目录 | iCloud 备份和 Time Machine 都不包含它；模型是可以重新下载的缓存，而手机备份里塞进数 GB 模型只会招来一张工单。空间不足时系统可能清掉它，此时模型库会把该模型显示为未下载。把文件夹标记为排除不需要任何原生代码。 |
| Android、Windows | 应用目录下的 `models/` | 自定义存储路径会把模型一并带走。在 Android 上，下面的备份规则把 `models/` 排除在自动备份和设备迁移之外。 |

桌面用户可以用 `modelsPath` 把模型挪到任何地方；改动它时不会复制任何东西。

一个平台到底能有哪些引擎适配器，也在那里决定（`localEngineBackends`）：whisper.cpp 与 sherpa-onnx 所有平台
都有；Swift 插件在 iOS 与 macOS 上；Android 的识别器在 Android 上；带 Qualcomm QNN 提供程序的 ONNX Runtime
在 Windows 与 Android 上。某个构建是否真的包含其中之一，由引擎注册表回答。`hasSystemSpeechRecognizer` 在
Windows 上为 false，因为它没有文件转写 API，所以回退设置在那里是不出现，而不是被禁用。

### whisper.cpp

whisper.cpp 是位于 `packages/whisper.cpp` 的 git 子模块，固定在一个发布标签（v1.9.4）上，使用公开的上游 URL
—— 与 `myapps_data` 不同，这里用绝对 URL 是对的，因为上游不在本项目的任何一个远端里。`packages/local_asr_whisper`
对它做了封装：一个构建钩子（`hook/build.dart`）针对 Flutter 工具正在构建的目标在子模块上运行 CMake，一个小
小的 C 垫片（`src/lasr_whisper.c`）为 Dart 一侧提供只用普通类型的稳定 ABI，因此没有任何 Dart 代码去镜像
whisper.cpp 的结构体。没有可用的 pub 包：现有的两个要么只附带 x86_64 的 Windows 二进制文件，要么根本不支持
桌面。

| 目标 | 编译器 | CPU 代码 | 其他后端 |
|---|---|---|---|
| Windows ARM64 | 来自 Visual Studio LLVM 组件的 clang（或独立的 LLVM），在 Visual Studio 的开发者环境中 | 一个 ARMv8.2 的库，带点积和 FP16，每款 Windows 11 ARM 处理器都具备 —— 固定的 ggml 没有可在运行时挑选的 Windows ARM64 变体列表 | —（OpenCL 在 L3） |
| Windows x64 | 同一个 clang | 构建所有 x86 变体，运行时加载最好的那个 | —（Vulkan 在 L3） |
| Android arm64、x86_64 | NDK 的 clang 与 CMake 工具链文件 | 构建所有 Android 变体，运行时加载最好的那个 | —（OpenCL 在 L3） |
| macOS、iOS | Xcode 的 clang | 该架构的默认设置 | Metal；Core ML 编码器放在模型旁边时会使用它 |
| Linux x64 | 主机编译器 | 默认设置 | —（CI 中运行主机 `flutter test` 的环境） |

Windows 上不使用 `cl.exe`：它缺少 ggml 的 ARM 代码所需的 FP16 内建函数，而 L3 的 OpenCL 后端根本不支持它。x64 上
不兼容指针类型的诊断保持为警告：ggml 的 SSE4.2 变体把块指针传给 `_mm_prefetch`，否则较新的 clang 会因此中止。ggml 自带的 ccache 包装在所有平台都关闭：
ccache 在构建钩子那种精简的环境里会失败，而钩子的构建目录本来就是增量的。
32 位 Android 不构建 —— 大的 Whisper 模型装不进 32 位地址空间 —— 引擎在那里报告自己未构建。

在运行时挑选 CPU 代码的地方，ggml 把它的各个后端作为单独的库加载，而垫片从它自己被加载的那个文件夹加载它
们：在 Android 上那个文件夹不是可执行文件所在的文件夹，而在 `flutter test` 运行中其他文件夹也都不是。这就是
Android 应用用**旧式打包**（`android/app/build.gradle.kts` 中的 `useLegacyPackaging`）构建的原因：原生库被
解压到应用的库文件夹，而不是从 APK 内部读取 —— 在那里无法列出文件夹内容。Android 的备份规则
（`res/xml/backup_rules.xml` 与 `res/xml/data_extraction_rules.xml`）把 `models/` 排除在自动备份和设备迁移
之外。

工具：先用 PATH 中的 CMake 和 Ninja，然后在 Windows 上用 Visual Studio 自带的副本，在 Android 上用 Android
SDK 的副本；在 macOS 或 Linux 上没有 Ninja 时，钩子回退到 Makefiles。CMake 构建目录位于 `.dart_tool/` 下钩
子的共享输出中，因此第二次构建是增量的。
