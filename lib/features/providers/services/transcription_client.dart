import 'package:http/http.dart' as http;
import 'package:myapps_ai_online/myapps_ai_online.dart' as shared;

import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'provider_dialect.dart';
import 'shared_online_adapter.dart';

const maxTranscriptionRetries = 2;
const retryDelays = [Duration(seconds: 2), Duration(seconds: 5)];
const maxHonouredRetryAfter = Duration(seconds: 60);

/// Application facade over shared online transcription.
class TranscriptionClient {
  final http.Client Function() clientFactory;
  final Future<void> Function(Duration) sleep;
  late final shared.OnlineTranscriptionClient _client;

  /// Purpose: Create transport. Inputs: clientFactory, sleep. Returns: Client.
  /// Side effects: None. Notes: Injectable for network regression tests.
  TranscriptionClient({
    http.Client Function()? clientFactory,
    Future<void> Function(Duration)? sleep,
  }) : clientFactory = clientFactory ?? http.Client.new,
       sleep = sleep ?? Future.delayed {
    _client = shared.OnlineTranscriptionClient(
      clientFactory: this.clientFactory,
      sleep: this.sleep,
    );
  }

  /// Purpose: Transcribe a window. Inputs: request, provider, model, key, duration.
  /// Returns: Transcript. Side effects: HTTP. Notes: Cancellation never retries.
  Future<TranscriptionResult> transcribe({
    required TranscriptionRequest request,
    required ProviderConfig provider,
    required ModelConfig model,
    required String? apiKey,
    required double windowSeconds,
  }) async {
    try {
      final result = await _client.transcribe(
        request: shared.OnlineTranscriptionRequest(
          audioPath: request.file.path,
          languages: request.languages,
          prompt: request.prompt,
          keywords: request.keywords,
          diarize: request.diarize,
          wantTimestamps: request.wantTimestamps,
          knownSpeakers: [
            for (final speaker in request.knownSpeakers)
              shared.OnlineKnownSpeaker(
                id: speaker.id,
                samplePath: speaker.sample.path,
              ),
          ],
        ),
        provider: onlineProvider(provider),
        model: onlineModel(model),
        apiKey: apiKey,
        audioSeconds: windowSeconds,
      );
      return TranscriptionResult(
        text: result.text,
        segments: [
          for (final segment in result.segments)
            RawSegment(
              startSeconds: segment.startSeconds,
              endSeconds: segment.endSeconds,
              text: segment.text,
              speaker: segment.speaker,
            ),
        ],
        hasRealTimestamps: result.hasRealTimestamps,
        hasSpeakers: result.hasSpeakers,
      );
    } on shared.OnlineTranscriptionException catch (error) {
      throw TranscriptionException(
        TranscriptionFailure.values.byName(error.kind.name),
        error.message ?? 'The request could not be completed.',
        statusCode: error.statusCode,
        retryAfter: error.retryAfter,
        rejectedFeature: error.rejectedFeature == null
            ? null
            : RejectedFeature.values.byName(error.rejectedFeature!.name),
      );
    }
  }

  /// Purpose: Stop the request. Inputs: None. Returns: None.
  /// Side effects: Aborts HTTP. Notes: No retry after cancellation.
  void cancel() => _client.cancel();
}
