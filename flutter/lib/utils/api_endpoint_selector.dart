// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'package:http/http.dart' as http;

const internalApiOrigin = 'http://172.16.3.28:21114';
const publicApiOrigin = 'https://danhba.bvkhanhhoa.cloud';

bool isHospitalApi(Uri uri) =>
    uri.hasAuthority &&
    uri.userInfo.isEmpty &&
    (uri.origin == internalApiOrigin || uri.origin == publicApiOrigin);

class ApiEndpointSelector {
  final http.Client Function() _createClient;
  final Duration _refreshInterval;
  final Duration _probeTimeout;
  DateTime? _checkedAt;
  String _selectedOrigin = publicApiOrigin;
  Future<String>? _pending;

  ApiEndpointSelector({
    http.Client Function()? createClient,
    Duration refreshInterval = const Duration(seconds: 60),
    Duration probeTimeout = const Duration(seconds: 2),
  })  : _createClient = createClient ?? http.Client.new,
        _refreshInterval = refreshInterval,
        _probeTimeout = probeTimeout;

  Future<Uri> resolve(Uri url) async {
    if (!isHospitalApi(url)) return url;
    final origin = await _selectOrigin();
    return Uri.parse(origin + url.toString().substring(url.origin.length));
  }

  void invalidate(Uri url) {
    if (isHospitalApi(url)) _checkedAt = null;
  }

  Future<String> _selectOrigin() async {
    if (_pending != null) return _pending!;
    if (_checkedAt != null &&
        DateTime.now().difference(_checkedAt!) < _refreshInterval) {
      return _selectedOrigin;
    }
    final pending = _probe();
    _pending = pending;
    try {
      return await pending;
    } finally {
      _pending = null;
    }
  }

  Future<String> _probe() async {
    final client = _createClient();
    var internalAvailable = false;
    try {
      final request =
          http.Request('GET', Uri.parse('$internalApiOrigin/healthz'))
            ..followRedirects = false;
      final response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })()
          .timeout(_probeTimeout);
      internalAvailable =
          response.statusCode == 200 && response.body.trim() == 'ok';
    } on Exception {
      internalAvailable = false;
    } finally {
      client.close();
    }
    _selectedOrigin = internalAvailable ? internalApiOrigin : publicApiOrigin;
    _checkedAt = DateTime.now();
    return _selectedOrigin;
  }
}
