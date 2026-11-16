// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

class NotificationFeedCursor {
  int? sinceId;

  List<Map<String, dynamic>> consume(
    Map<String, dynamic> body, {
    bool Function(Map<String, dynamic>)? isValid,
  }) {
    final next = body['next_since_id'];
    final data = body['data'];
    if (body['code'] != 200 ||
        data is! List ||
        next is! int ||
        next < (sinceId ?? 0) ||
        (body['has_more'] == true && next <= (sinceId ?? 0))) {
      throw const FormatException('Invalid notification feed');
    }
    final events = data.cast<Map<String, dynamic>>();
    var previous = sinceId ?? 0;
    for (final event in events) {
      final id = event['id'];
      if (id is! int ||
          id <= previous ||
          id > next ||
          isValid?.call(event) == false) {
        throw const FormatException('Invalid notification feed event');
      }
      previous = id;
    }
    final fresh = sinceId == null ? <Map<String, dynamic>>[] : events;
    sinceId = next;
    return fresh;
  }
}
