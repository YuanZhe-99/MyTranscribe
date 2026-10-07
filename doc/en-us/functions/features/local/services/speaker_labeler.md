# lib/features/local/services/speaker_labeler.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `List<RawSegment> labelSegments(` | Attach window-local labels. Inputs: segments, turns. Returns: Segments. |
| `SpeakerLabeler({required this.artifacts}) {` | Create a labeler. Inputs: artifacts. Returns: Labeler. |
| `Future<bool> available() async =>` | Check package presence. Inputs: None. Returns: Presence. |
| `Future<List<RawSegment>> label(File pcm, List<RawSegment> segments) async {` | Label a window. Inputs: pcm, segments. Returns: Labeled segments. |
