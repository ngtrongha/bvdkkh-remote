// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/support_ticket_feed_cursor.dart';

void main() {
  Map<String, dynamic> feed(int next, List<int> ids, {bool more = false}) => {
        'code': 200,
        'data': ids.map((id) => {'id': id}).toList(),
        'next_since_id': next,
        'has_more': more,
        'open_count': ids.length,
      };
  test('zero baseline receives first ticket; existing backlog stays silent',
      () {
    final cursor = SupportTicketFeedCursor();
    expect(cursor.consume(feed(0, [])), isEmpty);
    expect(cursor.sinceId, 0);
    expect(cursor.consume(feed(1, [1])).single['id'], 1);
    expect(cursor.consume(feed(1, [])), isEmpty);
    final restored = SupportTicketFeedCursor();
    expect(restored.consume(feed(20, [])), isEmpty);
    expect(restored.consume(feed(21, [21])).single['id'], 21);
  });
  test('drains ascending pages and malformed responses do not advance cursor',
      () {
    final cursor = SupportTicketFeedCursor()..consume(feed(0, []));
    expect(
        cursor
            .consume(feed(20, List.generate(20, (i) => i + 1), more: true))
            .length,
        20);
    expect(cursor.consume(feed(23, [21, 22, 23])).length, 3);
    expect(() => cursor.consume({...feed(24, []), 'data': null}),
        throwsFormatException);
    expect(() => cursor.consume(feed(25, [25, 24])), throwsFormatException);
    expect(
        () => cursor.consume(feed(23, [], more: true)), throwsFormatException);
    expect(cursor.sinceId, 23);
    expect(cursor.consume(feed(24, [24])).single['id'], 24);
  });
}
