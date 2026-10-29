// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

class _SettingsBinding extends Fake implements RustdeskImpl {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #translate:
        return invocation.namedArguments[#name];
      case #mainGetBuildinOption:
      case #mainGetLocalOption:
        return '';
      case #isOutgoingOnly:
      case #isIncomingOnly:
      case #isDisableSettings:
      case #isDisableAccount:
        return false;
      case #mainGetCommon:
        return Future.value('true');
      case #mainGetLicense:
      case #mainGetVersion:
      case #mainGetBuildDate:
      case #mainGetFingerprint:
      case #mainGetMyId:
        return Future.value('test');
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  testWidgets('Settings require Admin and lock again after logout',
      (tester) async {
    platformFFI.setBindingForTesting(_SettingsBinding());
    isTest = true;
    await initGlobalFFI();
    addTearDown(() {
      gFFI.userModel.isAdmin.value = false;
      isTest = false;
      Get.reset();
    });

    await tester.pumpWidget(MaterialApp(
      home: DesktopSettingPage(initialTabkey: SettingsTabKey.about),
    ));
    expect(find.text('Settings Locked'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    gFFI.userModel.userName.value = 'technician';
    await tester.pump();
    expect(find.text('Administrator Access Required'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    gFFI.userModel.isAdmin.value = true;
    await tester.pump();
    await tester.pump();
    expect(find.text('Settings Locked'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Version: test'), findsOneWidget);

    gFFI.userModel.userName.value = '';
    gFFI.userModel.isAdmin.value = false;
    await tester.pump();
    expect(find.text('Settings Locked'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
