# 自适应布局

这个应用里所有的布局决策都由一个不从 Flutter 引入任何东西的模块做出：
`lib/shared/utils/adaptive_layout.dart`。页面调用具名判定函数，自己绝不拿宽度和数字比较。规则及其推导
来自与各仓库放在一起的系列指南；本页记录**本应用**所用的数字，以及每个页面适用哪条规则。

在声称树中已无内联断点之前，先全局搜一遍：

```bash
grep -rnE "maxWidth *[<>]=? *[0-9]|size\.width *[<>]=? *[0-9]" lib/
```

## 三个问题，三条独立的规则

系列指南要防止的错误，是把一个问题借道另一个问题来回答。问题有三个，它们有意接收不同的输入。

### 规则 A —— 这个布局可以分栏吗？（形状）

```dart
const splitMinWidth  = 600.0;   // Material 中等宽度，Android sw600dp
const splitMinHeight = 480.0;   // 紧凑与中等高度的分界
const splitMinAspect = 0.82;    // 宽 / 高

bool canSplitLayout(double width, double height);
```

三个条件必须同时成立。**长宽比这一项是承重的**：它落在竖握的 Galaxy Z Fold 8（0.755）与接近正方的
Fold 7、Fold 8 Ultra（0.90）之间，因此同一台设备在两种朝向下会得到不同答案 —— 这是任何宽度阈值都表达不
了的。宽度下限把展开的内屏与外屏区分开。高度下限存在，是因为单靠长宽比会放行又宽又矮的视口：横握的手机
在 915×412 下就会分成两个局促的栏。

需要接受的后果：4:3 平板竖屏是 0.75，16:10 平板竖屏是 0.625，因此两者竖屏都保持单栏，横屏都分栏。"我的
平板竖屏不分栏"正是规则在起作用。

### 规则 B —— 导航放在哪里？（只看宽度）

```dart
const navRailMinWidth = 600.0;
const navRailWidth    = 81.0;   // 80 dp 的导航栏加 1 dp 分隔线

bool useNavigationRail(double screenWidth);
```

**只看宽度，且有意不借道规则 A。** 导航栏不是分栏：它用宽度换高度，而每当这条判定通过时宽度都是充裕的，
高度则不然。它帮助最大的恰恰是规则 A 拒绝的情形 —— 横握的手机，此时底部栏要花掉 19% 的高度做导航，而
915 逻辑像素的宽度闲置着。

有两个后果贯穿整个应用：`shellContentWidth` 在计算任何容量之前先扣掉导航栏；`shellListBottomInset` 为底
部栏预留 80，有导航栏时只留 16 —— 因为恰恰在高度最紧张时，这份预留会变成死区。

导航栏与底部栏由 `ShellScaffold` 中**同一份**目的地列表构建，因此两者不会各走各的；导航栏使用
`groupAlignment: 0` —— 默认的顶部对齐是给下方还有前导按钮或 FAB 的导航栏用的，三个目的地钉在高导航栏的
顶部会让下半部分整片空着。

### 规则 C —— 这些东西能放下几个？（只看宽度，按内容）

```dart
int columnCapacity(double contentWidth, {required double minItemWidth, gap, maxColumns});
```

绝不为每个断点写死列数。分子里加一个间距，让算式付的是列**之间**的间距，而不是每列之后各一个。每个调用
方带上自己内容所需的最小宽度。

## 本应用的数字

每个常量都带有说明其来源的文档注释。摘要如下：

| 常量 | 取值 | 原因 |
|---|---|---|
| `pageMaxContentWidth` | 1080 | 表单或阶段列表是自上而下读的；更宽会把标签和取值拉成隔得很远的两列。 |
| `jobTileMinWidth` | 340 | 一个文件名、一行模型与时长、一条进度条和一个状态图标。低于此宽度，最先被截断的正是区分两份录音的文件名。 |
| `jobDetailPaneMinWidth` | 360 | 一行阶段信息加上两个宽 160 的操作按钮并排。 |
| `libraryEditorPaneMinWidth` | 320 | 一个能力下拉框，其最长标签为"词级时间戳：未知"，再加箭头。 |
| `viewerSidebarMinWidth` | 280 | 一个说话人条目：色点、16 个字符的名字、一行计数、一个溢出按钮。 |
| `viewerTranscriptMinWidth` | 440 | 一个说话人标签（约 110）、一个时间戳（约 56），以及至少 45 个字符的正文。 |
| `viewerContentMaxWidth` | 860 | 约 90 个 CJK 字或 100 个拉丁字符 —— 一行可读长度的上限。 |
| `jobOptionMinWidth` | 280 | 一个下拉框，其最长取值是 `microsoft/mai-transcribe-2` 这样的模型名。 |
| `settingsRightPaneMinWidth` | 280 | 沿用系列约定；设置详情栏放的是若干行短文本。 |

