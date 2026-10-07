import 'package:flutter/material.dart';
import 'package:myapps_ui/myapps_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/app_settings.dart';
import '../services/transcribe_storage.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;

  /// Purpose: Create a shell scaffold instance.
  /// Inputs: `key`, `child`.
  /// Returns: A new `ShellScaffold` instance.
  /// Side effects: None.
  /// Notes: None.
  const ShellScaffold({super.key, required this.child});

  /// The three tab routes, in display order. `lib/app/router.dart` declares the
  /// same three; keep them in step.
  static const routes = ['/jobs', '/settings'];

  /// Purpose: Find which tab the current location belongs to.
  /// Inputs: `context`.
  /// Returns: `int` — an index into [routes], 0 when nothing matches.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < routes.length; i++) {
      if (location.startsWith(routes[i])) return i;
    }
    return 0;
  }

  /// Purpose: Describe the shell's three destinations once, icons and all.
  /// Inputs: `l10n`.
  /// Returns: `List<_ShellDestination>` in the same order as [routes].
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Both the bottom bar and
  /// the rail read from this, so a destination can never end up in one and not
  /// the other, or in a different order between them.
  List<_ShellDestination> _destinations(AppLocalizations l10n) {
    return [
      _ShellDestination(
        Icons.graphic_eq_outlined,
        Icons.graphic_eq,
        l10n.navTranscribe,
      ),
      _ShellDestination(
        Icons.settings_outlined,
        Icons.settings,
        l10n.navSettings,
      ),
    ];
  }

  /// Purpose: Build the shell around the current tab's page.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often. The rail
  /// and the bottom bar are two renderings of the same three destinations.
  /// Whether the rail shows is the navigation-position setting (0.4.1): never
  /// (the default), when the shared width rule says the window is wide enough,
  /// or always. The rail sits
  /// on the left or, by setting, the right. Expressive's bottom bar floats over
  /// the pages (`extendBody`), and the Scaffold reports its height as bottom
  /// padding so every page can leave room to scroll its last content above it
  /// (see the app padding helper). Nothing here is stateful, so folding a device
  /// swaps layouts on the next frame with no route change.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = _destinations(l10n);
    final index = _currentIndex(context);
    final expressive = ref.watch(
      appSettingsProvider.select((s) => s.uiStyle == AppUiStyle.expressive),
    );
    final placement = ref.watch(
      appSettingsProvider.select((s) => s.navPlacement),
    );
    final railOnRight = ref.watch(
      appSettingsProvider.select((s) => s.navRailOnRight),
    );

    void select(int i) {
      context.go(routes[i]);
      // Remember where the user is, so the next launch opens here. Fire and
      // forget: it is one small file, and losing the write on a crash costs
      // nothing more than starting on the transcribe tab.
      TranscribeStorage.setLastTab(routes[i].substring(1));
    }

    return MyAppsNavigationShell(
      destinations: [
        for (final d in destinations)
          MyAppsDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
      ],
      selectedIndex: index,
      onSelected: select,
      style: expressive ? AppUiStyle.expressive : AppUiStyle.material3,
      placement: placement,
      railOnRight: railOnRight,
      child: child,
    );
  }
}

class _ShellDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Purpose: Create a shell destination instance.
  /// Inputs: `icon`, `selectedIcon`, `label`.
  /// Returns: A new `_ShellDestination` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _ShellDestination(this.icon, this.selectedIcon, this.label);
}
