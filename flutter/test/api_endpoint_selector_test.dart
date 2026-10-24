// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_hbb/utils/api_endpoint_selector.dart';

void main() {
  test('prefers LAN and shares one probe across concurrent API requests',
      () async {
    var probes = 0;
    final selector = ApiEndpointSelector(
        createClient: () => MockClient((request) async {
              probes++;
              expect(request.headers.containsKey('authorization'), isFalse);
              return http.Response('ok\n', 200);
            }));
    final results = await Future.wait([
      selector.resolve(Uri.parse('$publicApiOrigin/api/currentUser?q=1')),
      selector.resolve(Uri.parse('$internalApiOrigin/api/heartbeat')),
    ]);
    expect(results.every((url) => url.origin == internalApiOrigin), isTrue);
    expect(results.first.path, '/api/currentUser');
    expect(results.first.query, 'q=1');
    expect(probes, 1);
  });

  test('caches public, then rechecks LAN after a connection failure', () async {
    var available = false;
    final selector = ApiEndpointSelector(
        createClient: () => MockClient((_) async {
              if (!available) throw http.ClientException('offline');
              return http.Response('ok', 200);
            }));
    final url = Uri.parse('$internalApiOrigin/api/ab');
    expect((await selector.resolve(url)).origin, publicApiOrigin);
    available = true;
    expect((await selector.resolve(url)).origin, publicApiOrigin);
    selector.invalidate(url);
    expect((await selector.resolve(url)).origin, internalApiOrigin);
  });

  test('a stalled probe times out and custom API servers are preserved',
      () async {
    var probes = 0;
    final selector = ApiEndpointSelector(
        probeTimeout: const Duration(milliseconds: 30),
        createClient: () => MockClient((_) {
              probes++;
              return Completer<http.Response>().future;
            }));
    final url = Uri.parse('$internalApiOrigin/api/login');
    expect((await selector.resolve(url)).origin, publicApiOrigin);
    final custom = Uri.parse('https://custom.example/api/login');
    expect(await selector.resolve(custom), custom);
    expect(probes, 1);
  });
}
