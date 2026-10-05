# 共享界面基础

MyApps-UI `v0.1.1` 作为子模块放在 `packages/myapps_ui`，相对地址为
`../MyApps-UI.git`。克隆后递归初始化子模块。

`lib/app/theme.dart` 保留原公开包装接口、青绿色品牌色和默认
Expressive 风格，调用 `myapps_ui`。公共枚举保留存储名称。
动态配色的平台策略仍由应用负责。

`lib/shared/utils/adaptive_layout.dart` 重新导出 `myapps_adaptive` 的公共阈值及
`canSplitLayout`、`useNavigationRail`、`columnCapacity`、`listRowCount`。
任务、模型库、转写阅读和音频控件尺寸仍保留在应用中。
资料、设置、转写、密钥和音频格式不受影响。

## 升级

先把共享提交和标签发布到两个远程，再更新应用指针。
固定到标签并运行应用分析和完整测试。库文档维护公共声明；
应用保留接入和业务布局文档。

## P2 导航与实际空间

应用现在把导航绘制交给 `MyAppsNavigationShell`。应用导航壳保留路由、
目的地过滤、选中位置持久化和提醒回调。页面把 `context` 传入宽度和底部留白
函数，只使用一次实际内容宽度；全窗口路由不再扣除侧栏。无上下文的兼容函数
保留原计算方式。固定内容位置在缩放、风格和侧栏方向切换时保留页面状态。
MyVidComp 保留经典导航、展开侧栏和审核角标。

资料抽取仍属于 P3，数据格式不变。
