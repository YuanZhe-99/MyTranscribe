/// Purpose: Read, correct, search, play and export one transcript.
/// Inputs: A job id; the transcript beside it on disk.
/// Returns: A full-window page.
/// Side effects: Plays audio, writes the transcript back, writes export files.
/// Notes: A full-window route with no navigation rail, which is why its split
/// uses the double gate in `adaptive_layout.dart` rather than the shell's. The
/// two views are deliberate: the flowing one is for reading, the per-line one
/// is for correcting, and neither does both well. See
/// `doc/en-us/features/transcript-viewer.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/transcribe_storage.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../jobs/models/transcription_job.dart';
import '../../jobs/services/job_providers.dart';
import '../../jobs/services/job_store.dart';
import '../models/transcript.dart';
import '../services/export_formatters.dart';
import '../services/speaker_palette.dart';
import '../services/transcript_exporter.dart';
import '../services/transcript_providers.dart';
import '../services/transcript_search.dart';
import '../services/transcript_store.dart';
import '../widgets/audio_player_bar.dart';
import '../widgets/segment_edit_sheet.dart';
import '../widgets/speakers_panel.dart';
import '../widgets/viewer_options_panel.dart';

class TranscriptViewerPage extends ConsumerStatefulWidget {
  /// Which job's transcript to show.
  final String jobId;

  /// Purpose: Create the viewer.
  /// Inputs: [jobId].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptViewerPage({super.key, required this.jobId});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<TranscriptViewerPage> createState() =>
      _TranscriptViewerPageState();
}

class _TranscriptViewerPageState extends ConsumerState<TranscriptViewerPage> {
  final _player = AudioPlayerService();
  final _scroll = ScrollController();
  final _search = TextEditingController();

  /// The user's own edits, once they have made one.
  ///
  /// Null means "whatever is on disk". Holding the edited copy here rather than
  /// re-reading the file means a correction appears the instant it is made,
  /// while the write happens behind it.
  Transcript? _edited;

  /// The view options, seeded from the device's preferences on the first build.
  ViewerMode _mode = ViewerMode.transcript;
  bool _group = true;
  bool _showTimes = true;
  bool _follow = true;
  double _fontSize = 16;

  /// Whether the options have been seeded yet.
  bool _seeded = false;

  /// Whether the audio has been handed to the player yet.
  bool _audioRequested = false;

  /// Attached to whichever line is being played, so it can be scrolled to.
  final _playingKey = GlobalKey();

  /// Which line was last scrolled to, so it is not scrolled to repeatedly.
  ///
  /// Without this the page would fight the user for the scroll position on
  /// every position event, several times a second.
  Object? _followedLine;

  /// What is being searched for, and which hit is current.
  String _query = '';
  int _hitIndex = 0;
  bool _searching = false;

  /// Purpose: Release the player, the scroll controller and the search field.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees the audio device.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _player.dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Purpose: Hand the converted audio to the player, once.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Opens an audio device when the file is there.
  /// Notes: Internal helper used within this file only. A missing audio file is
  /// not an error: a transcript whose recording has been deleted is still worth
  /// reading, and the bar says there is nothing to play. Nothing on this page
  /// waits for it, which is why it is fire-and-forget.
  Future<void> _loadAudio() async {
    final audio = await JobStore.normalizedAudio(widget.jobId);
    if (audio.existsSync()) await _player.load(audio.path);
  }

  /// Purpose: Name one speaker.
  /// Inputs: The [transcript], the [speakerId] and the [l10n].
  /// Returns: The name, or null when nobody is identified.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Passed into the export
  /// formatters, so a file says exactly what the screen says.
  String? _nameOf(
    Transcript transcript,
    String? speakerId,
    AppLocalizations l10n,
  ) {
    final speaker = transcript.speaker(speakerId);
    if (speaker == null) return null;
    return speaker.displayName(l10n.viewerSpeakerFallback);
  }

