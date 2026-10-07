# lib/shared/widgets/shell_scaffold.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `const ShellScaffold({super.key, required this.child});` | Create a shell scaffold instance. |
| `int _currentIndex(BuildContext context) {` | Find which tab the current location belongs to. |
| `List<_ShellDestination> _destinations(AppLocalizations l10n) {` | Describe the shell's three destinations once, icons and all. |
| `Widget build(BuildContext context, WidgetRef ref) {` | Build the shell around the current tab's page. |
| `const _ShellDestination(this.icon, this.selectedIcon, this.label);` | Create a shell destination instance. |
