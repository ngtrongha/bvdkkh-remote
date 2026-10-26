# Public API was reachable while remote registration stayed offline

Observed on 2026-10-26 over external Wi-Fi:

- `https://danhba.bvkhanhhoa.cloud/healthz` returned HTTP 200, body `ok`.
- Both `wss://danhba.bvkhanhhoa.cloud/ws/id` and `/ws/relay` completed a
  certificate-validated WebSocket handshake (Open, 575 ms and 190 ms).
- Installed configuration still selected `172.16.3.28:21116` for rendezvous and
  `172.16.3.28` for relay. Client logs showed connection failure to port 21116.
- The previous API fallback and API badge did not select the remote protocol's
  endpoints. An API Public badge therefore did not mean remote registration worked.

The hospital client now selects a consistent ID server, relay server, API origin
and WebSocket mode using its existing bounded LAN health selection. LAN uses the
original IP/native transport. Public uses the `danhba` host with HTTPS and the
existing WSS `/ws/id` and `/ws/relay` mapping. No new ports, credentials, keys,
timers, model processes or dependencies are introduced.

These are runtime overrides only. Unknown/custom ID, relay or API servers retain
their previous path. When the route changes, only rendezvous registration is
restarted; established remote-session streams are not explicitly closed.
The existing WebSocket mode is process-wide; this fix does not add per-session
transport profiles for simultaneous hospital and foreign `id@server` targets.

Regression surface (each hook is needed for the corresponding network path):

- `src/rendezvous_mediator.rs`: choose before native registration/NAT detection.
- `src/hbbs_http/sync.rs`: refresh on the existing heartbeat so network changes
  can re-register the ID listener without waiting for a UI API request.
- `src/common.rs`: choose before outgoing ID lookup; hospital routes use the
  current process's choice instead of a potentially stale service IPC snapshot.
- `src/client.rs` and `src/server.rs`: map a hospital relay supplied by the peer
  onto the locally reachable route. This supports both LAN-to-public and
  public-to-LAN pairs while preserving third-party relay addresses.
- `src/lib.rs`: register the feature-specific `remote_endpoint` module.

Three Rust regression tests cover coordinated TLS/WS route values, custom-server
preservation and both directions of relay mapping. Local Rust execution remains
unavailable without cargo/rustc. WSS handshake checks establish transport
reachability, not successful device registration or a full remote-control session.
The installed client requires an updated binary before this fix takes effect.