  /// Purpose: Bring the line being played into view.
  /// Inputs: Which [line] is playing, identified however the current view
  /// identifies one.
  /// Returns: None.
  /// Side effects: Scrolls the list after the frame is laid out.
  /// Notes: Internal helper used within this file only. Only when the line has
  /// actually changed, and only when the user asked to follow: scrolling the
  /// page under somebody who is reading ahead is the fastest way to make a
  /// feature feel broken.
  void _followPlayback(Object? line) {
    if (!_follow || line == null || line == _followedLine) return;
    _followedLine = line;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _playingKey.currentContext;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Purpose: Write the transcript back after an edit.
  /// Inputs: The [next] transcript.
  /// Returns: None.
  /// Side effects: Writes `transcript.json`.
  /// Notes: Internal helper used within this file only. Saved immediately
  /// rather than on leaving the page: a correction the user made and then lost
  /// to a crash is worse than a file written a few times too often.
  Future<void> _save(Transcript next) async {
    final stamped = next.copyWith(editedAt: DateTime.now().toUtc());
    setState(() => _edited = stamped);
    await TranscriptStore.save(stamped);
  }

  /// Purpose: Build the page.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    final contentWidth = screen.width;
    final sidebar = useViewerSidebar(screen.width, screen.height, contentWidth);

    final stored = ref.watch(transcriptProvider(widget.jobId));
    final job = ref.watch(jobProvider(widget.jobId)).value;
    final preferences = ref.watch(viewerPreferencesProvider).value;

    if (preferences != null && !_seeded) {
      _seeded = true;
      _mode = preferences.mode;
      _group = preferences.group;
      _showTimes = preferences.showTimes;
      _follow = preferences.follow;
      _fontSize = preferences.fontSize;
    }

    if (!_audioRequested) {
      _audioRequested = true;
      _loadAudio();
    }

    // Riverpod 1.x has no hasValue; an AsyncData carrying null means the job
    // genuinely has no transcript, which is not the same as still reading.
    if (_edited == null && stored is! AsyncData<Transcript?>) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final transcript = _edited ?? stored.value;
    if (transcript == null || transcript.segments.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(job?.sourceName ?? '')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.viewerEmpty, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final hits = findInTranscript(transcript, _query);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.viewerSearchHint,
                ),
                onChanged: (value) => setState(() {
                  _query = value;
                  _hitIndex = 0;
                }),
              )
            : Text(
                job?.sourceName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (_searching)
            ..._searchActions(l10n, transcript, hits)
          else ...[
            IconButton(
              tooltip: l10n.viewerSearchHint,
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
            IconButton(
              tooltip: l10n.viewerCopyAll,
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () => _copyAll(l10n, transcript),
            ),
            _exportButton(l10n, transcript, job),
            if (!sidebar) ...[
              IconButton(
                tooltip: l10n.viewerSpeakers,
                icon: const Icon(Icons.record_voice_over_outlined),
                onPressed: transcript.hasSpeakers
                    ? () => _showSheet(_speakersPanel(l10n, transcript))
                    : null,
              ),
              IconButton(
                tooltip: l10n.viewerOptions,
                icon: const Icon(Icons.tune),
                onPressed: () => _showSheet(
                  _optionsPanel(l10n, hasSpeakers: transcript.hasSpeakers),
                ),
              ),
            ],
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: sidebar
                ? Row(
                    children: [
                      Expanded(child: _body(l10n, transcript, hits)),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: viewerSidebarWidth(contentWidth),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _optionsPanel(
                              l10n,
                              hasSpeakers: transcript.hasSpeakers,
                            ),
                            if (transcript.hasSpeakers) ...[
                              const SizedBox(height: 24),
                              _speakersPanel(l10n, transcript),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : _body(l10n, transcript, hits),
          ),
          AudioPlayerBar(player: _player, wide: useWideAudioBar(contentWidth)),
        ],
      ),
    );
  }

  /// Purpose: Build the search navigation buttons.
  /// Inputs: [l10n] and the [hits].
  /// Returns: The action widgets.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The count is shown
  /// rather than only the arrows, because "no matches" and "one match you are
  /// already on" look identical otherwise.
  List<Widget> _searchActions(
    AppLocalizations l10n,
    Transcript transcript,
    List<SearchHit> hits,
  ) => [
    Center(
      child: Text(
        hits.isEmpty
            ? l10n.viewerNoResults
            : l10n.viewerSearchCount(_hitIndex + 1, hits.length),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    ),
    IconButton(
      icon: const Icon(Icons.keyboard_arrow_up),
      onPressed: hits.isEmpty
          ? null
          : () => _jumpToHit(transcript, hits, (_hitIndex - 1) % hits.length),
    ),
    IconButton(
      icon: const Icon(Icons.keyboard_arrow_down),
      onPressed: hits.isEmpty
          ? null
          : () => _jumpToHit(transcript, hits, (_hitIndex + 1) % hits.length),
    ),
    IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => setState(() {
        _searching = false;
        _query = '';
        _search.clear();
      }),
    ),
  ];

  /// Purpose: Move to one search hit.
  /// Inputs: The [hits] and which [index] to go to.
  /// Returns: None.
  /// Side effects: Seeks the audio and rebuilds.
  /// Notes: Internal helper used within this file only. The audio follows the
  /// search, so finding a phrase and hearing it are one action rather than two.
  void _jumpToHit(Transcript transcript, List<SearchHit> hits, int index) {
    setState(() => _hitIndex = index);
    _player.seek(transcript.segments[hits[index].segmentIndex].startSeconds);
  }

  /// Purpose: Build the reading or correcting view.
  /// Inputs: [l10n], the [transcript] and the current [hits].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _body(
    AppLocalizations l10n,
    Transcript transcript,
    List<SearchHit> hits,
  ) {
    final current = hits.isEmpty || _hitIndex >= hits.length
        ? null
        : hits[_hitIndex].segmentIndex;

    return ValueListenableBuilder<PlaybackState>(
      valueListenable: _player.state,
      builder: (context, playback, _) {
        final at = playback.positionSeconds;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: viewerContentMaxWidth),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (!transcript.hasTimestamps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      l10n.viewerApproximate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (_mode == ViewerMode.transcript &&
                    _group &&
                    transcript.hasSpeakers)
                  ..._paragraphs(l10n, transcript, at)
                else
                  ..._lines(l10n, transcript, at, current),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Purpose: Build the grouped, flowing view.
  /// Inputs: [l10n], the [transcript], and where playback is [at].
  /// Returns: The paragraphs.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Grouping only means
  /// anything when there are speakers to group by, which is why the caller
  /// checks that before choosing this.
  List<Widget> _paragraphs(
    AppLocalizations l10n,
    Transcript transcript,
    double at,
  ) {
    final runs = groupBySpeaker(
      transcript,
      (id) => _nameOf(transcript, id, l10n),
    );
    final palette = Theme.of(context).brightness;
    final playingRun = runs.indexWhere(
      (run) => run.startSeconds <= at && at < run.endSeconds,
    );
    _followPlayback(playingRun < 0 ? null : 'run:$playingRun');

    return [
      for (var runIndex = 0; runIndex < runs.length; runIndex++)
        Builder(
          key: runIndex == playingRun ? _playingKey : null,
          builder: (context) {
            final run = runs[runIndex];
            final speakerIndex = transcript.speakers.indexWhere(
              (s) => s.displayName(l10n.viewerSpeakerFallback) == run.speaker,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (run.speaker != null)
                        Text(
                          run.speaker!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: _fontSize,
                            color: speakerColor(
                              speakerIndex < 0
                                  ? 0
                                  : transcript
                                        .speakers[speakerIndex]
                                        .colorIndex,
                              palette,
                            ),
                          ),
                        ),
                      if (_showTimes) ...[
                        const SizedBox(width: 8),
                        _timeChip(transcript, run.startSeconds),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  _highlighted(run.text, _fontSize, runIndex == playingRun),
                ],
              ),
            );
          },
        ),
    ];
  }

  /// Purpose: Build the per-line view.
  /// Inputs: [l10n], the [transcript], where playback is [at], and which line
  /// the search is [current]ly on.
  /// Returns: The rows.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Tapping a row plays
  /// from it, which is what makes correcting a transcript bearable: you hear
  /// the line you are fixing without hunting for it.
  List<Widget> _lines(
    AppLocalizations l10n,
    Transcript transcript,
    double at,
    int? current,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final playingLine = transcript.segments.indexWhere(
      (segment) => segment.startSeconds <= at && at < segment.endSeconds,
    );
    _followPlayback(playingLine < 0 ? null : 'line:$playingLine');

    return [
      for (var index = 0; index < transcript.segments.length; index++)
        Builder(
          key: index == playingLine ? _playingKey : null,
          builder: (context) {
            final segment = transcript.segments[index];
            final playing = index == playingLine;
            final speaker = transcript.speaker(segment.speakerId);

            return InkWell(
              onTap: () => _player.seek(segment.startSeconds),
              onLongPress: () => _editSegment(l10n, transcript, segment),
              child: Container(
                width: double.infinity,
                color: index == current
                    ? scheme.tertiaryContainer.withValues(alpha: 0.5)
                    : (playing ? scheme.surfaceContainerHighest : null),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_showTimes)
                          _timeChip(transcript, segment.startSeconds),
                        if (speaker != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            speaker.displayName(l10n.viewerSpeakerFallback),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: speakerColor(
                                speaker.colorIndex,
                                Theme.of(context).brightness,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          tooltip: l10n.viewerEditSegment,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () =>
                              _editSegment(l10n, transcript, segment),
                        ),
                      ],
                    ),
                    _highlighted(segment.text, _fontSize, playing),
                  ],
                ),
              ),
            );
          },
        ),
    ];
  }

  /// Purpose: Draw text with the search matches marked.
  /// Inputs: The [text], the [size], and whether it is [playing].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _highlighted(String text, double size, bool playing) {
    final scheme = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontSize: size,
      height: 1.5,
      fontWeight: playing ? FontWeight.w600 : null,
    );
    if (_query.trim().isEmpty) return Text(text, style: base);

    return Text.rich(
      TextSpan(
        children: [
          for (final part in highlightParts(text, _query))
            TextSpan(
              text: part.$1,
              style: part.$2
                  ? base.copyWith(
                      backgroundColor: scheme.tertiaryContainer,
                      color: scheme.onTertiaryContainer,
                    )
                  : base,
            ),
        ],
      ),
    );
  }

  /// Purpose: Draw one timestamp.
  /// Inputs: [seconds].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. An estimated time is
  /// prefixed, so nobody quotes it as exact.
  Widget _timeChip(Transcript transcript, double seconds) {
    final estimated = !transcript.hasTimestamps;
    return Text(
      '${estimated ? '≈ ' : ''}${readableTimestamp(seconds)}',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  /// Purpose: Open the editor for one line.
  /// Inputs: [l10n], the [transcript] and the [segment].
  /// Returns: None.
  /// Side effects: Saves the transcript when something changed.
  /// Notes: Internal helper used within this file only.
  Future<void> _editSegment(
    AppLocalizations l10n,
    Transcript transcript,
    TranscriptSegment segment,
  ) async {
    final result = await showSegmentEditSheet(
      context,
      segment: segment,
      speakers: transcript.speakers,
      nameOf: (id) => _nameOf(transcript, id, l10n),
    );
    if (result == null) return;

    await _save(
      transcript.copyWith(
        segments: [
          for (final existing in transcript.segments)
            if (existing.id == segment.id)
              existing.copyWith(
                text: result.text,
                speakerId: result.speakerId,
                clearSpeaker: result.speakerId == null,
                editedAt: DateTime.now().toUtc(),
              )
            else
              existing,
        ],
      ),
    );
  }

  /// Purpose: Build the view-options panel.
  /// Inputs: [l10n].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Every change is written
  /// to the device preferences straight away, so the next transcript opens the
  /// way the last one was left.
  Widget _optionsPanel(AppLocalizations l10n, {required bool hasSpeakers}) =>
      ViewerOptionsPanel(
        mode: _mode,
        group: _group,
        showTimes: _showTimes,
        follow: _follow,
        fontSize: _fontSize,
        hasSpeakers: hasSpeakers,
        onMode: (mode) {
          setState(() => _mode = mode);
          TranscribeStorage.setViewerMode(mode.name);
        },
        onGroup: (group) {
          setState(() => _group = group);
          TranscribeStorage.setViewerGroupSpeakers(group);
        },
        onTimes: (show) {
          setState(() => _showTimes = show);
          TranscribeStorage.setViewerShowTimestamps(show);
        },
        onFollow: (follow) {
          setState(() => _follow = follow);
          TranscribeStorage.setViewerAutoScroll(follow);
        },
        onFontSize: (size) {
          setState(() => _fontSize = size);
          TranscribeStorage.setViewerFontSize(size.round());
        },
      );

  /// Purpose: Build the speakers panel.
  /// Inputs: [l10n] and the [transcript].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _speakersPanel(AppLocalizations l10n, Transcript transcript) =>
      SpeakersPanel(
        transcript: transcript,
        onRename: (speakerId, name) => _save(
          transcript.copyWith(
            speakers: [
              for (final speaker in transcript.speakers)
                if (speaker.id == speakerId)
                  speaker.copyWith(name: name, clearName: name.trim().isEmpty)
                else
                  speaker,
            ],
          ),
        ),
      );

  /// Purpose: Show a panel as a sheet on a narrow window.
  /// Inputs: The [child].
  /// Returns: None.
  /// Side effects: Opens a modal sheet.
  /// Notes: Internal helper used within this file only. The same panel widget
  /// as the sidebar's, so a phone and a desktop offer the same controls.
  void _showSheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [child],
        ),
      ),
    );
  }

  /// Purpose: Copy the whole transcript.
  /// Inputs: [l10n] and the [transcript].
  /// Returns: None.
  /// Side effects: Writes to the clipboard.
  /// Notes: Internal helper used within this file only. Copies what the reader
  /// sees — grouped and named — rather than the raw segments.
  Future<void> _copyAll(AppLocalizations l10n, Transcript transcript) async {
    await Clipboard.setData(
      ClipboardData(
        text: renderTxt(transcript, (id) => _nameOf(transcript, id, l10n)),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.viewerCopied)));
  }

  /// Purpose: Build the export menu.
  /// Inputs: [l10n] and the [transcript].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A format that would be
  /// wrong is shown disabled with the reason rather than hidden: hiding it
  /// leaves the user hunting for a subtitle option that is not there.
  Widget _exportButton(
    AppLocalizations l10n,
    Transcript transcript,
    TranscriptionJob? job,
  ) => PopupMenuButton<ExportFormat>(
    tooltip: l10n.viewerExport,
    icon: const Icon(Icons.ios_share),
    onSelected: (format) => _export(l10n, transcript, job, format),
    itemBuilder: (context) => [
      for (final format in ExportFormat.values)
        PopupMenuItem(
          value: format,
          enabled: !format.needsRealTimestamps || transcript.hasTimestamps,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(format.extension.toUpperCase()),
              if (format.needsRealTimestamps && !transcript.hasTimestamps)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    l10n.viewerExportNeedsTimes,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
    ],
  );

  /// Purpose: Write the transcript out in one format.
  /// Inputs: [l10n], the [transcript] and the [format].
  /// Returns: None.
  /// Side effects: Writes a file, and opens a save or share dialog.
  /// Notes: Internal helper used within this file only.
  Future<void> _export(
    AppLocalizations l10n,
    Transcript transcript,
    TranscriptionJob? job,
    ExportFormat format,
  ) async {
    final name = await TranscriptExporter.export(
      transcript: transcript,
      format: format,
      sourceName: job?.sourceName ?? 'transcript',
      modelName: job?.modelName ?? '',
      nameOf: (id) => _nameOf(transcript, id, l10n),
    );
    if (!mounted || name == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.viewerExportSaved(name))));
  }
}
