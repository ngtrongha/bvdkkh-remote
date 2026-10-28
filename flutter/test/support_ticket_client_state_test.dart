// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/support_ticket_client_state.dart';

void main() {
  test('a later ticket receives its own assigned and completed notifications',
      () {
    final state = SupportTicketClientState()..track(1);
    expect(state.consume(1, 'assigned'), SupportTicketClientEvent.assigned);
    expect(state.consume(1, 'resolved'), SupportTicketClientEvent.resolved);
    expect(state.consume(2, 'assigned'), SupportTicketClientEvent.assigned);
    expect(state.consume(2, 'resolved'), SupportTicketClientEvent.resolved);
  });

  test(
      'completion first seen by polling is delivered once; older tickets stay silent',
      () {
    final state = SupportTicketClientState();
    expect(state.consume(1, 'resolved'), SupportTicketClientEvent.resolved);
    expect(state.consume(2, 'closed'), SupportTicketClientEvent.resolved);
    expect(state.consume(2, 'closed'), isNull);
    expect(state.consume(1, 'assigned'), isNull);
    expect(state.consume(0, 'resolved'), isNull);
  });
}
