/// Purpose: Send one window to a source and bring back its transcript.
/// Inputs: The request, the source, the model and the key.
/// Returns: A `TranscriptionResult`, or a typed failure.
/// Side effects: One or more HTTP requests.
/// Notes: The retry policy lives here rather than in the job runner, because
/// what is worth retrying is a property of the transport: a timeout or a 500
/// might work next time, a 401 never will. See
/// `doc/en-us/features/transcription-jobs.md`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'dialects.dart';
import 'provider_dialect.dart';
import 'response_parsers.dart';

/// How many times a retryable failure is tried again.
const maxTranscriptionRetries = 2;

/// How long to wait before each retry.
///
/// Two attempts, growing: long enough for a blip to pass, short enough that a
/// user watching a job does not think it has stalled.
const retryDelays = [Duration(seconds: 2), Duration(seconds: 5)];

/// The longest the app will wait when a server asks it to.
///
/// A rate limit sometimes comes back with a wait of many minutes. Honouring
/// that inside a job would look identical to a hang, so it is capped and the
/// job fails with the server's own message instead.
const maxHonouredRetryAfter = Duration(seconds: 60);

/// Sends transcription requests.
class TranscriptionClient {
  /// Builds the HTTP client, injectable for tests.
  final http.Client Function() clientFactory;

  /// Waits between retries, injectable so tests do not really sleep.
  final Future<void> Function(Duration) sleep;

  /// Purpose: Create a client.
  /// Inputs: Optional [clientFactory] and [sleep].
  /// Returns: A new client.
  /// Side effects: None.
  /// Notes: None.
  TranscriptionClient({
    http.Client Function()? clientFactory,
    Future<void> Function(Duration)? sleep,
  }) : clientFactory = clientFactory ?? http.Client.new,
       sleep = sleep ?? Future.delayed;

  /// The client in flight, so a cancel can abort it.
  http.Client? _inFlight;

  /// Purpose: Transcribe one window.
  /// Inputs: [request], [provider], [model], [apiKey], and the
  /// [windowSeconds] the audio covers.
  /// Returns: A [TranscriptionResult].
  /// Side effects: Network I/O.
  /// Notes: Retries only what is worth retrying, and only that many times. A
  /// rate limit honours the server's own delay up to a cap; beyond that the
  /// job fails and says why, because waiting ten minutes inside a request looks
  /// exactly like a hang.
  Future<TranscriptionResult> transcribe({
    required TranscriptionRequest request,
    required ProviderConfig provider,
    required ModelConfig model,
    required String? apiKey,
    required double windowSeconds,
  }) async {
    final handler = dialectHandler(provider.dialect);
    final format = handler.responseFormatFor(request, model);

    TranscriptionException? last;
    for (var attempt = 0; attempt <= maxTranscriptionRetries; attempt++) {
      if (attempt > 0) {
        final delay = last?.retryAfter ?? retryDelays[attempt - 1];
        await sleep(delay);
      }
      try {
        return await _send(
          handler: handler,
          request: request,
          provider: provider,
          model: model,
          apiKey: apiKey,
          format: format,
          windowSeconds: windowSeconds,
        );
      } on TranscriptionException catch (error) {
        if (!error.isRetryable) rethrow;
        last = error;
      }
    }
    throw last ??
        const TranscriptionException(
          TranscriptionFailure.network,
          'The request could not be completed.',
        );
  }

  /// Purpose: Abort whatever is in flight.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Closes the HTTP client, which fails the pending request.
  /// Notes: How a cancelled job stops an upload that has already started, which
  /// is the slowest part of a window and the one most worth interrupting.
  void cancel() {
    _inFlight?.close();
    _inFlight = null;
  }

