/// Purpose: Stand in for a WebDAV server, for the two app-level side channels
/// to talk to.
/// Inputs: The requests those exchanges make.
/// Returns: Responses, and a record of what was asked.
/// Side effects: None outside itself.
/// Notes: Much smaller than the shared package's golden server, on purpose. The
/// keys exchange only ever does GET and conditional PUT on one file, and the
/// audio exchange only lists a folder and moves whole files in and out of it. A
/// test that had to configure a whole WebDAV implementation to check an ETag
/// precondition would be testing the wrong thing.
///
/// [content] and [etag] are the keys file, kept as a special case because the
/// conditional PUT is exactly what those tests are about. Everything else lives
/// in [files], keyed by the path under the remote directory.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// A fake server holding the contents of one remote file, plus a folder.
class FakeWebDavStore extends http.BaseClient {
  /// What the server currently holds for the keys file, or null when absent.
  String? content;

  /// The entity tag of that content.
  String etag;

  /// Everything else on the server, keyed by path relative to the remote root.
  ///
  /// The audio exchange only deals in whole binary files, so these are bytes.
  final Map<String, Uint8List> files = {};

  /// Collections that have been created with MKCOL, in order.
  final List<String> collections = [];

  /// Every request method and path, in order.
  final List<String> requests = [];

  /// The bodies of every PUT to the keys file, in order.
  final List<String> writes = [];

  /// The paths of every DELETE, in order.
  final List<String> deletes = [];

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

  /// Set to have PROPFIND fail, so a listing comes back unknown.
  bool refuseListing = false;

  /// Set to have every binary PUT fail, as a server out of space would.
  bool refuseUploads = false;

  /// Purpose: Create the fake server.
  /// Inputs: The [content] it starts with, and its [etag].
  /// Returns: A new client.
  /// Side effects: None.
  /// Notes: None.
  FakeWebDavStore({this.content, this.etag = '"v1"'});

  /// Purpose: Answer one request.
  /// Inputs: [request].
  /// Returns: The response.
  /// Side effects: Records the request, and may replace stored content.
  /// Notes: A PUT with an `If-Match` that does not match the current entity tag
  /// is refused with 412, which is the whole point of sending one. Anything
  /// whose path names a subdirectory is treated as a binary file in [files].
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    requests.add('${request.method} $path');
    if (offline) throw http.ClientException('connection failed');

    final segments = [
      for (final segment in path.split('/'))
        if (segment.isNotEmpty) segment,
    ];
    final last = segments.isEmpty ? '' : segments.last;
    final parent = segments.length < 2 ? '' : segments[segments.length - 2];
    // A file sits in a subdirectory exactly when its parent is one this server
    // was asked to create. Everything else is a flat file at the remote root,
    // whatever the server URL's own path happens to be.
    final isBlob = collections.contains(parent);
    final name = isBlob ? '$parent/$last' : last;

    switch (request.method) {
      case 'GET':
        if (isBlob) {
          final bytes = files[name];
          if (bytes == null) return _response(404, const []);
          return _response(200, bytes);
        }
        if (content == null) return _response(404, const []);
        return _bodyResponse(200, content!, headers: {'etag': etag});

      case 'PUT':
        if (isBlob) {
          if (refuseUploads) return _response(507, const []);
          files[name] = await _bytesOf(request);
          return _response(201, const []);
        }

        final body = request is http.Request ? request.body : '';
        ifMatch.add(request.headers['If-Match']);
        ifNoneMatch.add(request.headers['If-None-Match']);

        if (refuseNextPut) {
          refuseNextPut = false;
          return _response(412, const []);
        }
        final condition = request.headers['If-Match'];
        if (condition != null && condition != etag) {
          return _response(412, const []);
        }
        if (request.headers['If-None-Match'] == '*' && content != null) {
          return _response(412, const []);
        }

        writes.add(body);
        content = body;
        etag = '"v${writes.length + 1}"';
        return _response(201, const []);

      case 'DELETE':
        deletes.add(name);
        files.remove(name);
        return _response(204, const []);

      case 'MKCOL':
        collections.add(last);
        return _response(201, const []);

      case 'PROPFIND':
        if (refuseListing) return _response(500, const []);
        final prefix = '$last/';
        final hrefs = [
          for (final stored in files.keys)
            if (stored.startsWith(prefix))
              '<d:response><d:href>/$stored</d:href></d:response>',
        ];
        return _bodyResponse(
          207,
          '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
          '<d:response><d:href>/$prefix</d:href></d:response>'
          '${hrefs.join()}</d:multistatus>',
        );

      default:
        return _response(207, const []);
    }
  }

  /// Purpose: Read a request's body as bytes.
  /// Inputs: The [request].
  /// Returns: The bytes.
  /// Side effects: Drains the request stream.
  /// Notes: Internal helper used within this file only.
  Future<Uint8List> _bytesOf(http.BaseRequest request) async {
    if (request is http.Request) return Uint8List.fromList(request.bodyBytes);
    return request.finalize().toBytes();
  }

  /// Purpose: Build a response from bytes.
  /// Inputs: The [status], the [body] and any [headers].
  /// Returns: A streamed response.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  http.StreamedResponse _response(
    int status,
    List<int> body, {
    Map<String, String> headers = const {},
  }) => http.StreamedResponse(
    Stream.value(body),
    status,
    headers: headers,
    contentLength: body.length,
  );

  /// Purpose: Build a response from text.
  /// Inputs: The [status], the [body] and any [headers].
  /// Returns: A streamed response.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  http.StreamedResponse _bodyResponse(
    int status,
    String body, {
    Map<String, String> headers = const {},
  }) => _response(status, utf8.encode(body), headers: headers);
}
