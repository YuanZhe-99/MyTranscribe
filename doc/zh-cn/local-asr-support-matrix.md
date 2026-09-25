# 本地模型支持矩阵

哪个本地模型在哪种设备的哪个处理器上运行、每条路线有多充分的文档说明它能工作，以及本项目是否测试过它。本页
随路线发布保持更新：每条验证记录、每条以未验证状态发布的路线，以及收到的每份来自别人硬件的诊断报告，都记在
这里。这些术语对用户意味着什么，见 [`features/local-models.md`](features/local-models.md)；自动如何使用它
们，见 [`algorithms/engine-routing.md`](algorithms/engine-routing.md)。

## 等级

调研给出的依据等级，在代码中表示为 `EvidenceLevel`：

| 等级 | 代码 | 含义 |
|---|---|---|
| **A** | `official` | 运行时或芯片厂商的文档涵盖该模型在这条路线上 |
| **B** | `community` | 存在可复现的第三方实现 |
| **E** | `experimental` | 存在通用后端，但这个模型 × 设备的组合没有展示过 |
| **U** | `none` | 什么也没找到 |

**在此测试过**是一项独立的事实：本项目在该类别的硬件上运行了 `PLAN.md` §7 的验收清单，并记录在下文。没有在
此测试过的路线照样发布，作为**未验证支持**：已经构建并由 CI 覆盖，在每台设备上的第一个任务之前先检查，在产
品中标明未测试，并且只有在等级为 A 或 B、且在检查中胜过 CPU 时才被自动使用。

## 按目标平台

调研于 2026-09-24。"计划"指明构建某条路线的里程碑；目前除基础（L0）之外什么都还不存在。

| 目标平台 | Whisper large-v3 / turbo | Parakeet TDT v3 | Qwen3-ASR 0.6B（1.7B） | 在此测试过 |
|---|---|---|---|---|
| **Windows x64** —— Intel / AMD / NVIDIA GPU；Intel NPU；AMD NPU | CPU **B**（whisper.cpp，L1）；GPU Vulkan **B**（L3）；Intel NPU **A**（OpenVINO GenAI，L7）；AMD NPU 编码器 **A**（Ryzen AI 300，L7） | CPU **B**（sherpa-onnx，L2）；GPU **B**（transcribe.cpp Vulkan，L3）；NPU **U** | CPU **B**（sherpa-onnx int8，L2；1.7B **E**）；GPU **B**（transcribe.cpp Vulkan，L3）；NPU **U** | **否** —— 未验证支持；CPU 路线也在 ARM64 机器上以仿真方式运行，这能检查代码路径，但检查不了速度 |
| **Windows ARM64** —— Snapdragon X Elite；X2 Elite；8cx Gen 3 | CPU **B**（L1）；GPU OpenCL **E**（L3）；NPU **A**，仅限 turbo（Qualcomm AI Hub 资源，ONNX Runtime QNN，L5a）；large-v3 NPU **U** | CPU **B**（L2）；GPU **U**；NPU **E** | CPU **B**（L2）；GPU **E**（llama.cpp 基于 OpenCL，L3）；NPU **U** | 在 8cx Gen 3（开发机）上**是**：CPU，以及在该代芯片上能运行的 OpenCL 和 QNN；X Elite 与 X2 Elite 未验证 |
| **Android** —— Snapdragon 8 Gen 3 / 8 Elite / 8 Elite Gen 5 | CPU **B**（L1）；GPU OpenCL **E**（L3）；NPU **A**，仅限 turbo（按 SoC 区分的资源，L5b） | CPU **B**（L2）；GPU **E**；NPU **E** | CPU **B**（L2）；GPU **E**；NPU **U** | **否** —— 未验证支持 |
| **Android** —— Google Tensor G3 / G4 / G5 | CPU **E**（L1）；GPU Vulkan **E**（L3，一项实验）；NPU **U** | CPU **E**（L2）；GPU **E**；NPU 不在计划中（Tensor SDK 已被放弃） | CPU **E**（L2）；GPU **E**；NPU **U** | 在 G5（Pixel 10）上**是**：CPU、Vulkan 实验；G3 与 G4 未验证 |
| **Android** —— MediaTek Dimensity、Samsung Exynos | CPU **E**（L1）；GPU Vulkan **E**；NPU **U** | CPU **E**（L2）；GPU **E**；NPU **U** | CPU **E**（L2）；GPU **E**；NPU **U** | **否** —— 未验证支持 |
| **macOS** —— Apple Silicon（Intel：仅 CPU） | CPU 与 Metal **B**（L1）；Core ML 编码器 **B**（L1）；WhisperKit **B**（可选，L4） | CPU **B**（L2）；Neural Engine **B**（FluidAudio，L4） | CPU **B**（L2）；Neural Engine **B/E**（FluidAudio，仅 0.6B，需通过质量门槛，L4） | 在 Apple Silicon（2024 款 Mac mini）上**是**；Intel Mac 未验证 |
| **iOS** —— A 系列 / M 系列 | CPU 与 Metal **B**（L1）；Core ML 编码器 **B**（L1） | CPU **B**（L2）；Neural Engine **B**（L4） | CPU **B**（L2）；Neural Engine **B/E**（L4） | 有 iPhone 可用时在 iPhone 上；否则由模拟器检查代码路径，设备端路线未验证 |
| **系统语音识别**（L6） | iOS/macOS 26+ 设备端 `SpeechAnalyzer` **A**；更低版本在区域设置支持时用设备端 `SFSpeechRecognizer` **A**；Android 设备端 **A**，文件输入 **E**；Windows 无 | | | Pixel 10 与 Mac |

