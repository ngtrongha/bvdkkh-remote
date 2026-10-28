// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

enum SupportTicketClientEvent { assigned, resolved }

class SupportTicketClientState {
  int _ticketId = 0;
  String _lastStatus = '';
  bool _notifiedAssigned = false;
  bool _notifiedResolved = false;

  void track(int ticketId) {
    _ticketId = ticketId;
    _lastStatus = 'open';
    _notifiedAssigned = false;
    _notifiedResolved = false;
  }

  SupportTicketClientEvent? consume(int ticketId, String status) {
    if (ticketId <= 0 || ticketId < _ticketId) return null;
    if (ticketId > _ticketId) track(ticketId);
    status = status.toLowerCase().trim();
    if (status == 'assigned' || status == 'in_progress') {
      if (!_notifiedAssigned || _lastStatus != status) {
        _notifiedAssigned = true;
        _lastStatus = status;
        return SupportTicketClientEvent.assigned;
      }
    } else if (status == 'resolved' || status == 'closed') {
      if (!_notifiedResolved) {
        _notifiedResolved = true;
        _lastStatus = status;
        return SupportTicketClientEvent.resolved;
      }
    }
    return null;
  }
}
