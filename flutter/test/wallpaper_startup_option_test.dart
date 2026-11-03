// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/platform_model.dart';

class _WallpaperBinding extends Fake implements RustdeskImpl {
  @override
  bool isCustomClient({dynamic hint}) => false;
}

void main() {
  setUpAll(() => platformFFI.setBindingForTesting(_WallpaperBinding()));

  for (final key in [
    kOptionEnableWallpaperUpdateOnStartup,
    kOptionEnableWallpaperLock,
    kOptionEnableSupportTicketSound,
    kOptionEnableSupportTicketNotifications,
  ]) {
    test('$key defaults on and preserves the saved choice', () {
      expect(option2bool(key, ''), isTrue);
      expect(option2bool(key, bool2option(key, false)), isFalse);
      expect(option2bool(key, bool2option(key, true)), isTrue);
    });
  }
}
