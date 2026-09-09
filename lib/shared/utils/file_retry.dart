/// Purpose: Retry a small file operation that a momentary lock defeated.
/// Inputs: The operation to run.
/// Returns: What the operation returns.
/// Side effects: Whatever the operation does, possibly more than once.
/// Notes: On Windows a virus scanner, a backup agent or the app's own atomic
/// rename can hold a file open for a few milliseconds, and the write that
/// lands in that window fails for no reason the user could act on. The job
/// store has retried its records this way since M2; transcripts need the same
/// protection, so the loop lives here rather than being copied.
library;

import 'dart:io';

/// Purpose: Run a file operation again if a lock defeats it.
/// Inputs: [action], and how many [attempts] to make.
/// Returns: What [action] returns.
/// Side effects: Whatever [action] does, possibly more than once.
/// Notes: The delay grows with each attempt, so six attempts span about a
/// tenth of a second and ten span about a third — far longer than a scanner or
/// a concurrent reader holds a small file, and short enough that nobody
/// notices. The final failure is thrown, not swallowed: a file that truly
/// cannot be written is worth reporting, and a caller that can carry on says
/// so by catching it.
Future<T> retryingFileOperation<T>(
  Future<T> Function() action, {
  int attempts = 6,
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await action();
    } on FileSystemException {
      if (attempt >= attempts) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 8 * attempt));
    }
  }
}