## 验证记录

每条在本项目硬件上验证过的路线一条记录：设备、操作系统、驱动、运行时版本、模型包哈希、量化与解码设置、实时
率、首个结果的延迟、峰值内存，以及日期。

暂无。一条路线只有在 §7 的验收清单对它全部成立后才记录在这里，其中包括对一段真实录音逐行比对，这需要用户参与。

### 已测量、尚未验证：Windows ARM64，whisper.cpp CPU，large-v3-turbo（2026-09-25）

- **设备**：一台骁龙 8cx Gen 3 笔记本，8 核，32 GB；Windows 11 专业版 10.0.26200.9457。只用 CPU，因此不涉及驱动。
- **运行时**：whisper.cpp v1.9.4，来自本项目的 Windows ARM64 二进制集（`whisper-bin-v1.9.4-1`：ARMv8.2，带点积
  和 FP16，不用 OpenMP），绑定版本 `prebuilt1`。
- **模型包**：`ggml-large-v3-turbo.bin`，f16，SHA-256
  `1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69`；贪心解码，flash attention 关闭，8 个线程
  （当时的线程策略）。
- **录音**：一段 81.4 分钟的英文讲座，分为 9 个窗口。耗时 145.7 分钟，**实时率 1.79**；在 11 秒片段上的路线检查
  实时率为 2.53，并且通过。峰值内存 2.65 GB。每个窗口都在 CPU 上运行；没有回退。
- **与同一录音的 MAI-Transcribe-2 转写稿对比**：8,331 词对 6,809 词，词级一致率（1 − WER）为 36.9%。这个指标会
  把 Whisper 保留、而参照服务删掉的每个语气词和重复都算作差异，所以它本身并不说明质量有问题 —— 但也不算通过。
- **线程数**，large-v3-turbo 在检查片段上：4 → 实时率 2.43，6 → 1.89，7 → 1.91，8 → 3.04。上游自己的 ARM64 命令
  行构建（OpenMP，ARMv8.7）在同一片段上用 8 个线程的实时率是 4.75，所以慢的不是这个构建。引擎现在会留出两个核心。
- **说明什么**：f16 的 turbo 在这颗 CPU 上比实时慢。q5_0 模型包是能跟上实时的 CPU 路线候选，Adreno GPU 上的
  OpenCL（L3）则是加速路线的候选。这条路线没有加入"在此测试过"表。

## 未验证的路线

未在其硬件类别上测试就发布的路线，附上原因以及约束它的条件。

所有发布的路线都在这里，因为还没有一条有验证记录（用户在 2026-09-25 决定不安排真机测试）。每条路线都以同样的
方式把关：第一个任务之前在设备上做检查、运行中标记，以及回退策略（决定 D20）。

| 路线 | 自 | 等级 | 未验证的原因 | 在这里运行过什么 |
|---|---|---|---|---|
| whisper.cpp CPU —— Whisper、Parakeet | 0.3.0、0.3.1 | **B**（Android 上为 **E**） | 任何类别上都没有验证记录 | 8cx Gen 3：JFK 片段端到端；81 分钟讲座的 turbo 转写，数据见上 |
| sherpa-onnx CPU —— Qwen3-ASR | 0.3.1 | **B**（Android 上为 **E**） | 同上；不支持 iOS | 8cx Gen 3：JFK 片段端到端 |
| Metal —— Whisper（Parakeet 为 **E**） | 0.3.0 | **B** | 没有 Mac 或 iPhone 上的测试 | 无 |
| Vulkan —— Windows x64 | 0.3.2 | **B** | 没有 x64 机器 | 无 |
| Vulkan —— Android arm64 | 0.3.2 | **E** | 没有手机上的测试；需要 Android 9 | 无 |
| OpenCL —— Windows ARM64 与 Android arm64 上的 Adreno | 0.3.2 | **E** | 8cx Gen 3 没有 ggml 能用的 OpenCL 驱动（微软的 OpenCLOn12 缺少 FP16，设备被丢弃） | 后端能加载并丢弃该设备，符合预期 |

**E** 路线只有在用户选择、且它在该设备上的检查通过后才会运行。

## 来自其他硬件的报告

拥有本项目所没有的硬件的人发来的诊断报告，连同日期记录下来。一份报告可以提高一条路线的依据等级；它永远不会
让这条路线变成在此测试过。

暂无。
