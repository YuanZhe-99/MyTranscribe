import 'package:flutter/widgets.dart';
import 'package:myapps_ui/myapps_ui.dart' show MyAppsShellLayout;
import 'package:myapps_adaptive/myapps_adaptive.dart';

export 'package:myapps_adaptive/myapps_adaptive.dart';

/// Minimum usable settings detail pane width.
const settingsRightPaneMinWidth = 280.0;

/// Purpose: Return the width a shell page's content actually receives.
/// Inputs: `screenWidth` — full window width; `context` — actual page context.
/// Returns: `double`, never negative.
/// Side effects: None.
/// Notes: Context reads measured shell width; outside a shell uses full width.
/// The context-free form retains the legacy width rule for compatibility. Pass the
/// result wherever a capacity is being computed; keep passing the untouched
/// screen size to [canSplitLayout], which asks about the window's shape rather
/// than about the room left over inside it.
double shellContentWidth(double screenWidth, {BuildContext? context}) {
  if (context != null) {
    return MyAppsShellLayout.maybeOf(context)?.contentWidth ?? screenWidth;
  }
  final width = useNavigationRail(screenWidth)
      ? screenWidth - navRailWidth
      : screenWidth;
  return width < 0 ? 0 : width;
}

/// Purpose: Return the bottom padding a shell page's scrolling list needs.
/// Inputs: `screenWidth` — full window width; optional page `context`.
/// Returns: `double`.
/// Side effects: None.
/// Notes: The page's floating action button overlaps the last rows of a list,
/// so pages reserve room for it. A navigation rail takes width instead, and the
/// reservation becomes dead space at the very moment vertical room is scarcest
/// — a Fold 8 in landscape is only 704 logical pixels tall. Since 0.4.1 the
/// Expressive bottom bar floats over the page; its height is added on top of
/// this value by [navBarAwarePadding], which every caller wraps around it.
double shellListBottomInset(double screenWidth, {BuildContext? context}) =>
    (context == null
        ? useNavigationRail(screenWidth)
        : MyAppsShellLayout.maybeOf(context)?.hasRail ?? false)
    ? 16.0
    : 80.0;

/// Widest, in logical pixels, a page's content column grows before it centres.
///
/// A transcript, a job's stage list and a model's capability form are all read
/// top to bottom; stretching any of them across a 1600-pixel window turns a
/// paragraph into one long line and a form into a row of far-apart labels.
const pageMaxContentWidth = 1080.0;

/// Purpose: Return the width of the settings page's fixed left pane.
/// Inputs: `contentWidth` — the width both panes share, in logical pixels,
/// which is [shellContentWidth] rather than the screen width.
/// Returns: `double`.
/// Side effects: None.
/// Notes: Proportional, then clamped, then capped so the detail pane can never
/// be squeezed below [settingsRightPaneMinWidth]. The left pane carries full
/// `ListTile`s with trailing dropdowns, so it needs more room than a plain
/// list would. The cap only binds on a hand-resized desktop window and on the
/// narrowest foldables, where it gives up left-pane width rather than let the
/// right pane become unusable.
double settingsLeftPaneWidth(double contentWidth) {
  final preferred = (contentWidth * 0.44).clamp(300.0, 440.0);
  final capped = contentWidth - settingsRightPaneMinWidth;
  if (preferred <= capped) return preferred;
  return capped.clamp(240.0, 440.0);
}

/// Minimum width, in logical pixels, one job tile may occupy.
///
/// A tile carries the recording's name on one line, a second line of model and
/// duration, a progress bar, and a trailing status icon. Below this the file
/// name — the only thing that tells two recordings apart — truncates before the
/// model name does.
const jobTileMinWidth = 340.0;

/// Smallest width, in logical pixels, the job detail pane may be given.
///
/// The stage list sets the floor: a stage row is an icon, a label and an
/// elapsed time, and the two action buttons under it (Cancel and Open
/// transcript) are 160 each with a gap between them.
const jobDetailPaneMinWidth = 360.0;

