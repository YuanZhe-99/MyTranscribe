/// Purpose: Stand in for a transcription service, and record exactly what was
/// sent to it.
/// Inputs: The requests the app makes.
/// Returns: Canned replies, and a transcript of every request for assertions.
/// Side effects: None outside the test.
/// Notes: A double rather than a real server: what these tests need to check is
/// the *shape* of a request — which fields, in which encoding, with which
/// values — and a real endpoint would answer that question slowly, only with a
/// key, and differently on different days.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// One request the app made, taken apart.
class RecordedRequest {
  /// Where it was sent.
  final Uri url;

  /// Its headers.
  final Map<String, String> headers;

  /// The multipart fields, when it was a multipart request.
  ///
  /// A repeated field name — the way a list is sent in multipart — keeps every
  /// value, because whether a list arrived as a list is exactly what some of
  /// these tests are about.
  final Map<String, List<String>> fields;

  /// The names of the files it carried.
  final Map<String, String> fileNames;

  /// The decoded JSON body, when it was a JSON request.
  final Map<String, dynamic>? json;

  /// Purpose: Create a recorded request.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const RecordedRequest({
    required this.url,
    required this.headers,
    this.fields = const {},
    this.fileNames = const {},
    this.json,
  });

  /// Whether the request carried a JSON body rather than multipart.
  bool get isJson => json != null;

  /// Purpose: Read one field's only value.
  /// Inputs: [name].
  /// Returns: The value, or null when the field was absent.
  /// Side effects: None.
  /// Notes: For the fields that are sent once. Use [valuesOf] for a list.
  String? field(String name) {
    final values = fields[name];
    return values == null || values.isEmpty ? null : values.first;
  }

  /// Purpose: Read every value sent under one field name.
  /// Inputs: [name].
  /// Returns: The values, in order.
  /// Side effects: None.
  /// Notes: None.
  List<String> valuesOf(String name) => fields[name] ?? const [];
}

/// What the fake server should answer with.
class FakeReply {
  /// The HTTP status.
  final int statusCode;

  /// The body.
  final String body;

  /// Extra response headers.
  final Map<String, String> headers;

  /// Purpose: Create a reply.
  /// Inputs: [body], [statusCode], [headers].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const FakeReply(this.body, {this.statusCode = 200, this.headers = const {}});

  /// Purpose: A plain successful transcript.
  /// Inputs: [text].
  /// Returns: A reply in the simple JSON shape.
  /// Side effects: None.
  /// Notes: None.
  factory FakeReply.text(String text) => FakeReply(jsonEncode({'text': text}));

  /// Purpose: A transcript with times.
  /// Inputs: [segments] as `(start, end, text)` triples.
  /// Returns: A reply in the verbose shape.
  /// Side effects: None.
  /// Notes: None.
  factory FakeReply.timed(List<(double, double, String)> segments) => FakeReply(
    jsonEncode({
      'text': segments.map((s) => s.$3).join(' '),
      'segments': [
        for (final (start, end, text) in segments)
          {'start': start, 'end': end, 'text': text},
      ],
    }),
  );

  /// Purpose: A transcript with speakers.
  /// Inputs: [segments] as `(start, end, speaker, text)` quads.
  /// Returns: A reply in the diarized shape.
  /// Side effects: None.
  /// Notes: None.
  factory FakeReply.diarized(List<(double, double, String, String)> segments) =>
      FakeReply(
        jsonEncode({
          'text': segments.map((s) => s.$4).join(' '),
          'segments': [
            for (final (start, end, speaker, text) in segments)
              {'start': start, 'end': end, 'speaker': speaker, 'text': text},
          ],
        }),
      );

  /// Purpose: A refusal, in the shape these services use.
  /// Inputs: [status], [message].
  /// Returns: A reply.
  /// Side effects: None.
  /// Notes: None.
  factory FakeReply.error(int status, String message) => FakeReply(
    jsonEncode({
      'error': {'message': message},
    }),
    statusCode: status,
  );
}

/// An HTTP client that answers as a transcription service would.
class FakeTranscriptionServer extends http.BaseClient {
  /// The replies to give, in order; the last is repeated once exhausted.
  final List<FakeReply> replies;

  /// Every request that was made, in order.
  final List<RecordedRequest> requests = [];

  /// How many requests have been answered.
  int _served = 0;

  /// Purpose: Create the fake server.
  /// Inputs: [replies].
  /// Returns: A new client.
  /// Side effects: None.
  /// Notes: Repeating the last reply means a test about a ten-window job does
  /// not have to list ten identical answers.
  FakeTranscriptionServer(this.replies);

  /// Purpose: Answer one request, recording it first.
  /// Inputs: [request].
  /// Returns: The next canned reply.
  /// Side effects: Appends to [requests].
  /// Notes: Multipart and JSON are both taken apart here, so a test can assert
  /// on either without knowing which the dialect chose.
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(await _record(request));
    final reply = replies.isEmpty
        ? const FakeReply('{}')
        : replies[_served.clamp(0, replies.length - 1)];
    _served++;
    return http.StreamedResponse(
      Stream.value(utf8.encode(reply.body)),
      reply.statusCode,
      headers: reply.headers,
      request: request,
    );
  }

  /// Purpose: Take one request apart.
  /// Inputs: [request].
  /// Returns: A [RecordedRequest].
  /// Side effects: Reads the request body.
  /// Notes: Internal helper used within this file only.
  Future<RecordedRequest> _record(http.BaseRequest request) async {
    if (request is http.MultipartRequest) {
      final fields = <String, List<String>>{};
      for (final entry in request.fields.entries) {
        fields.putIfAbsent(entry.key, () => []).add(entry.value);
      }
      final fileNames = <String, String>{};
      for (final file in request.files) {
        if (file.filename == null) {
          // A list value sent as a part rather than a field: multipart has no
          // other way to repeat a name, and the app uses it for `languages[]`
          // and `keywords[]`.
          final bytes = await file.finalize().toBytes();
          fields.putIfAbsent(file.field, () => []).add(utf8.decode(bytes));
        } else {
          fileNames[file.field] = file.filename!;
        }
      }
      return RecordedRequest(
        url: request.url,
        headers: Map.of(request.headers),
        fields: fields,
        fileNames: fileNames,
      );
    }

    if (request is http.Request) {
      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(request.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        // Not JSON; leave it null and let the test say so.
      }
      return RecordedRequest(
        url: request.url,
        headers: Map.of(request.headers),
        json: json,
      );
    }

    return RecordedRequest(url: request.url, headers: Map.of(request.headers));
  }
}