  /// Purpose: Make one attempt.
  /// Inputs: Everything the attempt needs.
  /// Returns: A [TranscriptionResult].
  /// Side effects: One HTTP request.
  /// Notes: Internal helper used within this file only.
  Future<TranscriptionResult> _send({
    required ProviderDialectHandler handler,
    required TranscriptionRequest request,
    required ProviderConfig provider,
    required ModelConfig model,
    required String? apiKey,
    required String format,
    required double windowSeconds,
  }) async {
    final client = clientFactory();
    _inFlight = client;
    try {
      final built = await handler.buildRequest(
        request,
        provider,
        model,
        apiKey,
      );
      final streamed = await client
          .send(built)
          .timeout(Duration(seconds: provider.requestTimeoutSeconds));
      final body = utf8.decode(
        await streamed.stream.toBytes(),
        allowMalformed: true,
      );

      if (streamed.statusCode != 200) {
        throw _failureFor(streamed.statusCode, streamed.headers, body, request);
      }
      return parseTranscriptionBody(body, format, windowSeconds);
    } on TranscriptionException {
      rethrow;
    } on TimeoutException {
      throw TranscriptionException(
        TranscriptionFailure.network,
        'The source did not answer within '
        '${provider.requestTimeoutSeconds} seconds.',
      );
    } catch (error) {
      throw TranscriptionException(
        TranscriptionFailure.network,
        'The request could not be completed: $error',
      );
    } finally {
      if (identical(_inFlight, client)) _inFlight = null;
      client.close();
    }
  }

  /// Purpose: Turn an unsuccessful response into a typed failure.
  /// Inputs: The [status], the [headers], the [body] and the [request].
  /// Returns: A [TranscriptionException].
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The server's own
  /// message is carried through wherever there is one: it usually says exactly
  /// what is wrong — a bad key, a file too large, an unsupported parameter —
  /// and replacing it with "the request failed" throws that away.
  TranscriptionException _failureFor(
    int status,
    Map<String, String> headers,
    String body,
    TranscriptionRequest request,
  ) {
    final message = _serverMessage(body) ?? 'The source answered with $status.';

    if (status == 401 || status == 403) {
      return TranscriptionException(
        TranscriptionFailure.unauthorized,
        message,
        statusCode: status,
      );
    }
    if (status == 413) {
      return TranscriptionException(
        TranscriptionFailure.tooLarge,
        message,
        statusCode: status,
      );
    }
    if (status == 429) {
      return TranscriptionException(
        TranscriptionFailure.rateLimited,
        message,
        statusCode: status,
        retryAfter: _retryAfter(headers),
      );
    }
    if (status >= 500) {
      return TranscriptionException(
        TranscriptionFailure.serverError,
        message,
        statusCode: status,
      );
    }
    return TranscriptionException(
      TranscriptionFailure.rejected,
      message,
      statusCode: status,
      rejectedFeature: _rejectedFeature(message, request),
    );
  }

  /// Purpose: Read how long the server asked the caller to wait.
  /// Inputs: [headers].
  /// Returns: The delay, capped, or null when none was given.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Only the seconds form
  /// is read; the HTTP-date form is rare here and a wrong parse would be worse
  /// than falling back to the app's own delay.
  Duration? _retryAfter(Map<String, String> headers) {
    final value = headers['retry-after'];
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds == null || seconds <= 0) return null;
    final delay = Duration(seconds: seconds);
    return delay > maxHonouredRetryAfter ? maxHonouredRetryAfter : delay;
  }

  /// Purpose: Pull the human-readable message out of an error body.
  /// Inputs: [body].
  /// Returns: The message, or null.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. These services wrap it
  /// as `{"error": {"message": …}}`; a self-hosted one might send a bare
  /// string, which is used as-is when it is short enough to be a message rather
  /// than a page of HTML.
  String? _serverMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (error is String) return error;
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {
      // Not JSON; fall through to the plain-text case.
    }
    return trimmed.length <= 300 ? trimmed : null;
  }

  /// Purpose: Guess which feature a rejection was about.
  /// Inputs: The server's [message] and the [request].
  /// Returns: The feature, or null.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Only ever used to offer
  /// "run again without this" — never to change what is sent automatically. A
  /// wrong guess costs the user one dismissed suggestion; silently dropping a
  /// feature they asked for would cost them a transcript that is missing
  /// something and no explanation.
  RejectedFeature? _rejectedFeature(
    String message,
    TranscriptionRequest request,
  ) {
    final lower = message.toLowerCase();
    if (request.diarize &&
        (lower.contains('diariz') ||
            lower.contains('speaker') ||
            lower.contains('chunking_strategy'))) {
      return RejectedFeature.diarization;
    }
    if (request.keywords.isNotEmpty && lower.contains('keyword')) {
      return RejectedFeature.keywords;
    }
    if (lower.contains('timestamp') || lower.contains('verbose_json')) {
      return RejectedFeature.timestamps;
    }
    if ((request.prompt?.isNotEmpty ?? false) && lower.contains('prompt')) {
      return RejectedFeature.prompt;
    }
    return null;
  }
}
