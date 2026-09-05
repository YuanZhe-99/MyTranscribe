/// Purpose: Enter, replace or remove one source's API key.
/// Inputs: The source's record id.
/// Returns: A widget for the source editor.
/// Side effects: Reads and writes `transcribe_secrets.json`.
/// Notes: **A stored key is never displayed.** The field shows whether one is
/// set and lets the user replace it, which is what every service that handles
/// credentials does — a key rendered on screen is a key in a screenshot, a
/// screen recording, or over somebody's shoulder. Replacing does not need the
/// old value, so nothing is lost by not showing it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../secrets/services/secrets_store.dart';

class ApiKeyField extends ConsumerStatefulWidget {
  /// The source whose key this edits.
  final String providerId;

  /// Purpose: Create the key field.
  /// Inputs: [providerId].
  /// Returns: A new widget.
  /// Side effects: None.
  /// Notes: None.
  const ApiKeyField({super.key, required this.providerId});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends ConsumerState<ApiKeyField> {
  final _controller = TextEditingController();

  /// Whether the field is showing what the user is typing.
  ///
  /// Only ever reveals a key the user typed in this session, never a stored
  /// one — there is nothing to reveal for a stored key, because it is not
  /// loaded into the field.
  bool _visible = false;

  /// Purpose: Release the controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Purpose: Store what the user typed.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes the keys file, schedules a sync, clears the field.
  /// Notes: Internal helper used within this file only. The field is cleared
  /// after saving, so the key does not sit in the widget tree for the rest of
  /// the session.
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    await SecretsStore.setKey(widget.providerId, value);
    ref.refresh(configuredProvidersProvider);
    if (!mounted) return;
    _controller.clear();
    setState(() => _visible = false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.libraryApiKeySet)));
  }

  /// Purpose: Remove the stored key.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes a tombstone and refreshes the status.
  /// Notes: Internal helper used within this file only. A tombstone rather than
  /// a deletion, so the removal survives the next sync instead of the other
  /// device putting the key back.
  Future<void> _clear() async {
    await SecretsStore.setKey(widget.providerId, null);
    ref.refresh(configuredProvidersProvider);
    if (mounted) setState(() {});
  }

  /// Purpose: Build the key field and its status.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches which sources have a key.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final configured = ref.watch(configuredProvidersProvider);
    final hasKey = configured.value?.contains(widget.providerId) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasKey ? Icons.key : Icons.key_off_outlined,
              size: 20,
              color: hasKey ? null : theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(l10n.libraryApiKey, style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              hasKey ? l10n.libraryApiKeySet : l10n.libraryApiKeyMissing,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasKey
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          obscureText: !_visible,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            // Never the stored key: a hint that showed it would defeat the
            // point of obscuring the field.
            hintText: hasKey ? '••••••••' : null,
            suffixIcon: IconButton(
              tooltip: _visible ? l10n.commonClose : l10n.commonEdit,
              icon: Icon(
                _visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(onPressed: _save, child: Text(l10n.libraryApiKeySave)),
            const SizedBox(width: 8),
            if (hasKey)
              TextButton(
                onPressed: _clear,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(l10n.libraryApiKeyClear),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.libraryApiKeyNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
