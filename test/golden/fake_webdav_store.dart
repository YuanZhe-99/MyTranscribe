/// Purpose: Stand in for a WebDAV server holding one file, for the keys
/// exchange to talk to.
/// Inputs: The requests the exchange makes.
/// Returns: Responses, and a record of what was asked.
/// Side effects: None outside itself.
/// Notes: Much smaller than the shared package's golden server, on purpose:
/// the exchange only ever does GET and conditional PUT on one file, and the
/// things worth testing are the ETag precondition and the fact that nothing is
/// sent at all when the address is refused. A test that had to configure a
/// whole WebDAV implementation to check that would be testing the wrong thing.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// A fake server holding the contents of one remote file.
class FakeWebDavStore extends http.BaseClient {
  /// What the server currently holds, or null when the file is not there.
  String? content;

  /// The entity tag of the current content.
  String etag;

  /// Every request method and path, in order.
  final List<String> requests = [];

  /// The bodies of every PUT, in order.
  final List<String> writes = [];

  /// The `If-Match` header of every PUT, in order; null when absent.
  final List<String?> ifMatch = [];

  /// The `If-None-Match` header of every PUT, in order; null when absent.
  final List<String?> ifNoneMatch = [];

  /// Set to have the next PUT refuse with a 412, as a second writer would.
  ///
  /// The one after it succeeds, which is what lets a test check the re-read and
  /// re-merge rather than only the refusal.
  bool refuseNextPut = false;

  /// Set to have every request fail at the transport, as a dropped connection
  /// would.
  bool offline = false;

  /// Purpose: Create the fake server.
  /// Inputs: The [content] it starts with, and its [etag].
  /// Returns: A new client.
  /// Side effects: None.
  /// Notes: None.
  FakeWebDavStore({this.content, this.etag = '"v1"'});

  /// Purpose: Answer one request.
  /// Inputs: [request].
  /// Returns: The response.
  /// Side effects: Records the request, and may replace [content].
  /// Notes: A PUT with an `If-Match` that does not match the current entity tag
  /// is refused with 412, which is the whole point of sending one.
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add('${request.method} ${request.url.path}');
    if (offline) throw http.ClientException('connection failed');

    switch (request.method) {
      case 'GET':
        if (content == null) return _response(404, '');
        return _response(200, content!, headers: {'etag': etag});

      case 'PUT':
        final body = request is http.Request ? request.body : '';
        ifMatch.add(request.headers['If-Match']);
        ifNoneMatch.add(request.headers['If-None-Match']);

        if (refuseNextPut) {
          refuseNextPut = false;
          return _response(412, '');
        }
        final condition = request.headers['If-Match'];
        if (condition != null && condition != etag) return _response(412, '');
        if (request.headers['If-None-Match'] == '*' && content != null) {
          return _response(412, '');
        }

        writes.add(body);
        content = body;
        etag = '"v${writes.length + 1}"';
        return _response(201, '');

      default:
        // PROPFIND and MKCOL, which the exchange never issues but the client
        // may on its own account.
        return _response(207, '');
    }
  }

  /// Purpose: Build a response.
  /// Inputs: The [status], the [body] and any [headers].
  /// Returns: A streamed response.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  http.StreamedResponse _response(
    int status,
    String body, {
    Map<String, String> headers = const {},
  }) => http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    status,
    headers: headers,
  );
}
