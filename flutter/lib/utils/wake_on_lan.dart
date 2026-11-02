// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'dart:convert';
import 'package:http/http.dart' show Response;
import 'api_endpoint_selector.dart';

Future<String> requestWakeOnLan(
  String id, {
  required String server,
  required String token,
  required String senderId,
  required Future<void> Function(String) sendLocal,
  required Future<Response> Function(Uri,
          {Map<String, String>? headers, Object? body})
      post,
}) async {
  id = id.trim().replaceAll(' ', '');
  if (id.isEmpty) {
    throw Exception('Vui lòng nhập ID hoặc địa chỉ MAC của thiết bị cần bật');
  }
  server = server.trim().replaceAll(RegExp(r'/+$'), '');
  final endpoint = Uri.tryParse(server);
  final hospital = endpoint != null && isHospitalApi(endpoint);
  final isMac = RegExp(r'^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$').hasMatch(id);
  if (isMac ||
      !hospital ||
      (token.isEmpty && endpoint.origin == internalApiOrigin)) {
    await sendLocal(id);
    return 'Đã yêu cầu phát WOL trong LAN đến $id';
  }
  if (token.isEmpty) {
    throw Exception('Vui lòng đăng nhập để bật máy qua máy chủ');
  }
  final response = await post(
    Uri.parse('$server/admin/devices/${Uri.encodeComponent(id)}/wol'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'sender_id': senderId}),
  );
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw Exception('Phiên đăng nhập hết hạn hoặc không có quyền bật máy');
  }
  if (response.statusCode != 200) {
    throw Exception('Máy chủ WOL trả về HTTP ${response.statusCode}');
  }
  final result = jsonDecode(utf8.decode(response.bodyBytes));
  if (result is! Map) {
    throw const FormatException('Phản hồi WOL không hợp lệ');
  }
  final data = result['data'];
  if (endpoint.origin == internalApiOrigin &&
      const ['DeviceNotFound', 'NoValidMacAddressFound']
          .contains(result['message'])) {
    await sendLocal(id);
    return 'Đã yêu cầu phát WOL trong LAN đến $id';
  }
  if (result['code'] != 200 || data is! Map || data['error'] != null) {
    throw Exception(data is Map && data['error'] != null
        ? data['error']
        : result['message'] ?? result['error'] ?? 'Yêu cầu WOL thất bại');
  }
  if (data['method'] == 'relay') {
    return 'Đã xếp hàng WOL cho $id, chờ máy trung gian trong LAN';
  }
  if (data['sent_count'] is! num || data['sent_count'] <= 0) {
    throw Exception('Máy chủ chưa gửi được yêu cầu WOL');
  }
  return 'Máy chủ đã chuyển yêu cầu WOL đến $id';
}
