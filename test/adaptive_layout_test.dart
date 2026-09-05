/// Purpose: Test the layout policy module as pure functions, at the geometry
/// of real devices.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Every threshold is checked at `n - 1` and `n`, every clamp at both
/// ends, and each viewport names the device it stands for — so a regression
/// reports the device it would break rather than a bare number. The derivation
/// behind the constants is `doc/en-us/adaptive-layout.md`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/shared/utils/adaptive_layout.dart';

void main() {
  group('canSplitLayout', () {
    test('rejects a phone in portrait', () {
      expect(canSplitLayout(412, 915), isFalse); // Pixel 8, portrait
      expect(canSplitLayout(360, 800), isFalse); // a small Android phone
    });

    test('rejects a phone in landscape on the height floor', () {
      // 915 x 412 clears the width floor and the aspect test, and fails only
      // because two panes cannot share 412 logical pixels of height.
      expect(canSplitLayout(915, 412), isFalse);
    });

    test('accepts an unfolded foldable in portrait when it is near square', () {
      expect(canSplitLayout(716, 750), isTrue); // Galaxy Z Fold 7, portrait
      expect(canSplitLayout(820, 859), isTrue); // Fold 8 Ultra, portrait
      expect(canSplitLayout(755, 791), isTrue); // Pixel 10 Pro Fold, portrait
    });

    test(
      'rejects a Galaxy Z Fold 8 in portrait and accepts it in landscape',
      () {
        // The reason the rule is not a plain width breakpoint: one device, one
        // width, two answers. Its 4:3 inner panel is 0.755 held in portrait.
        expect(canSplitLayout(704, 933), isFalse);
        expect(canSplitLayout(933, 704), isTrue);
      },
    );

    test('rejects a tablet in portrait, by design', () {
      // A 4:3 tablet in portrait is 0.75. "My tablet does not split in
      // portrait" is the rule working, not a bug.
      expect(canSplitLayout(768, 1024), isFalse);
      expect(canSplitLayout(800, 1280), isFalse); // 16:10, portrait
      expect(canSplitLayout(1280, 800), isTrue); // and both split in landscape
    });

    test('checks each threshold at n - 1 and n', () {
      // Held at a square-ish height, so only the width floor decides. At
      // 1000 tall, 600 wide is 0.6 and the aspect test would reject it first.
      expect(canSplitLayout(splitMinWidth - 1, 600), isFalse);
      expect(canSplitLayout(splitMinWidth, 600), isTrue);
      expect(canSplitLayout(1000, splitMinHeight - 1), isFalse);
      expect(canSplitLayout(1000, splitMinHeight), isTrue);
      // Exactly at the aspect threshold, and just under it.
      expect(canSplitLayout(splitMinAspect * 1000, 1000), isTrue);
      expect(canSplitLayout(splitMinAspect * 1000 - 1, 1000), isFalse);
    });

    test('a zero or negative height never splits', () {
      expect(canSplitLayout(1000, 0), isFalse);
      expect(canSplitLayout(1000, -10), isFalse);
    });
  });

  group('useNavigationRail', () {
    test('is width only, and disagrees with the split rule where it should', () {
      // The case Rule B exists for: a phone in landscape earns a rail although
      // it must not split.
      expect(useNavigationRail(915), isTrue);
      expect(canSplitLayout(915, 412), isFalse);
    });

    test('checks the threshold at n - 1 and n', () {
      expect(useNavigationRail(navRailMinWidth - 1), isFalse);
      expect(useNavigationRail(navRailMinWidth), isTrue);
    });
  });

  group('shellContentWidth and shellListBottomInset', () {
    test('subtracts the rail only when there is one', () {
      expect(shellContentWidth(412), 412); // phone: bottom bar, full width
      expect(shellContentWidth(1280), 1280 - navRailWidth);
    });

    test('never returns a negative width', () {
      expect(shellContentWidth(0), 0);
      expect(shellContentWidth(-100), 0);
    });

    test('reserves bar room only when a bar is shown', () {
      expect(shellListBottomInset(412), 80.0);
      expect(shellListBottomInset(1280), 16.0);
    });
  });

  group('columnCapacity', () {
    test('pays for the gaps between columns, not after every one', () {
      // Two 320-wide columns and one 12 gap need 652, not 664.
      expect(columnCapacity(652, minItemWidth: 320), 2);
      expect(columnCapacity(651, minItemWidth: 320), 1);
    });

    test('clamps to at least one column and at most the ceiling', () {
      expect(columnCapacity(0, minItemWidth: 320), 1);
      expect(columnCapacity(100, minItemWidth: 320), 1);
      expect(columnCapacity(100000, minItemWidth: 320), listMaxColumns);
      expect(columnCapacity(100000, minItemWidth: 320, maxColumns: 2), 2);
    });
  });

  group('listRowCount', () {
    test('rounds a short last row up', () {
      expect(listRowCount(0, 3), 0);
      expect(listRowCount(1, 3), 1);
      expect(listRowCount(4, 3), 2);
      expect(listRowCount(6, 3), 2);
    });

    test('treats a nonsense column count as one column', () {
      expect(listRowCount(5, 0), 5);
    });
  });

  group('pane widths', () {
    test('the settings detail pane always clears its floor', () {
      for (var width = 600.0; width <= 2000.0; width += 1) {
        final left = settingsLeftPaneWidth(width);
        expect(
          width - left,
          greaterThanOrEqualTo(settingsRightPaneMinWidth),
          reason: 'the detail pane is squeezed at $width',
        );
      }
    });

    test('the job detail pane always clears its floor', () {
      for (var width = 600.0; width <= 2000.0; width += 1) {
        final list = jobsListPaneWidth(width);
        expect(
          width - list,
          greaterThanOrEqualTo(jobDetailPaneMinWidth),
          reason: 'the job detail pane is squeezed at $width',
        );
      }
    });

    test('the library editor pane always clears its floor', () {
      for (var width = 600.0; width <= 2000.0; width += 1) {
        final list = libraryListPaneWidth(width);
        expect(
          width - list,
          greaterThanOrEqualTo(libraryEditorPaneMinWidth),
          reason: 'the library editor is squeezed at $width',
        );
      }
    });

    test('list panes stay inside their clamps on a wide desktop window', () {
      expect(jobsListPaneWidth(3000), 420.0);
      expect(libraryListPaneWidth(3000), 440.0);
      expect(settingsLeftPaneWidth(3000), 440.0);
    });
  });

  group('useViewerSidebar', () {
    test('needs both the window shape and room for both blocks', () {
      // A Fold 7 in portrait passes the shape gate but has nowhere near the
      // 720 logical pixels the two blocks need together.
      expect(canSplitLayout(716, 750), isTrue);
      expect(useViewerSidebar(716, 750, 716), isFalse);

      // A Fold 8 in landscape passes both.
      expect(useViewerSidebar(933, 704, 933), isTrue);
    });

    test('a phone in landscape never gets the sidebar', () {
      expect(useViewerSidebar(915, 412, 915), isFalse);
    });

    test('checks the content-width threshold at n - 1 and n', () {
      const floor = viewerTranscriptMinWidth + viewerSidebarMinWidth;
      expect(useViewerSidebar(1280, 800, floor - 1), isFalse);
      expect(useViewerSidebar(1280, 800, floor), isTrue);
    });

    test('the transcript always clears its floor where the sidebar shows', () {
      for (var width = 600.0; width <= 2400.0; width += 1) {
        if (!useViewerSidebar(width, 900, width)) continue;
        expect(
          width - viewerSidebarWidth(width),
          greaterThanOrEqualTo(viewerTranscriptMinWidth),
          reason: 'the transcript is squeezed at $width',
        );
      }
    });
  });

  group('width-only packing rules', () {
    test('two job dropdowns share a row from 572 up', () {
      expect(useNewJobOptionRow(571), isFalse);
      expect(useNewJobOptionRow(572), isTrue);
      // Width only: a phone in landscape pairs them although it cannot split.
      expect(useNewJobOptionRow(915), isTrue);
      expect(canSplitLayout(915, 412), isFalse);
    });

    test('the wide player bar has its own threshold', () {
      expect(useWideAudioBar(519), isFalse);
      expect(useWideAudioBar(520), isTrue);
    });
  });

  group('page-named delegates', () {
    test('still agree with the rule they delegate to', () {
      // These exist so each page keeps its own vocabulary. Asserting the
      // agreement is what stops one of them drifting into its own rule.
      for (final size in const [
        [412.0, 915.0], // phone, portrait
        [915.0, 412.0], // phone, landscape
        [704.0, 933.0], // Fold 8, portrait
        [933.0, 704.0], // Fold 8, landscape
        [768.0, 1024.0], // tablet, portrait
        [1280.0, 800.0], // tablet, landscape
        [1000.0, 720.0], // the default desktop window
      ]) {
        final expected = canSplitLayout(size[0], size[1]);
        expect(useJobsTwoPane(size[0], size[1]), expected, reason: '$size');
        expect(useLibraryTwoPane(size[0], size[1]), expected, reason: '$size');
      }
    });
  });
}
