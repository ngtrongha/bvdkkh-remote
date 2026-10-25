# Hospital API endpoint selection

The client prefers `http://172.16.3.28:21114` and falls back to
`https://danhba.bvkhanhhoa.cloud`. These are two routes to the same backend.

A credential-free GET `/healthz` must return HTTP 200 with body `ok` to select
the internal route. The probe has a two-second timeout and the choice is cached
for sixty seconds. Concurrent calls share the probe. A transport failure causes
the next request to check again; it does not replay the failed write through the
other API origin. Authentication responses do not trigger endpoint switching.
Custom API origins and the existing Dart/Rust transport choice are preserved.

Review and verification on 2026-10-24:

- On Ethernet, the real Dart selector chose the internal API in 44 ms and its
  health request returned 200. On external Wi-Fi, it chose public in 2015 ms and
  the public health request returned 200.
- Selector tests cover internal preference and shared probes, caching and
  rechecking after a connection failure, timeout fallback and custom origins.
- The support dialog's direct HTTP/multipart submission also resolves the API
  before sending, so it does not depend on the background process's cached route.
- The local machine has no Rust compiler. Rust source syntax was checked with
  Tree-sitter; native compilation is delegated to the existing GitHub Actions
  builds. A requested build is not evidence of a successful native compilation.

Existing runtime paths changed, and why:

- `flutter/lib/utils/http_service.dart`: resolve the origin before Dart HTTP
  sends a request and invalidate only after a transport failure.
- `flutter/lib/common/widgets/support_dialog.dart`: resolve direct HTTP and
  multipart ticket requests which bypass `HttpService`.
- `src/common.rs`: return the selected cached API and resolve native POST/HTTP
  requests before dispatch; invalidate on transport failure for the next call.
- `src/hbbs_http/sync.rs`: check selection during background heartbeat, including
  when the UI is idle, and keep sync bookkeeping on the selected URL.
- `src/deployment_agent.rs`: resolve direct HTTP/agent WebSocket endpoints before
  connection, because these calls bypass the common request wrapper.
- `src/lib.rs`: register the new endpoint module.

ID and relay servers are unchanged. API fallback alone does not establish a
remote desktop session from outside the hospital. Browser CORS/LAN permissions
are separate from native client networking.

## API route indicator

The desktop footer and mobile app bar show the last observed API route: internal,
public or custom. Before a UI request completes, the badge remains unknown; it
does not infer a route from Ethernet/Wi-Fi or the remote-session service status.
Transport errors are marked separately. Tooltip text contains only the origin,
never request paths, query parameters or credentials. HTTP business/auth errors
still establish that the API was reachable.

`HttpService` and direct support submissions report completed API requests to a
small UI notifier. Native `http_request_sync` adds `api_origin` to its existing
JSON response so UI polling reads the route used by that request, including TCP
proxy requests. The additive field leaves status, headers and body unchanged;
older native responses fall back to the existing API getter. Rust syntax and
the origin-redaction unit test are included; local native execution still needs
the Rust toolchain.

The existing desktop home footer and mobile/web home app bars now host the badge
(`desktop_home_page.dart`, `mobile/pages/home_page.dart`). These are the only
client layout paths changed. The support dialog reports its direct submission
response/transport failure; `HttpService` reports Dart and native requests.
No extra health checks, timers, settings or remote-session changes are added.
