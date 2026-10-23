// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

class SupportTicketFeedCursor {
  int? sinceId;

  List<Map<String, dynamic>> consume(Map<String, dynamic> body) {
    final next = body['next_since_id'];
    final data = body['data'];
    if (body['code'] != 200 ||
        data is! List ||
        next is! int ||
        body['open_count'] is! int ||
        next < (sinceId ?? 0) ||
        (body['has_more'] == true && next <= (sinceId ?? 0))) {
      throw const FormatException('Invalid support feed');
    }
    final tickets = data.cast<Map<String, dynamic>>();
    var previous = sinceId ?? 0;
    for (final ticket in tickets) {
      final id = ticket['id'];
      if (id is! int || id <= previous || id > next) {
        throw const FormatException('Invalid support ticket order');
      }
      previous = id;
    }
    final fresh = sinceId == null ? <Map<String, dynamic>>[] : tickets;
    sinceId = next;
    return fresh;
  }
}
