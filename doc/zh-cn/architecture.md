# 架构

## 形态

MyTranscribe 是一个三标签页的 Flutter 应用，没有自己的后端。它所做的一切，要么是本地文件操作，要么
是向用户自己配置的服务器发请求。

```
lib/
  main.dart                 启动服务、上次所在标签页、runApp
  app/                      应用外壳：MaterialApp.router、主题、路由、数据模块
  features/<feature>/       models/ services/ views/ widgets/
  shared/                   providers/ services/ utils/ views/ widgets/
  l10n/                     ARB 词条与其生成的 Dart
packages/myapps_data/       共享的同步、备份与 ZIP 引擎（git 子模块）
```

`features/` 按业务域平铺，而不按分层划分：没有 data/domain/presentation 的切分。一个功能自己拥有它的
模型、服务和页面；两个功能都需要的东西才移到 `shared/`。

现有功能为 `jobs`（转写）、`providers`（来源与模型）、`transcript`（阅读结果）、`media`（FFmpeg）、
`secrets`（API Key）与 `settings`。

## 核心架构规则

- **状态管理使用 `flutter_riverpod` 1.x** —— UI 会修改的数据用 `StateNotifierProvider`，依赖用普通的
  `Provider`，一次性读取用 `FutureProvider`。不使用 Provider 和 Bloc，也不应引入。
- **路由使用 `go_router`，只有一个 `ShellRoute`。** 三个标签页在其中。新建任务和阅读转写稿是外壳
  **之外**的整窗路由：这两件事都是针对某一份录音做的，做完就离开，而转写稿需要整个窗口。放在外壳之外
  还意味着它们没有导航栏需要扣除，而布局规则正依赖这一点。`buildAppRouter` 接收初始位置，根部件用
  `late final` 持有路由器，这样主题或语言变化不会重建它、把导航历史清空。
- **没有依赖注入容器。** Riverpod 的 provider 加上静态服务单例就是全部。
- **通过 `flex_color_scheme` 使用 Material 3**，种子为 `FlexScheme.tealM3`。配色是系列各应用一眼可辨
  的依据。
- **模型全部手写。** 不做代码生成。每个模型都有 `fromJson` 与 `toJson`，并带一个 `extraJson`，这样新
  版本写入的字段被旧版本读出再写回时不会丢失。
- **持久化是应用目录下带缩进的 JSON 文件。** 没有数据库，也不用 `shared_preferences`。缩进是有意义
  的：同步在合并前会比较原始字符串，如果某个引擎写出与存储中枢不同的格式，每个未改动的文件都会被视为
  已改动而反复上传。
- **HTTP 使用 `package:http`。** 共享包也用它，所以 WebDAV 传输与转写请求共用一套栈。
- **只有一个文件按平台分支**：`lib/shared/utils/platform_capabilities.dart`，且它读取
  `defaultTargetPlatform` 而非 `dart:io` 的 `Platform`，这样在项目实际拥有的这一台主机上，控件测试也能
  走到任意分支。
- **只有一个文件持有布局数字**：`lib/shared/utils/adaptive_layout.dart`，它不从 Flutter 引入任何东西，
  因此可以作为纯函数测试。控件文件里出现宽度数值比较即为缺陷。

## 四种数据

这个区分贯穿整个应用，值得说明一次：

| 种类 | 例子 | 是否同步 | 是否进备份与 ZIP |
|---|---|---|---|
| 配置 | 来源、模型、默认值 | 是，作为一个数据模块 | 是 |
| 转写记录 | 已完成转写的记录和文本 | 是，作为一个由 `jobs/` 投影出来的数据模块 | 是 |
| 机密 | API Key | 仅在安全端点下，通过单独的交换流程 | 否 |
| 录音与音频 | 原始文件、分段音频、转换后的副本 | 否 —— 只有转换后的副本，且仅通过需要主动开启的旁路通道 | 否 |

这些排除是**结构性**的，不是过滤出来的：同步、备份与 ZIP 引擎只会接触
`lib/app/data_modules.dart` 中注册表里的文件名，而密钥文件和任务目录都不在其中。把其中任何一个加入注册
表，都会悄悄开始上传它。

转写的**文本**仍然能够传输：每个任务文件夹里较小的那一半 —— 记录和转写稿，绝不包括音频 —— 会在同步前被
投影进一个属于它自己的模块文件，同步后再写回 `jobs/`。转换后的回放副本只在明确开启的设备上传输，走的是
与密钥相同的应用层旁路通道。参见 [`data-formats.md`](data-formats.md) 和 [`sync.md`](sync.md)。

## 共享包

`myapps_data` 是一个 Flutter 包，以 git 子模块形式嵌入在 `packages/myapps_data`，按 path 依赖使用。它
提供 WebDAV 传输与同步引擎、上传锁、通用的三路记录合并、原子写入、存储迁移、备份引擎和 ZIP 传输引擎。

应用在两个接缝处与它相接：

- `lib/app/data_modules.dart` —— 一个 `StorageAdapter` 实现和 `ModuleRegistry`。该文件是数据文件名、
  模块 id、远端路径与归档前缀的唯一事实来源；其他任何地方都不得写死这些值。
- `lib/shared/services/webdav_service.dart`、`backup_service.dart`、`import_export_service.dart` 与
  `auto_sync_service.dart` —— 四个薄外观层，其公开形态与兄弟应用一致，因此页面可以在应用之间原样移植。
  行为改动属于共享包，不属于外观层。

使用方不得直接引入 `package:myapps_data/src/...`；桶文件才是 API。

## 存储

`lib/shared/services/transcribe_storage.dart` 是存储中枢：唯一知道数据放在哪里的地方。所有文件访问都经
由 `getAppDir()` 解析，它会遵守自定义存储路径；所有设置写入都经由 `saveSettings()`，它会通知自动同步。
设备本地偏好是 `storage_config.json` 之上的强类型访问器，默认值以**缺省键**的形式保存，这样后续版本改变
某个默认值时，对所有从未动过该设置的人都会生效。

## 启动

`main()` 在首帧之前按顺序做四件事：启动每日备份检查（发出即不管）、启动自动同步的生命周期观察者、读取
上次所在标签页以便应用回到用户离开的位置，然后 `runApp`。这里没有任何网络访问 —— 在用户于设置中配置同步
之前，这两个服务都不做事。

`DevicePreview` 已编译进来，但只在 debug 构建中启用；在那里它是试验
[`adaptive-layout.md`](adaptive-layout.md) 中折叠屏尺寸最快的办法。

## 本地化

使用 Flutter 原生的 `gen-l10n`，ARB 文件放在 `lib/l10n/`。`app_en.arb` 是模板，`app_zh.arb` 与
`app_zh_TW.arb` 逐键对应，`test/l10n_arb_test.dart` 会在其中之一不对应时失败。生成的文件会提交。两份中文
词条都由人工维护：台湾用法与大陆的差别不只在字形，也在词汇。

`lib/app/locale_resolution.dart` 依据书写系统子标签判断繁简，因为 Flutter 自带的语言与地区匹配会把
`zh-Hant-HK` 送到简体。

## 测试

纯粹的规则按纯函数测试；渲染的页面按具名设备的逻辑像素尺寸测试。控件测试以简体中文运行：`flutter_test`
的默认字体把每个字形都渲染成一个全角方块，这会让拉丁字母标签膨胀到实际宽度的约两倍半，在生产中本来宽松
的宽度上报告溢出。而 CJK 字形本来就是方的，因此中文环境量到的才是生产布局。
