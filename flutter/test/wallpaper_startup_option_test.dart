// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';

void main() {
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
