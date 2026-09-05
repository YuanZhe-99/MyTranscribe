# Adaptive layout

Every layout decision in this app is made by one module that imports nothing from Flutter:
`lib/shared/utils/adaptive_layout.dart`. Pages call a named predicate; they never compare a width to
a number themselves. The rules and their derivation come from the series guide kept beside the
repositories; this page records the numbers **this** app uses and which rule each page applies.

Grep the whole tree before claiming no inline breakpoint remains:

```bash
grep -rnE "maxWidth *[<>]=? *[0-9]|size\.width *[<>]=? *[0-9]" lib/
```

## Three questions, three separate rules

The mistake the series guide exists to prevent is routing one question through another. There are
three, and they take different inputs on purpose.

### Rule A — may this layout split? (shape)

```dart
const splitMinWidth  = 600.0;   // Material medium width, Android sw600dp
const splitMinHeight = 480.0;   // the compact/medium height boundary
const splitMinAspect = 0.82;    // width / height

bool canSplitLayout(double width, double height);
```

All three conditions must hold. The **aspect test is the load-bearing one**: it sits between a
Galaxy Z Fold 8 held in portrait (0.755) and the near-square Fold 7 and Fold 8 Ultra (0.90), so one
device answers differently in its two orientations — which no width threshold can express. The width
floor separates an unfolded panel from a cover screen. The height floor exists because the aspect
test alone would admit a wide, short viewport: a phone in landscape at 915 by 412 would otherwise
split into two cramped panes.

The consequence to accept: a 4:3 tablet in portrait is 0.75 and a 16:10 tablet in portrait is 0.625,
so both stay single-column and both split in landscape. "My tablet does not split in portrait" is
the rule working.

### Rule B — where does navigation live? (width only)

```dart
const navRailMinWidth = 600.0;
const navRailWidth    = 81.0;   // an 80 dp rail plus its 1 dp divider

bool useNavigationRail(double screenWidth);
```

**Width only, and deliberately not routed through Rule A.** A rail is not a split: it trades width,
which is abundant whenever this passes, for height, which is not. The case it helps most is the one
Rule A rejects — a phone in landscape, where a bottom bar spends 19% of the height on navigation
while 915 logical pixels of width sit unused.

Two consequences are carried through the app: `shellContentWidth` subtracts the rail before any
capacity is computed, and `shellListBottomInset` reserves 80 for a bottom bar but only 16 when there
is a rail, because the reservation becomes dead space exactly when height is scarcest.

The rail and the bottom bar are built from **one** list of destinations in `ShellScaffold`, so they
cannot drift apart, and the rail uses `groupAlignment: 0` — the default top alignment is for a rail
sitting under a leading button or FAB, and three destinations pinned to the top of a tall rail would
leave the whole lower half empty.

### Rule C — how many of these fit? (width only, per content)

```dart
int columnCapacity(double contentWidth, {required double minItemWidth, gap, maxColumns});
```

Never a hardcoded column count per breakpoint. One gap goes in the numerator so the arithmetic pays
for the gaps *between* columns rather than one after every column. Each caller brings the minimum
its own content needs.

## This app's numbers

Every constant carries a doc comment saying where the number came from. In summary:

| Constant | Value | Why |
|---|---|---|
| `pageMaxContentWidth` | 1080 | A form or a stage list read top to bottom; wider turns labels and values into distant columns. |
| `jobTileMinWidth` | 340 | A file name, a model-and-duration line, a progress bar and a status icon. Below this the file name — the only thing telling two recordings apart — truncates first. |
| `jobDetailPaneMinWidth` | 360 | A stage row plus two 160-wide action buttons side by side. |
| `libraryEditorPaneMinWidth` | 320 | A capability dropdown whose longest label is "Word timestamps: unknown" plus its arrow. |
| `viewerSidebarMinWidth` | 280 | A speaker tile: colour dot, a 16-character name, a counts line, an overflow button. |
| `viewerTranscriptMinWidth` | 440 | A speaker chip (~110), a timestamp (~56) and at least 45 characters of body text. |
| `viewerContentMaxWidth` | 860 | About 90 CJK or 100 Latin characters — the upper end of a reading measure. |
| `jobOptionMinWidth` | 280 | A dropdown whose longest value is a model name such as `microsoft/mai-transcribe-2`. |
| `settingsRightPaneMinWidth` | 280 | Inherited from the series; a settings detail pane holds rows of short text. |

Pane widths are proportional and then clamped, and then **capped** so the other pane can never drop
below its floor — a cap rather than a second breakpoint. `test/adaptive_layout_test.dart` asserts
the floor holds at every width from 600 to 2000 rather than trusting the arithmetic.

## Which rule each page uses

| Page | Rule | Notes |
|---|---|---|
| Shell (`ShellScaffold`) | B, width only | Rail from 600. A phone in landscape gets a rail and cannot split; both are correct. |
| Transcribe (jobs list and detail) | A, via `useJobsTwoPane` | List and detail side by side, `jobsListPaneWidth` capped against `jobDetailPaneMinWidth`. |
| Library | A, via `useLibraryTwoPane` | Same shape; the list is wider because it is grouped by source. |
| Settings | A, directly | List and detail, `settingsLeftPaneWidth`. The sub-page is hosted in a nested `Navigator` holding one route, which reports `canPop == false` so it grows no back arrow. |
| New job | C, width only, via `useNewJobOptionRow` | The source and model dropdowns pair from 572 up. Reading this as a split would exclude a phone in landscape, which is where the form is tallest relative to the window. |
| Transcript viewer | **A and C together** — a double gate | See below. |
| Player bar | C, width only, via `useWideAudioBar` | Its own threshold at 520, because its content is not the same as the dropdown pair's. |
| WebDAV, backup, licence, privacy | none | Single column; they are hosted in the settings detail pane on a wide window. |

## The viewer's double gate

```dart
bool useViewerSidebar(double screenWidth, double screenHeight, double contentWidth) =>
    canSplitLayout(screenWidth, screenHeight) &&
    contentWidth >= viewerTranscriptMinWidth + viewerSidebarMinWidth;
```

The shape rule alone is not enough. A Fold 7 in portrait passes it at about 716 logical pixels and
would leave the transcript under 440 — worse than the single column it replaced. Both blocks must
have room, so the gate asks both questions.

**The viewer is a full-window route outside the shell, so it has no rail to subtract.** Pass the
screen width less the page's own padding, not `shellContentWidth`; passing it through would silently
lose 81 logical pixels that are not there.

## Folding at runtime

`android:configChanges` on the main activity carries
`screenLayout|screenSize|smallestScreenSize|density`, so the window resizes without recreating the
activity and everything reading `MediaQuery.sizeOf` re-evaluates on the next frame. That is all
"switch automatically when the device unfolds" needs — no lifecycle work, no state to save. Without
it, the activity recreates and any unsaved page state is lost mid-fold.

## Testing

`test/adaptive_layout_test.dart` checks every threshold at `n - 1` and `n`, every clamp at both
ends, and asserts the pane-floor invariants across a range rather than at a point. **Each viewport
names the device it stands for**, so a regression reports the device it would break rather than a
bare number.

`test/shell_nav_ui_test.dart` pumps the shell at those geometries over stub pages, so a failure is a
failure of the shell and not of whatever a tab happens to show. Both drive Simplified Chinese; the
reason is in [`architecture.md`](architecture.md).

Two traps worth remembering: the default 800 by 600 test viewport already passes `canSplitLayout`,
so pin an explicit size in any test that cares; and every `TextFormField` contributes its own
`Scrollable`, so never address one positionally.
