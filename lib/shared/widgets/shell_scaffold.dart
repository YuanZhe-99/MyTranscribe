import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/app_settings.dart';
import '../services/transcribe_storage.dart';
import '../utils/adaptive_layout.dart';

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
  static const routes = ['/jobs', '/library', '/settings'];

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
        Icons.library_books_outlined,
        Icons.library_books,
        l10n.navLibrary,
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
  /// (the default), when [useNavigationRail] says the window is wide enough,
  /// or always. The rail sits
  /// on the left or, by setting, the right. Expressive's bottom bar floats over
  /// the pages (`extendBody`), and the Scaffold reports its height as bottom
  /// padding so every page can leave room to scroll its last content above it
  /// (see [navBarAwarePadding]). Nothing here is stateful, so folding a device
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

    final wide = useNavigationRail(MediaQuery.sizeOf(context).width);
    // The navigation-position setting (0.4.1): bottom everywhere (the
    // default), side rail on wide windows only, or side rail everywhere.
    final showRail = switch (placement) {
      NavPlacement.bottom => false,
      NavPlacement.sideOnWide => wide,
      NavPlacement.side => true,
    };

    if (!showRail) {
      if (expressive) {
        return Scaffold(
          extendBody: true,
          // extendBody reports the bar's height as `padding`, which lists and
          // navBarAwarePadding use. A page's own Scaffold places its FAB from
          // `viewPadding` instead, so raise that too, or the FAB would sit
          // behind the floating bar.
          body: Builder(
            builder: (context) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  viewPadding: mq.viewPadding.copyWith(
                    bottom: math.max(mq.viewPadding.bottom, mq.padding.bottom),
                  ),
                ),
                child: child,
              );
            },
          ),
          bottomNavigationBar: _ExpressiveNavBar(
            destinations: destinations,
            selectedIndex: index,
            onSelected: select,
          ),
        );
      }
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: select,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    // Three destinations with labels are short, but a rail can appear at
    // compact heights — a phone in landscape earns one at 412 logical pixels
    // tall — so let it scroll rather than overflow.
    final rail = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              // Centred rather than the default top alignment. A rail
              // top-aligns to sit under a leading menu button or FAB; this one
              // has neither, so three destinations pinned to the top of a tall
              // rail would leave the whole lower half empty. Centring also
              // keeps them near the thumb when the window is tall.
              groupAlignment: 0,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    const divider = VerticalDivider(width: 1);
    return Scaffold(
      body: Row(
        children: railOnRight
            ? [Expanded(child: child), divider, rail]
            : [rail, divider, Expanded(child: child)],
      ),
    );
  }
}

/// The Expressive bottom navigation bar (0.4.1): a compact floating pill that
/// hugs its items, modelled on Material 3 Expressive's floating navigation.
/// The selected destination shows its icon and label side by side in a
/// tonal pill; the others show their icon only. It floats over the page
/// (the shell sets `extendBody`), with margins from the screen edges.
class _ExpressiveNavBar extends StatelessWidget {
  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Key on the island's surface, so tests can tell it from the classic bar.
  static const islandKey = ValueKey('floatingNavBarIsland');

  /// Purpose: Create the Expressive navigation bar.
  /// Inputs: `destinations`, `selectedIndex`, `onSelected`.
  /// Returns: A new `_ExpressiveNavBar` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _ExpressiveNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Purpose: Build the island and its items.
  /// Inputs: `context`.
  /// Returns: The floating bar, centred above the system inset.
  /// Side effects: None.
  /// Notes: The bar is as wide as its items; on very narrow screens it scales
  /// down instead of overflowing.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          heightFactor: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Material(
              key: islandKey,
              color: cs.surfaceContainer,
              surfaceTintColor: Colors.transparent,
              shadowColor: cs.shadow,
              elevation: 3,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < destinations.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      _ExpressiveNavItem(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination of [_ExpressiveNavBar].
class _ExpressiveNavItem extends StatelessWidget {
  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  /// Purpose: Create one Expressive navigation item.
  /// Inputs: `destination`, `selected`, `onTap`.
  /// Returns: A new `_ExpressiveNavItem` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _ExpressiveNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  /// Purpose: Build the item: icon, plus the label while selected.
  /// Inputs: `context`.
  /// Returns: A tappable pill.
  /// Side effects: Calls [onTap] when tapped.
  /// Notes: The pill's width and colour animate when the selection moves.
  /// Unselected items carry a tooltip and a semantic label, since their text
  /// is hidden.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    const duration = Duration(milliseconds: 250);
    Widget item = InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: selected ? 20 : 16),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: selected ? cs.secondaryContainer : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              color: fg,
              size: 24,
            ),
            AnimatedSize(
              duration: duration,
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: fg),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    if (!selected) {
      item = Tooltip(message: destination.label, child: item);
    }
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: selected ? null : destination.label,
      child: item,
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