/// Purpose: Return the width of the job list pane beside a job's detail.
/// Inputs: `contentWidth` — the width both panes share, from
/// [shellContentWidth].
/// Returns: `double`.
/// Side effects: None.
/// Notes: The same proportional-then-capped shape as [settingsLeftPaneWidth].
/// The list is the smaller half: it holds one tile per recording, while the
/// detail holds the plan, the stages and the per-chunk table.
double jobsListPaneWidth(double contentWidth) {
  final preferred = (contentWidth * 0.38).clamp(300.0, 420.0);
  final capped = contentWidth - jobDetailPaneMinWidth;
  return capped < preferred ? capped : preferred;
}

/// Smallest width, in logical pixels, the library editor pane may be given.
///
/// A capability row is an `OutlineInputBorder` dropdown whose longest label is
/// "Word timestamps: unknown" plus its arrow; narrower and the value truncates
/// before the label does, which is the half that matters.
const libraryEditorPaneMinWidth = 320.0;

/// Purpose: Return the width of the library list pane beside an editor.
/// Inputs: `contentWidth` — the width both panes share, from
/// [shellContentWidth].
/// Returns: `double`.
/// Side effects: None.
/// Notes: Wider than [jobsListPaneWidth] because the list is grouped — a
/// source header with its models indented under it — so it carries two levels
/// of text rather than one.
double libraryListPaneWidth(double contentWidth) {
  final preferred = (contentWidth * 0.40).clamp(300.0, 440.0);
  final capped = contentWidth - libraryEditorPaneMinWidth;
  return capped < preferred ? capped : preferred;
}

/// Smallest width, in logical pixels, the transcript viewer's sidebar may be.
///
/// A speaker tile is a colour dot, a name field wide enough for a sixteen
/// character name, a "12 segments, 4:07" line, and an overflow button.
const viewerSidebarMinWidth = 280.0;

/// Smallest width, in logical pixels, the transcript itself may be given.
///
/// A speaker chip is about 110, a timestamp about 56, and below roughly 45
/// characters of body text a paragraph wraps so often that the speaker chips
/// dominate the page. Larger than [settingsRightPaneMinWidth] on purpose: a
/// settings pane holds rows of short text, this holds prose.
const viewerTranscriptMinWidth = 440.0;

/// Widest, in logical pixels, the transcript column grows before it centres.
///
/// About 90 CJK or 100 Latin characters at the default viewer text size, which
/// is the upper end of a comfortable reading measure. Narrower than
/// [pageMaxContentWidth] because this is continuous prose rather than a form.
const viewerContentMaxWidth = 860.0;

/// Purpose: Return the width of the transcript viewer's speaker sidebar.
/// Inputs: `contentWidth` — the width both panes share.
/// Returns: `double`.
/// Side effects: None.
/// Notes: The transcript is the larger half, so the sidebar takes a smaller
/// share than the list panes above. [useViewerSidebar] has already guaranteed
/// the transcript clears [viewerTranscriptMinWidth], so no cap is needed here:
/// above the gate the sidebar grows at 0.30 while the transcript grows at 0.70,
/// and the sidebar stops growing at 360 entirely.
double viewerSidebarWidth(double contentWidth) =>
    (contentWidth * 0.30).clamp(viewerSidebarMinWidth, 360.0);

