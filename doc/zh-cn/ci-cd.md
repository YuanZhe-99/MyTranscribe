# 构建与验证

**没有持续集成**。仓库有两个远端，两个都不跑托管任务，因此 `flutter analyze` 与 `flutter test` 在本地
运行，它们就是关卡。

| 远端 | 位置 | 用途 |
|---|---|---|
| `origin` | 一台私有的 Gitea 实例 | 开发；每次推送先到这里 |
| `github` | `github.com/YuanZhe-99/MyTranscribe` | 公开镜像 |

两者携带同一个 `main` 与同一批标签。先推 `origin`：没有经过本地关卡的提交，没有理由先公开。

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
