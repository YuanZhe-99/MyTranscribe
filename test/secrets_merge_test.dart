/// Purpose: Test how two devices' API keys are reconciled.
/// Inputs: None.
/// Returns: None.
/// Side effects: None — the merge is pure.
/// Notes: The case that matters most is the tombstone: without one, clearing a
/// key on one device and syncing would simply let the other device's copy come
/// back, which is the opposite of what deleting a credential should do.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/secrets/models/provider_secrets.dart';
import 'package:my_transcribe/features/secrets/services/secrets_store.dart';

void main() {
  final earlier = DateTime.utc(2026, 1, 1);
  final later = DateTime.utc(2026, 2, 1);

  SecretsFile file(Map<String, (String?, DateTime)> entries) => SecretsFile(
    keys: {
      for (final e in entries.entries)
        e.key: ProviderSecret(apiKey: e.value.$1, updatedAt: e.value.$2),
    },
  );

  group('merging', () {
    test('a key set on one device reaches the other', () {
      final merged = mergeSecrets(
        const SecretsFile(),
        file({'provider:openai': ('sk-remote', later)}),
      );
      expect(merged.keyFor('provider:openai'), 'sk-remote');
    });

    test('the newer edit wins', () {
      final merged = mergeSecrets(
        file({'provider:openai': ('sk-mine', later)}),
        file({'provider:openai': ('sk-theirs', earlier)}),
      );
      expect(merged.keyFor('provider:openai'), 'sk-mine');

      final other = mergeSecrets(
        file({'provider:openai': ('sk-mine', earlier)}),
        file({'provider:openai': ('sk-theirs', later)}),
      );
      expect(other.keyFor('provider:openai'), 'sk-theirs');
    });

    test('a cleared key stays cleared instead of coming back', () {
      // The tombstone earning its keep: the remote still holds the old key, but
      // this device cleared it more recently.
      final merged = mergeSecrets(
        file({'provider:openai': (null, later)}),
        file({'provider:openai': ('sk-old', earlier)}),
      );
      expect(merged.keyFor('provider:openai'), isNull);
      expect(
        merged.keys.containsKey('provider:openai'),
        isTrue,
        reason: 'the tombstone has to survive, or the next sync undoes this',
      );
    });

    test('a key set after a deletion comes back', () {
      final merged = mergeSecrets(
        file({'provider:openai': (null, earlier)}),
        file({'provider:openai': ('sk-new', later)}),
      );
      expect(merged.keyFor('provider:openai'), 'sk-new');
    });

    test('keys for different sources do not interfere', () {
      final merged = mergeSecrets(
        file({'provider:openai': ('sk-a', later)}),
        file({'provider:openrouter': ('sk-b', later)}),
      );
      expect(merged.keyFor('provider:openai'), 'sk-a');
      expect(merged.keyFor('provider:openrouter'), 'sk-b');
    });

    test('a tie is resolved the same way on both devices', () {
      // Whichever side runs the merge must reach the same answer, or the two
      // would swap values back and forth forever.
      final mine = file({'provider:openai': ('sk-mine', later)});
      final theirs = file({'provider:openai': ('sk-theirs', later)});
      expect(
        mergeSecrets(mine, theirs).keyFor('provider:openai'),
        mergeSecrets(mine, theirs).keyFor('provider:openai'),
      );
      // And the rule is "prefer the remote", so a device that has just
      // downloaded converges on what the server holds.
      expect(mergeSecrets(mine, theirs).keyFor('provider:openai'), 'sk-theirs');
    });

    test('merging is idempotent', () {
      final a = file({'provider:openai': ('sk-a', later)});
      final b = file({'provider:openai': (null, earlier)});
      final once = mergeSecrets(a, b);
      final twice = mergeSecrets(once, b);
      expect(twice.keyFor('provider:openai'), once.keyFor('provider:openai'));
    });
  });

  group('the file', () {
    test('round-trips through JSON, tombstones included', () {
      final original = file({
        'provider:openai': ('sk-live', later),
        'provider:gone': (null, earlier),
      });
      final parsed = SecretsFile.fromJson(
        jsonDecode(encodeSecrets(original)) as Map<String, dynamic>,
      );
      expect(parsed.keyFor('provider:openai'), 'sk-live');
      expect(parsed.keys['provider:gone']!.apiKey, isNull);
      expect(parsed.keys['provider:gone']!.updatedAt, earlier);
    });

    test('encodes identically for identical content', () {
      // What lets the exchange skip an upload that would say nothing new.
      final a = file({
        'provider:b': ('two', later),
        'provider:a': ('one', later),
      });
      final b = file({
        'provider:a': ('one', later),
        'provider:b': ('two', later),
      });
      expect(encodeSecrets(a), encodeSecrets(b));
    });

    test('reports which sources are configured, without exposing a key', () {
      final secrets = file({
        'provider:openai': ('sk-live', later),
        'provider:gone': (null, later),
      });
      expect(secrets.configuredProviders, {'provider:openai'});
    });

    test('a blank key reads as absent', () {
      final secrets = const SecretsFile().withKey('provider:x', '   ');
      expect(secrets.keyFor('provider:x'), isNull);
      expect(secrets.configuredProviders, isEmpty);
    });

    test('a key is trimmed, because a pasted one often carries whitespace', () {
      final secrets = const SecretsFile().withKey('provider:x', '  sk-abc\n');
      expect(secrets.keyFor('provider:x'), 'sk-abc');
    });

    test('a malformed entry does not take the whole file down', () {
      final parsed = SecretsFile.fromJson({
        'keys': {
          'provider:ok': {
            'apiKey': 'sk-ok',
            'updatedAt': later.toIso8601String(),
          },
          'provider:bad': 'not an object',
        },
      });
      expect(parsed.keyFor('provider:ok'), 'sk-ok');
      expect(parsed.keys.containsKey('provider:bad'), isFalse);
    });

    test(
      'an unreadable timestamp loses every merge rather than winning it',
      () {
        final parsed = SecretsFile.fromJson({
          'keys': {
            'provider:x': {'apiKey': 'sk-damaged', 'updatedAt': 'not a date'},
          },
        });
        final merged = mergeSecrets(
          parsed,
          file({'provider:x': ('sk-real', earlier)}),
        );
        expect(merged.keyFor('provider:x'), 'sk-real');
      },
    );

    test('fields from a newer build survive a round trip', () {
      final parsed = SecretsFile.fromJson({
        'version': 1,
        'keys': const <String, dynamic>{},
        'somethingNew': 42,
      });
      final reparsed = SecretsFile.fromJson(
        jsonDecode(encodeSecrets(parsed)) as Map<String, dynamic>,
      );
      expect(reparsed.extraJson['somethingNew'], 42);
    });
  });
}
