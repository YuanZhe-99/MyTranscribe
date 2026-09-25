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

应用构建不编译任何原生代码（`PLAN.md` 的决定 D21）。`packages/local_asr_whisper` 里有一份清单
`native/binaries.json`，按 URL 和 SHA-256 为每个目标固定一个压缩包。它的构建钩子下载正在构建的目标所对应的
压缩包，核对哈希，把列出的库解压到 `.dart_tool/` 下它的共享缓存中，再作为代码资源交给 Flutter 工具。哈希不
符时构建失败，而不是打包一个不同的二进制文件。所有压缩包都来自 whisper.cpp v1.9.4（提交 `927cfce3`），并且每个都在
Whisper 的库旁边带着 whisper.cpp 自带的 Parakeet 运行时（`parakeet`；在 Apple 上位于框架二进制文件内），Parakeet
引擎用它自己生成的绑定（`parakeet_bindings.g.dart`，决定 D22）来调用它。我们自己的压缩包是 `whisper-bin-v1.9.4-2`
这个发布，它是第一个包含 Parakeet 的。

| 目标 | 压缩包 | CPU 代码 | 其他后端 |
|---|---|---|---|
| Windows x64 | 上游的 `whisper-bin-x64.zip`（发布资源 `b5130`） | 所有 x86 变体，运行时加载最好的那个 | —（Vulkan 在 L3） |
| Windows ARM64 | 我们的：`whisper-bin-v1.9.4-1` 发布中的 `whisper-win-arm64.zip` | 一个 ARMv8.2 的库，带点积和 FP16，不用 OpenMP | —（OpenCL 在 L3） |
| Android arm64-v8a、x86_64 | 我们的：同一发布中的 `whisper-android-<abi>.zip` | 所有 Android 变体，运行时加载最好的那个 | —（OpenCL 在 L3） |
| macOS、iOS 及其模拟器 | 上游的 `whisper-b5130-xcframework.zip`：取匹配切片的框架二进制，若是通用二进制则只取正在构建的那个架构 | 链接在内 | Metal；Core ML 编码器放在模型旁边时会使用它 |
| Linux x64 | 上游的 `whisper-bin-ubuntu-x64.tar.gz`，各库以其 soname 命名 | 所有 x86 变体 | —（仅是 CI 中运行主机 `flutter test` 的环境） |

其中两个是我们自己的，因为上游的不合格：它的 Windows ARM64 压缩包需要 Visual Studio `debug_nonredist` 文件夹
里的 `libomp140.aarch64.dll`，而那是不能分发的，并且它以 ARMv8.7 为目标，较旧的骁龙笔记本跑不了；它也没有为
Android 发布任何东西。`.github/workflows/native-prebuild.yml` 从同一个上游提交构建这两者，每个版本一次
（见 `ci-cd.md`）。32 位 Android 没有条目 —— 大的 Whisper 模型装不进 32 位地址空间 —— 引擎在那里报告自己未构建。

Dart 一侧直接绑定这些库，不再有 C 垫片。`third_party/whisper.cpp/include/` 存放固定版本的头文件和许可证，
`dart run tool/ffigen.dart` 生成 `lib/src/whisper_bindings.g.dart`（绑定到 `whisper` 代码资源）和
`lib/src/ggml_bindings.g.dart`（在它旁边的 ggml 库中查找符号；在 Apple 上 ggml 链接在 whisper 自己的二进制
文件里，就在那里查找）。参数结构体按值传递，因此引擎在加载时会通过生成的结构体读回 whisper.cpp 的默认参数，
并与其源码记载的值比较；不一致说明库与绑定对不上，引擎就拒绝这个库，而不是去调用它。取消与进度是在引擎
isolate 中创建的回调，这是允许的，因为 whisper.cpp 在调用 `whisper_full` 的那个线程上调用它们。ggml 的两个
枚举被绑定为 32 位整数，这些目标所用的每个编译器都给它们这个大小。内存保护所用的可用内存数值通过 FFI 从操作
系统读取。引擎在手机上最多用四个线程；在桌面上留出两个核心（四核及以下留出一个），最多八个，因为
ggml 的线程池在等待时会空转 —— 在 8 核的开发机上，八个线程比六个慢 60%（`localEngineThreads`）。

