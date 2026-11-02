// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:flutter_hbb/utils/api_endpoint_selector.dart';
import 'package:flutter_hbb/utils/wake_on_lan.dart';

void main() {
  test('public ID uses authenticated server WOL and reports the relay queue',
      () async {
    final message = await requestWakeOnLan(' 123 456 ',
        server: '$publicApiOrigin/',
        token: 'client-token',
        senderId: 'operator-device',
        sendLocal: (_) async => fail('Must use server WOL outside LAN'),
        post: (url, {headers, body}) async {
          expect(url.toString(), '$publicApiOrigin/admin/devices/123456/wol');
          expect(headers?['Authorization'], 'Bearer client-token');
          expect(headers?['Content-Type'], 'application/json');
          expect(jsonDecode(body as String), {'sender_id': 'operator-device'});
          return Response(
              '{"code":200,"data":{"method":"relay","sent_count":1}}', 200);
        });
    expect(message, contains('xếp hàng WOL'));
    expect(message, contains('123456'));
  });

  test('MAC and existing LAN/custom-server requests keep local WOL', () async {
    for (final input in [
      (id: '00-11-22-33-44-55', server: publicApiOrigin, token: 'token'),
      (id: '123456', server: internalApiOrigin, token: ''),
      (id: '123456', server: 'https://custom.example', token: 'token'),
    ]) {
      String? localId;
      final message = await requestWakeOnLan(input.id,
          server: input.server,
          token: input.token,
          senderId: '',
          sendLocal: (id) async => localId = id,
          post: (_, {headers, body}) async => fail('Must keep local WOL'));
      expect(localId, input.id);
      expect(message, contains('trong LAN'));
    }
    for (final error in ['DeviceNotFound', 'NoValidMacAddressFound']) {
      String? localId;
      final message = await requestWakeOnLan('123456',
          server: internalApiOrigin,
          token: 'token',
          senderId: '',
          sendLocal: (id) async => localId = id,
          post: (_, {headers, body}) async =>
              Response(jsonEncode({'code': 500, 'message': error}), 200));
      expect(localId, '123456');
      expect(message, contains('trong LAN'));
    }
  });

  test('server errors and unauthenticated public requests never report success',
      () async {
    Future<String> request({String token = 'token', Response? response}) =>
        requestWakeOnLan('123456',
            server: publicApiOrigin,
            token: token,
            senderId: '',
            sendLocal: (_) async => fail('Must not silently fall back to LAN'),
            post: (_, {headers, body}) async {
              if (response == null) throw ClientException('offline');
              return response;
            });
    await expectLater(request(token: ''), throwsException);
    await expectLater(request(), throwsException);
    for (final response in [
      Response('Unauthorized', 401),
      Response('{"code":500,"message":"NoValidMacAddressFound"}', 200),
      Response('{"code":500,"message":"DeviceNotFound"}', 200),
      Response('{"code":200,"data":{"error":"No relay"}}', 200),
      Response('{"code":200,"data":{"method":"direct","sent_count":0}}', 200),
      Response('<html>Bad gateway</html>', 502),
    ]) {
      await expectLater(request(response: response), throwsException);
    }
    expect(
        await request(
            response: Response(
                '{"code":200,"data":{"method":"relay_ws","sent_count":1}}',
                200)),
        contains('đã chuyển yêu cầu WOL'));
  });
}
