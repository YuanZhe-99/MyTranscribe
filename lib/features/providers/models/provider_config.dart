/// Purpose: A source — somewhere the app can send audio, and how to talk to it.
/// Inputs: The `payload` of a settings record of kind `provider`.
/// Returns: The `ProviderConfig` value type and its enums.
/// Side effects: None.
/// Notes: The user's word for this is 来源, a *source*; in code it is a
/// provider, because that is what the endpoints call themselves. It holds no
/// API key: keys live in `transcribe_secrets.json`, which is not part of any
/// data module. See `doc/en-us/features/provider-library.md`.
library;

/// How requests to a source are shaped.
///
/// Not a cosmetic label — each value selects a different request builder,
/// because the three endpoints genuinely differ in where options go, not only
/// in their URLs.
enum ProviderDialect {
  /// The official OpenAI audio API: multipart, with keyword and multi-language
  /// hints and speaker references where the model supports them.
  openai,

  /// OpenRouter, which is OpenAI-compatible for the simple case and needs a
  /// JSON body to reach a provider's own options such as speaker labels.
  openrouter,

  /// Anything else that speaks the OpenAI protocol: another gateway, or a
  /// server on the user's own machine.
  openaiCompatible,
}

/// How a request proves who it is.
enum AuthScheme {
  /// `Authorization: Bearer <key>`, what almost everything expects.
  bearer,

  /// No credential at all. What a server on your own machine usually wants,
  /// and the reason this is a choice rather than an assumption.
  none,

  /// A header the user names, for a gateway with its own convention.
  header,
}

/// Keys this build writes into a provider payload.
const _knownKeys = {
  'name',
  'templateId',
  'dialect',
  'baseUrl',
  'authScheme',
  'authHeaderName',
  'extraHeaders',
  'maxRequestSeconds',
  'maxFileBytes',
  'requestTimeoutSeconds',
  'defaultModelId',
  'overriddenFields',
  'templateVersion',
};

/// One place the app can send audio.
class ProviderConfig {
  /// The settings record id, e.g. `provider:openai` or `provider:<uuid>`.
  final String id;

  /// What the user calls it.
  final String name;

  /// The template this came from, or null when the user built it themselves.
  final String? templateId;

  /// How requests are shaped.
  final ProviderDialect dialect;

  /// The API root, without a trailing slash, e.g. `https://api.openai.com/v1`.
  final String baseUrl;

  /// How to authenticate.
  final AuthScheme authScheme;

  /// The header name when [authScheme] is [AuthScheme.header].
  final String? authHeaderName;

  /// Extra headers to send, for a gateway that asks for them.
  final Map<String, String> extraHeaders;

  /// The longest audio one request may carry, in seconds, or null for no
  /// provider-level limit.
  ///
  /// A *provider* limit, distinct from a model's. A gateway that gives up after
  /// a minute of upstream processing caps every model behind it, however much
  /// audio the model itself would accept.
  final int? maxRequestSeconds;

  /// The largest upload this provider accepts, in bytes, or null to use the
  /// model's own limit.
  final int? maxFileBytes;

  /// How long to wait for one request before giving up.
  final int requestTimeoutSeconds;

  /// The model a new job starts with, or null for the first one.
  final String? defaultModelId;

  /// Fields the user changed away from the template.
  ///
  /// A later build that ships an updated template refreshes everything **not**
  /// in this set, so an improved default reaches people who never touched it
  /// while a deliberate change survives.
  final Set<String> overriddenFields;

  /// The template version this record was last refreshed from.
  final int templateVersion;

