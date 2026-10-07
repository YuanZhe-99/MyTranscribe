import 'package:myapps_data/myapps_data.dart' as shared;

export 'package:myapps_data/myapps_data.dart'
    show EndpointReason, EndpointVerdict;

/// Purpose: Evaluate a secret endpoint. Inputs: url, trustedHosts. Returns: Verdict.
/// Side effects: None. Notes: Shared policy includes HTTPS, LAN, Tailscale, EasyTier.
shared.EndpointVerdict evaluateSecretsEndpoint(
  String url, {
  List<String> trustedHosts = const [],
}) => shared.evaluateEndpointUrl(url, trustedHosts: trustedHosts);

/// Purpose: Normalize a trusted host. Inputs: value. Returns: Host or null.
/// Side effects: None. Notes: Host entries remain device-local.
String? normalizeTrustedHost(String value) =>
    shared.normalizeTrustedHostEntry(value);
