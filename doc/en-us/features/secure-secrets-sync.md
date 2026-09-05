# API keys, and when they are allowed to travel

*Delivered by milestone M6. The rule and its reasoning are fixed here first, because it is a promise
made to the user in the privacy policy.*

## Where keys live

In `transcribe_secrets.json`, in the app directory, keyed by the source's record id so a key follows
its source. Plain text, like the WebDAV password beside it, and stated as such in the privacy
policy.

That file is **not** a data module. The sync, backup and ZIP engines only ever touch the file names
in the registry in `lib/app/data_modules.dart`, so a key cannot end up in a backup bundle or a ZIP
export by accident — not because something filters it out, but because nothing ever looks at the
file. This is the whole reason keys are not simply a field on the source record.

## The rule

A key is copied to the user's WebDAV server only when the app can reach that server safely.

**Allowed:**

- `https://` — any host. The transport is encrypted; that is the whole question.
- `http://` to an address that cannot leave the user's own network or overlay:
  - loopback: `localhost`, `127.0.0.0/8`, `::1`
  - private IPv4: `10/8`, `172.16/12`, `192.168/16`
  - link-local: `169.254/16`, `fe80::/10`
  - carrier-grade NAT: `100.64/10` — the range Tailscale assigns
  - IPv6 unique local: `fc00::/7`, which covers Tailscale's own range
  - a Tailscale name: any host ending `.ts.net`
  - a ZeroTier name: any host ending `.et.net`
  - a local name: any host ending `.local`, or a host with no dot at all
- `http://` to a host the user added to their **trusted hosts** list, by exact name or as
  `*.suffix`.

**Refused:** plain HTTP to anything else, and any other scheme.

Ports are ignored: what decides is the transport and the destination, not the port number.

The check is written as a pure function with a named reason for every verdict, so the UI can say
*why* rather than just yes or no, and so the whole table can be tested without a network. A
suffix match requires a real subdomain: `*.example.com` trusts `a.example.com` and not
`example.com`, and a host such as `evil.ts.net.example.com` is refused because its suffix is not
`.ts.net`.

## What the user sees

Under the server URL field, a banner that updates as they type:

- green — "API keys will sync", with the reason (over HTTPS; on your local network; over Tailscale).
- amber — "API keys stay on this device", with the reason and what to do about it. **Settings still
  sync**; only the keys are held back.

A row in the configured section shows how many sources have a key and what happened at the last
exchange. The trusted-hosts editor lives beside it, and adding a host re-evaluates the banner
immediately.

## The exchange

Runs inside the WebDAV facade, immediately after the sync engine returns, against the same server
and the same remote directory:

1. Evaluate the endpoint. If it is refused, stop — **in both directions**. A download carries keys
   over the same connection an upload would.
2. Download the remote keys file, keeping its version tag.
3. Merge per key by `updatedAt`, last writer wins, tombstones included so a deleted key does not
   come back.
4. Write locally if anything changed, then upload conditionally on the version tag we read. If the
   server says it changed underneath us, read again and re-merge once.

Force upload and force download skip the merge in the matching direction, like the module does.

**Why this runs outside the engine's lock.** The lock protects a three-way merge whose base snapshot
must not move underneath it. The keys file has no base snapshot and no merge state — it is a map of
independent per-key values — and the conditional upload turns a concurrent write into a rejection
and a retry rather than a lost update. Putting the exchange inside the locked window would mean
changing an engine four apps share, for no safety gained.

## The trade this makes

Keys are excluded from local backups. Restoring a backup on a fresh device gives you your sources
and models, and you re-enter your keys — or sync once from a device that has them, over a connection
that qualifies. That is a deliberate choice: a backup bundle is a plain file people copy around, and
a key in one is a key in every copy of it.
