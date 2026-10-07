# lib/shared/widgets/shell_scaffold.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `const ShellScaffold({super.key, required this.child});` | Create a shell scaffold instance. |
| `int _currentIndex(BuildContext context) {` | Find which tab the current location belongs to. |
| `List<_ShellDestination> _destinations(AppLocalizations l10n) {` | Describe the shell's three destinations once, icons and all. |
| `Widget build(BuildContext context, WidgetRef ref) {` | Build the shell around the current tab's page. |
| `const _ShellDestination(this.icon, this.selectedIcon, this.label);` | Create a shell destination instance. |