在运行时挑选 CPU 代码的地方，ggml 把各个变体作为单独的库，从 whisper 库被加载的那个文件夹加载，而这个文件夹
由 Dart 一侧向操作系统询问得到：在 Android 上那个文件夹不是可执行文件所在的文件夹，而在 `flutter test` 运行中
其他文件夹也都不是。这就是 Android 应用用**旧式打包**（`android/app/build.gradle.kts` 中的
`useLegacyPackaging`）构建的原因：原生库被解压到应用的库文件夹，而不是从 APK 内部读取 —— 在那里无法列出文件夹
内容。Android 的备份规则（`res/xml/backup_rules.xml` 与 `res/xml/data_extraction_rules.xml`）把 `models/`
排除在自动备份和设备迁移之外。

Windows 上的库链接 Visual C++ 运行库（`MSVCP140.dll`、`VCRUNTIME140.dll`，x64 上还有 `VCRUNTIME140_1.dll` 和
OpenMP 运行库 `VCOMP140.DLL`）。本应用本来就依赖这个运行库 —— 它自己的可执行文件和各插件都链接
`MSVCP140.dll` 与 `VCRUNTIME140.dll`，安装程序也不附带任何运行库 —— 因此 whisper.cpp 只在 x64 上多出一个
`VCOMP140.DLL`，而它由同一个 Visual C++ 可再发行组件包安装。

升级到更新的上游版本会一次涉及以上全部：用新标签运行 `native-prebuild.yml`，把 `native/binaries.json` 指向新的
压缩包及其哈希，把新的头文件复制到 `third_party/`，重新生成绑定，默认值有变时更新布局检查，并提高
`whisper_cpp_engine.dart` 中的 `_bindingsVersion`，让每台设备重新检查它的路线。

### sherpa-onnx

Qwen3-ASR 运行在 sherpa-onnx 上（决定 D22），通过 `packages/local_asr_sherpa`，其构建方式与 `local_asr_whisper`
完全相同：`native/binaries.json` 按 URL 与 SHA-256 固定 sherpa-onnx v1.13.8 自己的发布资源，钩子下载并打包它们，
`third_party/sherpa-onnx/c-api.h` 与许可证（Apache-2.0）一起放在仓库里，`dart run tool/ffigen.dart` 生成
`lib/src/sherpa_bindings.g.dart`。不使用 pub 包 `sherpa_onnx`：1.13.8 不带 Windows ARM64 的 DLL，这台机器根本
运行不了它。

| 目标 | 压缩包 | 库 |
|---|---|---|
| Windows x64、ARM64 | `sherpa-onnx-v1.13.8-win-{x64,arm64}-shared-MD-Release-no-tts-lib.tar.bz2` | `sherpa-onnx-c-api.dll`、`onnxruntime.dll`、`onnxruntime_providers_shared.dll` |
| Android arm64-v8a、x86_64 | `sherpa-onnx-1.13.8.aar` 中的 `jni/<abi>/` 文件夹 | `libsherpa-onnx-c-api.so`、`libonnxruntime.so` |
| macOS | `sherpa-onnx-v1.13.8-osx-universal2-shared-no-tts-lib.tar.bz2`，每个架构取一个切片 | `libsherpa-onnx-c-api.dylib`、`libonnxruntime.dylib` |
| Linux x64 | `sherpa-onnx-v1.13.8-linux-x64-shared-no-tts-lib.tar.bz2` | `libsherpa-onnx-c-api.so`、`libonnxruntime.so` |
| iOS | 暂无 —— sherpa-onnx 没有为它发布动态库；引擎报告自己未构建 | |

C API 按指针接收配置，没有能读回默认值的函数，因此防止布局不匹配的手段是版本：库报告的版本必须恰好是
`1.13.8`，否则不使用它。`onnxruntime.dll` 还链接 `MSVCP140_1.dll`，它属于同一个 Visual C++ 可再发行组件包。
Android 的压缩包是所有目标里最大的下载（48 MiB），由钩子下载一次。
