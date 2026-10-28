// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/support_ticket_mobile_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bvdkkh/support_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('delivery waits for the first notification permission prompt', () async {
    final permission = Completer<bool>();
    final promptStarted = Completer<void>();
    var shown = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'requestPermission') {
        promptStarted.complete();
        return permission.future;
      }
      shown = true;
      return true;
    });
    final requested = requestSupportNotificationPermission();
    await promptStarted.future;
    final delivery = showMobileSupportNotification(
      ticketId: 1,
      title: 'New',
      body: 'Ticket',
      sound: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(shown, isFalse);
    permission.complete(true);
    expect(await requested, isTrue);
    await delivery;
    expect(shown, isTrue);
  });

  test('requests notification permission and passes a muted ticket to native',
      () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    expect(await requestSupportNotificationPermission(), isTrue);
    await showMobileSupportNotification(
      ticketId: 7,
      title: 'Hoàn tất',
      body: 'Đã xử lý',
      sound: false,
    );
    expect(calls.first.method, 'requestPermission');
    expect(calls.last.method, 'show');
    expect(calls.last.arguments, {
      'id': 7,
      'title': 'Hoàn tất',
      'body': 'Đã xử lý',
      'sound': false,
    });
  });

  test(
      'permission rejection and native delivery failures stay visible to the caller',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'requestPermission') return false;
      throw PlatformException(
          code: 'notifications_disabled', message: 'Disabled');
    });
    expect(await requestSupportNotificationPermission(), isFalse);
    await expectLater(
      showMobileSupportNotification(
          ticketId: 8, title: 'New', body: 'Ticket', sound: true),
      throwsA(isA<PlatformException>()
          .having((e) => e.code, 'code', 'notifications_disabled')),
    );
  });
}
