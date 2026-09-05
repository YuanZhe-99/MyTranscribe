/// Purpose: Decide whether an API key may be sent to a WebDAV address.
/// Inputs: The server address, and the hosts this device has been told to
/// trust.
/// Returns: A verdict and the reason for it.
/// Side effects: None.
/// Notes: Settings sync anywhere; keys do not. A key is a bearer credential —
/// anyone who reads it off the wire can spend the user's money — so it goes out
/// only over HTTPS, or over plain HTTP to an address that cannot leave the
/// user's own network: a private range, a link-local address, a Tailscale or
/// ZeroTier name, an mDNS name, or a host they have explicitly trusted.
/// Everything else is refused with a reason, and the settings sync anyway. See
/// `doc/en-us/algorithms/secure-endpoint.md`.
library;

/// Why an address was or was not accepted.
enum EndpointReason {
  /// The connection is encrypted.
  https,

  /// Loopback: the server is this machine.
  loopback,

  /// A private IPv4 range.
  privateIpv4,

  /// A link-local IPv4 address.
  linkLocal,

  /// The carrier-grade NAT range Tailscale allocates from.
  cgnat,

  /// A unique-local or link-local IPv6 address.
  privateIpv6,

  /// A Tailscale name.
  tailnet,

  /// A ZeroTier name.
  zerotier,

  /// An mDNS name, resolvable only on the local link.
  mdns,

  /// A bare hostname with no dots, which only a local resolver answers.
  singleLabelHost,

  /// A host the user added to this device's trusted list.
  trustedHost,

  /// Plain HTTP to a host that could be anywhere.
  deniedPublicHttp,

  /// Neither HTTP nor HTTPS.
  deniedScheme,

  /// The address could not be read as one.
  deniedUnparseable,
}

/// What the policy decided about one address.
class EndpointVerdict {
  /// Whether keys may be exchanged with this address.
  final bool allowed;

  /// Why.
  final EndpointReason reason;

  /// The host that was judged, lowercased, or empty when there was none.
  final String host;

  /// Purpose: Record a verdict.
  /// Inputs: [allowed], [reason], [host].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const EndpointVerdict({
    required this.allowed,
    required this.reason,
    required this.host,
  });
}

/// Purpose: Judge whether an address is safe to send an API key to.
/// Inputs: The [url] of the WebDAV server, and the [trustedHosts] this device
/// has been told to accept.
/// Returns: An [EndpointVerdict].
/// Side effects: None.
/// Notes: The host is judged, never resolved: a DNS lookup would make the
/// answer depend on the network at the moment of asking, and a name that
/// resolves privately today can resolve publicly tomorrow. Ports are ignored
/// entirely — a port says nothing about who can read the traffic.
EndpointVerdict evaluateSecretsEndpoint(
  String url, {
  List<String> trustedHosts = const [],
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return const EndpointVerdict(
      allowed: false,
      reason: EndpointReason.deniedUnparseable,
      host: '',
    );
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return const EndpointVerdict(
      allowed: false,
      reason: EndpointReason.deniedUnparseable,
      host: '',
    );
  }

  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();

  if (scheme == 'https') {
    return EndpointVerdict(
      allowed: true,
      reason: EndpointReason.https,
      host: host,
    );
  }
  if (scheme != 'http') {
    return EndpointVerdict(
      allowed: false,
      reason: EndpointReason.deniedScheme,
      host: host,
    );
  }

  if (_privateAddress(host) case final reason?) {
    return EndpointVerdict(allowed: true, reason: reason, host: host);
  }
  if (_privateName(host) case final reason?) {
    return EndpointVerdict(allowed: true, reason: reason, host: host);
  }
  if (_isTrusted(host, trustedHosts)) {
    return EndpointVerdict(
      allowed: true,
      reason: EndpointReason.trustedHost,
      host: host,
    );
  }

  return EndpointVerdict(
    allowed: false,
    reason: EndpointReason.deniedPublicHttp,
    host: host,
  );
}

