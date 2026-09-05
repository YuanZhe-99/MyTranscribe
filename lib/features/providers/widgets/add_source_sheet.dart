/// Purpose: Offer the prefilled sources when the user adds one.
/// Inputs: The starter presets.
/// Returns: The chosen preset, or null when the user backs out.
/// Side effects: Shows a modal sheet.
/// Notes: Every preset is marked *unverified*: it is a starting point for an
/// address and a model name, not a promise about what that service does. Its
/// capabilities stay unknown, which is what makes the app offer a feature with
/// a warning rather than claim it works.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/provider_templates.dart';

/// Purpose: Ask which kind of source to add.
/// Inputs: [context].
/// Returns: The chosen preset, or null.
/// Side effects: Shows a modal bottom sheet.
/// Notes: A sheet rather than a page: choosing is one decision from a short
/// list, and the editing happens afterwards on the real editor.
Future<ProviderPreset?> showAddSourceSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<ProviderPreset>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.libraryAddSource,
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final preset in buildProviderPresets())
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Row(
                  children: [
                    Flexible(child: Text(preset.label)),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(l10n.libraryUnverified),
                      visualDensity: VisualDensity.compact,
                      labelStyle: theme.textTheme.labelSmall,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                subtitle: Text(preset.description),
                onTap: () => Navigator.of(ctx).pop(preset),
              ),
          ],
        ),
      );
    },
  );
}