  /// Payload fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a provider configuration.
  /// Inputs: All fields; only [id], [name], [dialect] and [baseUrl] are
  /// required.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ProviderConfig({
    required this.id,
    required this.name,
    required this.dialect,
    required this.baseUrl,
    this.templateId,
    this.authScheme = AuthScheme.bearer,
    this.authHeaderName,
    this.extraHeaders = const {},
    this.maxRequestSeconds,
    this.maxFileBytes,
    this.requestTimeoutSeconds = 600,
    this.defaultModelId,
    this.overriddenFields = const {},
    this.templateVersion = 0,
    this.extraJson = const {},
  });

  /// Purpose: Read a provider from a settings record payload.
  /// Inputs: [id] the record id, [payload] its fields.
  /// Returns: A [ProviderConfig].
  /// Side effects: None.
  /// Notes: Every field falls back rather than throwing. A record written by a
  /// newer build must stay usable here, and a hand-edited file should degrade
  /// to something sensible rather than making the library unopenable.
  factory ProviderConfig.fromPayload(String id, Map<String, dynamic> payload) {
    return ProviderConfig(
      id: id,
      name: _string(payload['name']) ?? id,
      templateId: _string(payload['templateId']),
      dialect: _parseDialect(payload['dialect']),
      baseUrl: _string(payload['baseUrl']) ?? '',
      authScheme: _parseAuth(payload['authScheme']),
      authHeaderName: _string(payload['authHeaderName']),
      extraHeaders: _stringMap(payload['extraHeaders']),
      maxRequestSeconds: _positiveInt(payload['maxRequestSeconds']),
      maxFileBytes: _positiveInt(payload['maxFileBytes']),
      requestTimeoutSeconds:
          _positiveInt(payload['requestTimeoutSeconds']) ?? 600,
      defaultModelId: _string(payload['defaultModelId']),
      overriddenFields: _stringSet(payload['overriddenFields']),
      templateVersion: _positiveInt(payload['templateVersion']) ?? 0,
      extraJson: {
        for (final e in payload.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Purpose: Write the provider as a settings record payload.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Unknown fields first, so a known key wins a name collision. Null
  /// optional fields are omitted rather than written as null, which keeps the
  /// file readable and the raw-equality sync fast path reachable.
  Map<String, dynamic> toPayload() => {
    ...extraJson,
    'name': name,
    if (templateId != null) 'templateId': templateId,
    'dialect': dialect.name,
    'baseUrl': baseUrl,
    'authScheme': authScheme.name,
    if (authHeaderName != null) 'authHeaderName': authHeaderName,
    if (extraHeaders.isNotEmpty) 'extraHeaders': extraHeaders,
    if (maxRequestSeconds != null) 'maxRequestSeconds': maxRequestSeconds,
    if (maxFileBytes != null) 'maxFileBytes': maxFileBytes,
    'requestTimeoutSeconds': requestTimeoutSeconds,
    if (defaultModelId != null) 'defaultModelId': defaultModelId,
    if (overriddenFields.isNotEmpty)
      'overriddenFields': (overriddenFields.toList()..sort()),
    'templateVersion': templateVersion,
  };

  /// Purpose: Return a copy with some fields replaced, marking what changed.
  /// Inputs: The fields to change, and a `clear` flag per nullable one.
  /// Returns: A new [ProviderConfig].
  /// Side effects: None.
  /// Notes: **Every changed field is added to [overriddenFields]**, which is
  /// what protects a user's edit from a later template refresh. Pass
  /// `markOverridden: false` only when the change *is* the refresh.
  ProviderConfig copyWith({
    String? name,
    String? baseUrl,
    ProviderDialect? dialect,
    AuthScheme? authScheme,
    String? authHeaderName,
    bool clearAuthHeaderName = false,
    Map<String, String>? extraHeaders,
    int? maxRequestSeconds,
    bool clearMaxRequestSeconds = false,
    int? maxFileBytes,
    bool clearMaxFileBytes = false,
    int? requestTimeoutSeconds,
    String? defaultModelId,
    bool clearDefaultModelId = false,
    Set<String>? overriddenFields,
    int? templateVersion,
    bool markOverridden = true,
  }) {
    final changed = <String>{
      if (name != null) 'name',
      if (baseUrl != null) 'baseUrl',
      if (dialect != null) 'dialect',
      if (authScheme != null) 'authScheme',
      if (authHeaderName != null || clearAuthHeaderName) 'authHeaderName',
      if (extraHeaders != null) 'extraHeaders',
      if (maxRequestSeconds != null || clearMaxRequestSeconds)
        'maxRequestSeconds',
      if (maxFileBytes != null || clearMaxFileBytes) 'maxFileBytes',
      if (requestTimeoutSeconds != null) 'requestTimeoutSeconds',
    };
    return ProviderConfig(
      id: id,
      name: name ?? this.name,
      templateId: templateId,
      dialect: dialect ?? this.dialect,
      baseUrl: baseUrl ?? this.baseUrl,
      authScheme: authScheme ?? this.authScheme,
      authHeaderName: clearAuthHeaderName
          ? null
          : (authHeaderName ?? this.authHeaderName),
      extraHeaders: extraHeaders ?? this.extraHeaders,
      maxRequestSeconds: clearMaxRequestSeconds
          ? null
          : (maxRequestSeconds ?? this.maxRequestSeconds),
      maxFileBytes: clearMaxFileBytes
          ? null
          : (maxFileBytes ?? this.maxFileBytes),
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      defaultModelId: clearDefaultModelId
          ? null
          : (defaultModelId ?? this.defaultModelId),
      overriddenFields:
          overriddenFields ??
          (markOverridden
              ? {...this.overriddenFields, ...changed}
              : this.overriddenFields),
      templateVersion: templateVersion ?? this.templateVersion,
      extraJson: extraJson,
    );
  }

  /// Purpose: Report whether this source needs an API key.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Drives whether the editor shows a key field at all. A local server
  /// with no authentication should not be nagged about a missing key.
  bool get needsApiKey => authScheme != AuthScheme.none;

  /// Purpose: Build the URL for one endpoint under this source.
  /// Inputs: [path] such as `audio/transcriptions`.
  /// Returns: The absolute URL.
  /// Side effects: None.
  /// Notes: Tolerates a base URL the user typed with or without a trailing
  /// slash, which is the single most common way to mistype one.
  String endpoint(String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final suffix = path.startsWith('/') ? path.substring(1) : path;
    return '$base/$suffix';
  }
}

/// Purpose: Parse a dialect name.
/// Inputs: [value].
/// Returns: The dialect; unknown values read as [ProviderDialect.openaiCompatible].
/// Side effects: None.
/// Notes: The compatible dialect is the safe fallback: it sends the smallest
/// request any of these endpoints accepts, so a record from a newer build that
/// names a dialect this one lacks still works, with fewer features.
ProviderDialect _parseDialect(Object? value) {
  for (final dialect in ProviderDialect.values) {
    if (dialect.name == value) return dialect;
  }
  return ProviderDialect.openaiCompatible;
}

/// Purpose: Parse an authentication scheme name.
/// Inputs: [value].
/// Returns: The scheme; unknown values read as [AuthScheme.bearer].
/// Side effects: None.
/// Notes: Bearer is the fallback because it is what almost every endpoint
/// wants, and because sending a key that is not needed fails more visibly than
/// omitting one that is.
AuthScheme _parseAuth(Object? value) {
  for (final scheme in AuthScheme.values) {
    if (scheme.name == value) return scheme;
  }
  return AuthScheme.bearer;
}

/// Purpose: Read a non-empty string field.
/// Inputs: [value].
/// Returns: The trimmed string, or null.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String? _string(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Purpose: Read a positive integer field.
/// Inputs: [value].
/// Returns: The value, or null when absent, unparseable or not positive.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Zero and negatives read
/// as unset: a limit of zero would mean "nothing may be uploaded", which is
/// never what a config file meant to say.
int? _positiveInt(Object? value) {
  final parsed = switch (value) {
    final int n => n,
    final num n => n.round(),
    final String s => int.tryParse(s),
    _ => null,
  };
  return parsed != null && parsed > 0 ? parsed : null;
}

/// Purpose: Read a map of strings.
/// Inputs: [value].
/// Returns: The entries whose keys and values are both strings.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final e in value.entries)
      if (e.key is String && e.value is String)
        e.key as String: e.value as String,
  };
}

/// Purpose: Read a set of strings.
/// Inputs: [value].
/// Returns: The string entries.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Set<String> _stringSet(Object? value) {
  if (value is! List) return const {};
  return {
    for (final item in value)
      if (item is String) item,
  };
}
