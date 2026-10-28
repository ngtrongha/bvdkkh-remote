// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà
import 'package:flutter/services.dart';

const _channel = MethodChannel('bvdkkh/support_notifications');
Future<bool>? _permissionRequest;

Future<bool> requestSupportNotificationPermission() {
  return _permissionRequest ??= _channel
      .invokeMethod<bool>('requestPermission')
      .then((granted) => granted == true)
      .whenComplete(() => _permissionRequest = null);
}

Future<void> showMobileSupportNotification({
  required int ticketId,
  required String title,
  required String body,
  required bool sound,
}) async {
  final permission = _permissionRequest;
  if (permission != null) await permission;
  final shown = await _channel.invokeMethod<bool>('show', {
    'id': ticketId,
    'title': title,
    'body': body,
    'sound': sound,
  });
  if (shown != true) {
    throw PlatformException(
      code: 'notification_failed',
      message: 'Không thể hiển thị thông báo hệ thống.',
    );
  }
}
