// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/widgets/api_connection_badge.dart';
import 'package:flutter_hbb/utils/api_connection_status.dart';
import 'package:flutter_hbb/utils/api_endpoint_selector.dart';

void main() {
  tearDown(() {
    apiConnectionStatus.value = (origin: null, failed: false);
  });

  testWidgets('shows actual API route, failure and recovery without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 120));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: const Scaffold(body: Center(child: ApiConnectionBadge())),
    )));
    expect(find.text('API: Chưa xác định'), findsOneWidget);
    reportApiConnection(Uri.parse('$internalApiOrigin/api/test?token=private'));
    await tester.pump();
    expect(find.text('API: Nội bộ'), findsOneWidget);
    final tip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tip.message, contains(internalApiOrigin));
    expect(tip.message, isNot(contains('private')));
    expect(tip.message, isNot(contains('/api/test')));
    reportApiConnection(Uri.parse(publicApiOrigin), failed: true);
    await tester.pump();
    expect(find.text('API: Public · Lỗi'), findsOneWidget);
    reportApiConnection(Uri.parse(publicApiOrigin));
    await tester.pump();
    expect(find.text('API: Public'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('API: Public'));
    await tester.pump();
    expect(find.textContaining(publicApiOrigin), findsOneWidget);
  });
}
