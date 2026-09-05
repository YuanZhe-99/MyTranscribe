import 'package:go_router/go_router.dart';

import '../features/jobs/views/jobs_page.dart';
import '../features/jobs/views/new_job_page.dart';
import '../features/providers/views/library_page.dart';
import '../features/transcript/views/transcript_viewer_page.dart';
import '../features/settings/views/settings_page.dart';
import '../shared/widgets/shell_scaffold.dart';

/// Purpose: Build the app's router.
/// Inputs: `initialLocation` — the tab to open on, defaulting to Transcribe.
/// Returns: `GoRouter`.
/// Side effects: None.
/// Notes: The three shell tabs, in the order the bottom bar and the rail show
/// them; `ShellScaffold.routes` holds the same list, keep the two in step.
/// `main()` passes the tab the app was last on, read before `runApp`, so the
/// app opens where the user left it without a visible jump.
///
/// Starting a transcription and reading one are full-window routes outside the
/// shell: both are things you do to one recording and leave when you are
/// finished, and a transcript wants the whole window. Keeping them out of the
/// shell also means they have no navigation rail to subtract, which the layout
/// rules rely on — see `doc/en-us/adaptive-layout.md`.
GoRouter buildAppRouter({String initialLocation = '/jobs'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(path: '/jobs', builder: (context, state) => const JobsPage()),
        GoRoute(
          path: '/library',
          builder: (context, state) => const LibraryPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
    // Outside the shell: both take the whole window, and neither has a
    // navigation rail to subtract, which is what the viewer's layout rules
    // assume.
    GoRoute(path: '/new-job', builder: (context, state) => const NewJobPage()),
    GoRoute(
      path: '/transcript/:id',
      builder: (context, state) =>
          TranscriptViewerPage(jobId: state.pathParameters['id'] ?? ''),
    ),
  ],
);