分栏宽度先按比例计算再夹取，然后再**封顶**，使另一栏永远不会低于它的下限 —— 用封顶而不是第二个断点。
`test/adaptive_layout_test.dart` 会在 600 到 2000 的每个宽度上断言下限成立，而不是相信算式。

## 每个页面用哪条规则

| 页面 | 规则 | 说明 |
|---|---|---|
| 外壳（`ShellScaffold`） | B，只看宽度 | 从 600 起用导航栏。横握手机会得到导航栏且不能分栏；两者都正确。 |
| 转写（任务列表与详情） | A，经由 `useJobsTwoPane` | 列表与详情并排，`jobsListPaneWidth` 以 `jobDetailPaneMinWidth` 封顶。 |
| 库 | A，经由 `useLibraryTwoPane` | 形态相同；列表更宽，因为它按来源分组。 |
| 设置 | A，直接使用 | 列表与详情，`settingsLeftPaneWidth`。子页面托管在只含一条路由的嵌套 `Navigator` 中，它报告 `canPop == false`，因此不会长出返回箭头。 |
| 新建任务 | C，只看宽度，经由 `useNewJobOptionRow` | 来源与模型两个下拉框从 572 起并排。把它当成分栏来判断会排除横握的手机，而那正是表单相对窗口最高的时候。 |
| 转写稿查看器 | **A 与 C 同时** —— 双重门槛 | 见下文。 |
| 播放条 | C，只看宽度，经由 `useWideAudioBar` | 有自己的阈值 520，因为它的内容与那对下拉框不同。 |
| WebDAV、备份、许可证、隐私 | 无 | 单栏；在宽窗口下它们托管在设置详情栏里。 |

## 查看器的双重门槛

```dart
bool useViewerSidebar(double screenWidth, double screenHeight, double contentWidth) =>
    canSplitLayout(screenWidth, screenHeight) &&
    contentWidth >= viewerTranscriptMinWidth + viewerSidebarMinWidth;
```

只用形状规则是不够的。Fold 7 竖屏在约 716 逻辑像素处通过它，却会让转写稿不足 440 —— 比它取代的单栏还
糟。两块内容都必须放得下，所以这道门槛同时问两个问题。

**查看器是外壳之外的整窗路由，因此没有导航栏需要扣除。** 传入的应是屏幕宽度减去页面自身的内边距，而不是
`shellContentWidth`；后者会悄悄少掉并不存在的 81 逻辑像素。

## 运行时折叠

主 Activity 的 `android:configChanges` 带有
`screenLayout|screenSize|smallestScreenSize|density`，因此窗口尺寸变化不会重建 Activity，所有读取
`MediaQuery.sizeOf` 的地方会在下一帧重新求值。"设备展开时自动切换"所需要的仅此而已 —— 没有生命周期工作，
没有状态要保存。没有它，Activity 会重建，折叠过程中任何未保存的页面状态都会丢失。

## 测试

`test/adaptive_layout_test.dart` 在 `n - 1` 与 `n` 处检查每个阈值，在两端检查每个夹取，并在一段区间上断言
分栏下限不变量，而不是只在某一点。**每个视口都写明它代表的设备**，这样回归报告的是它会弄坏哪台设备，而不
是一个孤零零的数字。

`test/shell_nav_ui_test.dart` 在那些尺寸下用占位页面渲染外壳，因此失败是外壳的失败，而不是某个标签页内容
的失败。两者都以简体中文运行；原因见 [`architecture.md`](architecture.md)。

有两个坑值得记住：默认的 800×600 测试视口已经通过 `canSplitLayout`，所以凡是在意尺寸的测试都要明确固定
视口；另外每个 `TextFormField` 都会带来自己的 `Scrollable`，所以绝不要按位置去定位其中之一。
