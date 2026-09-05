# What counts as a safe place to send a key

*Delivered by milestone M6. A pure function with a named reason for every verdict, so the interface
can explain itself and the whole table can be tested without a network.*

The question is narrow: may this app copy an API key to the WebDAV server the user configured? The
answer must be conservative, because getting it wrong sends a credential across the open internet in
clear text.

## Allowed

**Anything over HTTPS.** The transport is encrypted; that is the whole question, and the host does
not matter.

**Plain HTTP to somewhere the traffic cannot leave.** Concretely: loopback; the private IPv4 ranges;
link-local; the carrier-grade NAT range that Tailscale hands out; IPv6 loopback, link-local and
unique-local, which covers Tailscale's own range; a host ending `.ts.net` (Tailscale) or `.et.net`
(ZeroTier); a host ending `.local`; and a host with no dot in it at all, which on a home network
means a machine name.

**A host the user vouched for.** A trusted-hosts list, by exact name or as a `*.suffix` pattern.
This is the escape hatch for a network the app cannot recognise — a VPN with its own naming, a
reverse proxy on a private domain.

## Refused

Plain HTTP to anything else, and any scheme that is neither. The settings still sync; only the keys
are held back, and the interface says so and why.

## Details that matter

- **Ports are ignored.** What decides is the transport and the destination.
- **A suffix match needs a real subdomain.** `*.example.com` trusts `a.example.com`, not
  `example.com`.
- **The suffix must be the end.** A host such as `evil.ts.net.example.com` is refused: its actual
  suffix is `.example.com`.
- **IPv4-mapped IPv6 addresses are unwrapped** before the ranges are checked, so a private address
  written the long way is still recognised, and a public one is still refused.
- **A refusal blocks both directions.** Downloading keys uses the same connection uploading them
  would.

## Why the list is device-local

The trusted-hosts list is not synced. A name resolves to a machine on this network here and to
something else entirely on another device, so the judgement belongs to the device that will make the
connection. Keeping it local also means one device's edit cannot quietly start key uploads from
every other device.
