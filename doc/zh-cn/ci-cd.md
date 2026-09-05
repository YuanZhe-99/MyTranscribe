# 构建与验证

## 远端

| 远端 | 位置 | 用途 |
|---|---|---|
| `origin` | 一台私有的 Gitea 实例 | 开发；每次推送先到这里 |
| `github` | `github.com/YuanZhe-99/MyTranscribe` | 公开镜像，也是唯一跑 CI 的一个 |

两者携带同一个 `main` 与同一批标签。先推 `origin`：没有经过本地关卡的提交，没有理由先公开。

## 持续集成

`.github/workflows/build.yml` 在 GitHub 上运行：每次推送到 `main`、每个 pull request，以及在 Actions 页
手动触发时。Gitea 没有 runner，因此推到那里的提交不会被任何东西检查。

| 任务 | Runner | 产出 |
|---|---|---|
| `android` | `ubuntu-latest` | analyze、完整测试套件、一个 APK 和一个 AAB |
| `windows-x64` | `windows-latest` | 一个 Inno Setup 安装程序 |
| `windows-arm64` | `windows-11-arm` | 一个 Inno Setup 安装程序 |
| `ios` | `macos-latest` | 一个未签名的侧载 IPA |
| `macos` | `macos-latest` | 一个 DMG |
| `release` | `ubuntu-latest` | 仅在 `v*` 标签上：把以上全部做成一个 GitHub Release |

**验证关卡仍然在本地。** CI 是关于本机没有的四个平台的第二意见，不是提交前不跑 `flutter analyze` 与
`flutter test` 的理由。本地通过而那边失败，几乎总是一个值得细读的平台特有问题。

关于这些任务，有三件事值得知道：

- **Android 发布签名是可选的。** 只有当仓库配置了密钥库机密（`KEYSTORE_BASE64`、`STORE_PASSWORD`、
  `KEY_ALIAS`、`KEY_PASSWORD`）时，该任务才会写出 `android/key.properties`。没有它们时，Gradle 配置会像本
  地构建一样回落到 debug 密钥，因此 APK 能安装，但不是可以发到商店的东西。
- **Ubuntu runner 自带 FFmpeg**，因此 `test/media_toolkit_live_test.dart` 不再自行跳过，而是对着一个真实
  的二进制来检验外部可执行文件后端。那是没有 FFmpeg 的主机唯一检查不到的媒体层部分。它体积较大的下载仍然
  留在 `--dart-define=live_download` 之后。
- **ARM64 任务使用 stable**，这一点与兄弟应用不同，它们是从 Flutter master 构建的。写它们的工作流时，
  stable 还没有 ARM64 的 Windows 引擎；3.44.2 已经提供 `windows-arm64-release`，而本项目正是在
  Windows on ARM64 上、针对这个版本开发的。固定 stable 还意味着每次运行产出同一个 `flutter_windows.dll`，
  于是 Defender 的云端信誉是累积在一个哈希上，而不是每次构建都换一个陌生的。

CI 不构建 MSIX：打包它需要签名证书，而本仓库没有。要产出它，仍然是在本地运行 `dart run msix:create`。

## 全新克隆

```bash
git clone git@github.com:YuanZhe-99/MyTranscribe.git     # 或使用 Gitea 远端
cd MyTranscribe
git submodule update --init          # myapps_data 是子模块内的 path 依赖
flutter pub get
flutter gen-l10n
```

跳过子模块那一步会让 `flutter pub get` 失败：`myapps_data` 是从 `packages/myapps_data` 解析的，而在子模块
检出之前那里是空的。

子模块的 URL 是**相对**的 —— `../MyApps-DATA.git` —— 因此它按你克隆自哪个远端来解析。从 GitHub 克隆会指向
`github.com/YuanZhe-99/MyApps-DATA`，从 Gitea 克隆会指向 Gitea 上的副本，两者都不必知道对方存在。两边都必
须带有本仓库所固定的那个标签；今天是 `v1.0.2`，且指向同一个提交。

## 验证

```bash
flutter analyze                      # 必须零问题
flutter test
```

两者在任何提交前都必须通过。改动范围窄时，运行最窄的有意义子集：

```bash
flutter test test/adaptive_layout_test.dart test/shell_nav_ui_test.dart   # 布局相关
flutter test test/settings_merge_test.dart test/data_modules_test.dart    # 同步或数据相关
flutter test test/l10n_arb_test.dart                                      # 改过 ARB 之后
```

只要改动了 ARB 文件，就必须重新运行 `flutter gen-l10n` 并提交其输出；生成的文件是被跟踪的。

## 真机测试

`test/` 在主机上运行，覆盖了几乎所有内容。有一个问题它回答不了：链接进 Android、iOS 与 macOS 构建的 FFmpeg
库是否真的能加载并运行 —— 原生归档是在构建时取得的，架构不对会在第一次真正调用时失败，而不是在构建时。
`integration_test/` 就是为此存在的：

```bash
flutter devices
flutter test integration_test/media_toolkit_test.dart -d <device id>
```

改动 `lib/features/media/` 中任何内容之后，或重新内置 FFmpeg 包之后，都要运行它。见
`integration_test/README.md`。

桌面端的对应物是 `test/media_toolkit_live_test.dart`，未安装 FFmpeg 时它会自行跳过，并把体积较大的下载放在
一个开关之后：

```bash
flutter test test/media_toolkit_live_test.dart
flutter test test/media_toolkit_live_test.dart --dart-define=live_download=true
```

## 运行

```bash
flutter run -d windows
flutter run -d macos
flutter run -d <android device id>
```

`flutter devices` 列出已连接的设备。在 debug 构建中 `DevicePreview` 是启用的，这是在没有折叠屏的情况下查看
[`adaptive-layout.md`](adaptive-layout.md) 中折叠尺寸最快的办法。

在 Windows 与 Linux 上，除了原样上传一个小文件之外，任何操作都需要 `ffmpeg` 与 `ffprobe`；设置页在 Windows
上提供下载，也接受一个指向你已有构建的路径。Android、iOS 与 macOS 已内置这些库。

## 构建

```bash
flutter build apk --release          # Android，侧载
flutter build appbundle --release    # Android，商店
flutter build windows --release
flutter build macos --release
flutter build ipa                    # iOS，需要一台 Mac 和签名身份
```

Android 的发布签名读取未提交的 `android/key.properties`。没有它，发布构建会用 debug 密钥签名，这对本地构建
没问题，对分发则不行。

需要打包时：

```bash
dart run msix:create                 # Windows，MSIX
iscc installer.iss                   # Windows，Inno Setup 安装程序
```

## 图标

```bash
dart run tool/generate_ios_icons.dart   # 生成 iOS 的默认、深色与着色源图
dart run flutter_launcher_icons          # Android mipmap、iOS appiconset、Windows 与 macOS 图标
```

源文件是 `assets/icon/app_icon.png`。生成的图标文件绝不手工编辑；改源文件然后重新运行这两条命令。

## 发布之前

`AGENTS.md` 里有完整清单。简而言之：版本号在 `pubspec.yaml` 中出现两次（版本本身与 MSIX 版本），在
`installer.iss` 中出现三次，它们必须一起变。设置页显示的版本不在其中 —— 它在运行时读取包信息，绝不能手工
改动。
