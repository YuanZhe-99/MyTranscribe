# lib/features/jobs/services/job_runner.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | Run transcription jobs, one at a time, and survive being |
| `const JobQueueState({this.active, this.queued = const [], this.finished});` | Create a queue state. |
| `JobRunner({` | Create the runner. |
| `Future<TranscriptionJob> create({` | Create a job for a recording. |
| `void enqueue(String jobId) {` | Put a job in the queue. |
| `Future<void> _markQueued(String jobId) async {` | Record that a job is waiting its turn. |
| `Future<void> restore() async {` | Re-queue jobs that were interrupted, and clear up after the ones |
| `Future<void> _sweepChunkAudio(List<TranscriptionJob> jobs) async {` | Delete split audio a finished job left behind. |
| `void cancel(String jobId) => _cancel(jobId, persist: true);` | Stop a job. |
| `void _cancel(String jobId, {required bool persist}) {` | Stop a job, optionally writing "cancelled" for one that was |
| `Future<void> _markCancelled(String jobId) async {` | Record that a waiting job was cancelled. |
| `Future<void> retryWithout(String jobId, {required bool diarize}) async {` | Run a job again with one feature turned off. |
| `Future<void> remove(String jobId) async {` | Delete a job and everything belonging to it. |
| `Future<void> rename(String jobId, String? title) async {` | Give a transcription a name of its own. |
| `Future<bool> discardAudio(String jobId) async {` | Remove a job's converted audio, keeping everything else. |
| `Future<int> discardAllAudio() async {` | Remove every finished transcription's converted audio at once. |
| `Future<void> _pump() async {` | Work through the queue. |
| `Future<void> _run(TranscriptionJob initial) async {` | Run one job from wherever it left off. |
| `Future<TranscriptionJob> _advance(TranscriptionJob initial) async {` | Take a job through every stage. |
| `Future<TranscriptionJob> _advanceLocal(` | Take a job whose model runs on the device through every stage. |
| `Future<MediaInfo?> _probe(` | Read the recording's duration and streams, once per job. |
| `Future<({TranscriptionJob job, File file})> _normalize(` | Make sure the job has its converted copy. |
| `Future<void> _writeRawReply(` | Keep one window's raw reply beside its audio. |
| `Future<TranscriptionJob> _finish(` | Join, name, render and finish a job whose windows are all in. |
| `List<MergedSegment> _merge(TranscriptionJob job, ChunkPlan plan) {` | Join the finished windows into one transcript. |
| `Future<List<KnownSpeaker>> _enrol(` | Cut a short clip of each speaker heard so far, to send with the |
| `Map<String, String> _unifySpeakers(TranscriptionJob job) {` | Join each window's speaker labels into speakers that mean the |
| `Future<List<String>> _writeOutputs(` | Write the Markdown and text transcripts. |
| `Future<TranscriptionJob> _write(TranscriptionJob job) async {` | Write a job, applying anything renamed since it was read. |
| `Future<TranscriptionJob> _save(TranscriptionJob job) async {` | Save a job and publish it. |
| `Future<void> _saveBestEffort(TranscriptionJob job) async {` | Save a job's final state without letting a failed write escape. |
| `void _publish() {` | Publish the queue without changing a job. |
| `void _bump() => revision.value++;` | Say that a job record on disk has changed. |
| `void _syncLater() {` | Tell sync that a transcription is worth sending. |
| `void _checkCancelled(TranscriptionJob job) {` | Stop the job when the user has asked to. |
| `JobError _planFailure(PlanFailure failure) => switch (failure) {` | Turn a planning failure into a job error. |
| `JobError _localFailure(LocalAsrException error) => JobError(` | Turn a local engine failure into a job error. |
| `JobError _requestFailure(TranscriptionException error) => JobError(` | Turn a request failure into a job error. |