/// Purpose: Recognise an address that cannot be routed off the local network.
/// Inputs: The lowercased [host].
/// Returns: The reason, or null when it is not one.
/// Side effects: None.
/// Notes: Internal helper used within this file only. An IPv4 address mapped
/// into IPv6 is unwrapped and judged as the IPv4 address it is, because that is
/// what the packets will carry.
EndpointReason? _privateAddress(String host) {
  final bare = host.startsWith('[') && host.endsWith(']')
      ? host.substring(1, host.length - 1)
      : host;

  if (bare == '::1') return EndpointReason.loopback;
  if (bare.startsWith('::ffff:')) {
    final mapped = bare.substring('::ffff:'.length);
    if (mapped.contains('.')) return _privateIpv4(mapped);
  }
  if (bare.contains(':')) {
    // fe80::/10 link-local, and fc00::/7 unique-local — the range Tailscale's
    // own addresses fall in.
    final head = bare.split(':').first;
    if (head.length >= 2) {
      final prefix = int.tryParse(head.padRight(4, '0'), radix: 16);
      if (prefix != null) {
        if (prefix >= 0xfe80 && prefix <= 0xfebf) {
          return EndpointReason.privateIpv6;
        }
        if (prefix >= 0xfc00 && prefix <= 0xfdff) {
          return EndpointReason.privateIpv6;
        }
      }
    }
    return null;
  }

  return _privateIpv4(bare);
}

/// Purpose: Recognise a private IPv4 address.
/// Inputs: The [address] in dotted form.
/// Returns: The reason, or null.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
EndpointReason? _privateIpv4(String address) {
  final parts = address.split('.');
  if (parts.length != 4) return null;
  final octets = [for (final part in parts) int.tryParse(part)];
  if (octets.any((o) => o == null || o < 0 || o > 255)) return null;
  final a = octets[0]!;
  final b = octets[1]!;

  if (a == 127) return EndpointReason.loopback;
  if (a == 10) return EndpointReason.privateIpv4;
  if (a == 172 && b >= 16 && b <= 31) return EndpointReason.privateIpv4;
  if (a == 192 && b == 168) return EndpointReason.privateIpv4;
  if (a == 169 && b == 254) return EndpointReason.linkLocal;
  // 100.64.0.0/10, which is where Tailscale hands out addresses.
  if (a == 100 && b >= 64 && b <= 127) return EndpointReason.cgnat;
  return null;
}

/// Purpose: Recognise a name that only resolves inside a private network.
/// Inputs: The lowercased [host].
/// Returns: The reason, or null.
/// Side effects: None.
/// Notes: Internal helper used within this file only. The suffixes are matched
/// on a label boundary, so `evil.ts.net.example.com` is a public host that
/// happens to contain the string and is refused.
EndpointReason? _privateName(String host) {
  // An address is not a name. Without this, a public IPv6 address such as
  // `[2001:db8::1]` would reach the no-dot rule below and be accepted as a
  // local hostname, which is exactly backwards.
  if (host.contains(':') || RegExp(r'^[0-9.]+$').hasMatch(host)) return null;

  if (host == 'localhost' || host.endsWith('.localhost')) {
    return EndpointReason.loopback;
  }
  if (host.endsWith('.ts.net')) return EndpointReason.tailnet;
  if (host.endsWith('.et.net')) return EndpointReason.zerotier;
  if (host.endsWith('.local')) return EndpointReason.mdns;
  // A name with no dot cannot be resolved by public DNS; only a local resolver,
  // a hosts file or NetBIOS answers it.
  if (!host.contains('.')) return EndpointReason.singleLabelHost;
  return null;
}

/// Purpose: Check a host against this device's trusted list.
/// Inputs: The lowercased [host] and the [trustedHosts].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. An entry may be an exact
/// host or a `*.suffix` wildcard, which covers subdomains and **not** the bare
/// domain: somebody who trusts `*.example.com` has said nothing about
/// `example.com` itself.
bool _isTrusted(String host, List<String> trustedHosts) {
  for (final raw in trustedHosts) {
    final entry = raw.trim().toLowerCase();
    if (entry.isEmpty) continue;
    if (entry.startsWith('*.')) {
      final suffix = entry.substring(1);
      if (host.endsWith(suffix) && host.length > suffix.length) return true;
    } else if (entry == host) {
      return true;
    }
  }
  return false;
}