/// Purpose: Report whether the transcript viewer shows its sidebar beside the
/// transcript instead of in a bottom sheet.
/// Inputs: `screenWidth`, `screenHeight` — the whole screen, for the shape
/// gate; `contentWidth` — the width the page itself receives.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: A **double gate**: the window must have the shape for two panes, and
/// there must be room for both blocks. The shape rule alone is not enough — a
/// Fold 7 in portrait passes it at about 716 logical pixels and would leave the
/// transcript under 440, which is worse than the single column it replaced.
///
/// The viewer is a full-window route **outside** the navigation shell, so it
/// has no rail to subtract: pass the screen width less the page's own padding,
/// not [shellContentWidth].
bool useViewerSidebar(
  double screenWidth,
  double screenHeight,
  double contentWidth,
) {
  if (!canSplitLayout(screenWidth, screenHeight)) return false;
  return contentWidth >= viewerTranscriptMinWidth + viewerSidebarMinWidth;
}

/// Minimum width, in logical pixels, one new-job dropdown may occupy.
///
/// An `OutlineInputBorder` dropdown whose longest value is a model name such
/// as "microsoft/mai-transcribe-2"; narrower and the name truncates before the
/// arrow.
const jobOptionMinWidth = 280.0;

/// Purpose: Report whether the new-job page pairs its source and model
/// dropdowns on one row.
/// Inputs: `contentWidth` — the width the form receives.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: **Width only, deliberately** — this asks whether two controls fit
/// side by side, not whether the window has the shape for two panes. Reading it
/// as a split would exclude a phone in landscape, which is exactly where the
/// form is tallest relative to the window and the pairing helps most.
bool useNewJobOptionRow(double contentWidth) =>
    columnCapacity(
      contentWidth,
      minItemWidth: jobOptionMinWidth,
      maxColumns: 2,
    ) >=
    2;

/// Purpose: Report whether the player bar fits its transport, scrubber and
/// speed control on one line.
/// Inputs: `contentWidth` — the width the bar receives.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Width only, for the same reason as [useNewJobOptionRow], and a
/// separate threshold from it because the content is different: three transport
/// buttons (144), an elapsed/total pair (120), a speed button (72) and a
/// scrubber that stops being draggable below about 160, plus gaps.
bool useWideAudioBar(double contentWidth) => contentWidth >= 520.0;

/// Purpose: Report whether the jobs page shows its list and detail side by
/// side.
/// Inputs: `screenWidth`, `screenHeight` — the whole screen.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: A page-named delegate to [canSplitLayout], so the page keeps its own
/// vocabulary; `test/adaptive_layout_test.dart` asserts the two still agree.
bool useJobsTwoPane(double screenWidth, double screenHeight) =>
    canSplitLayout(screenWidth, screenHeight);

/// Purpose: Report whether the library page shows its list and editor side by
/// side.
/// Inputs: `screenWidth`, `screenHeight` — the whole screen.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: A page-named delegate to [canSplitLayout], like [useJobsTwoPane].
bool useLibraryTwoPane(double screenWidth, double screenHeight) =>
    canSplitLayout(screenWidth, screenHeight);

/// Purpose: Add the floating navigation bar's height to a page's padding.
/// Inputs: `context` — inside a shell page; `padding` — the page's own padding.
/// Returns: `EdgeInsets` — [padding] with the bottom inset reported by the
/// enclosing Scaffold added to its bottom.
/// Side effects: None.
/// Notes: With the Expressive bottom bar the shell uses `extendBody`, so pages
/// draw behind the bar and the Scaffold reports the bar's height as
/// `MediaQuery.padding.bottom`. Scroll views with an explicit padding do not
/// apply that inset themselves; passing their padding through here leaves room
/// to scroll the last content above the bar. `ListView`/`GridView` with no
/// padding, and a page outside the shell, need nothing. A route pushed with
/// `Navigator.push` from a shell page lives inside the shell navigator and is
/// covered by the bar too, unless it uses `rootNavigator: true`; the same holds
/// for a modal sheet without `useRootNavigator: true`. Elsewhere (classic bar,
/// rail) the inset is just the system's, so this is harmless.
EdgeInsets navBarAwarePadding(BuildContext context, EdgeInsets padding) =>
    padding.copyWith(
      bottom: padding.bottom + MediaQuery.paddingOf(context).bottom,
    );
