// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'package:flutter/foundation.dart';

typedef ApiConnection = ({String? origin, bool failed});

final apiConnectionStatus =
    ValueNotifier<ApiConnection>((origin: null, failed: false));

void reportApiConnection(Uri endpoint, {bool failed = false}) {
  if (!endpoint.hasAuthority ||
      (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
    return;
  }
  apiConnectionStatus.value = (origin: endpoint.origin, failed: failed);
}
