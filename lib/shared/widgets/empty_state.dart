import 'package:flutter/material.dart';

/// A centred icon, title and one paragraph, for a page with nothing in it yet.
///
/// Every empty page in the app uses this, so "nothing here" looks the same
/// everywhere and each page only has to supply its own words.
class EmptyState extends StatelessWidget {
  /// The outline icon shown above the title.
  final IconData icon;

  /// One short line naming what is missing.
  final String title;

  /// One sentence saying what to do about it.
  final String body;

  /// An optional action, shown under the text.
  final Widget? action;

  /// Purpose: Create an empty-state instance.
  /// Inputs: `icon`, `title`, `body`, optional `action`.
  /// Returns: A new `EmptyState` instance.
  /// Side effects: None.
  /// Notes: None.
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  /// Purpose: Build the empty state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often. The
  /// 420-pixel cap is a text measure rather than a layout decision — one
  /// sentence set across a desktop window reads as a single long line — so it
  /// is not a breakpoint and does not belong in `adaptive_layout.dart`.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
