// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../consts.dart';
import 'support_ticket_client_state.dart';
import 'support_ticket_feed_cursor.dart';
import 'support_ticket_mobile_notifications.dart';
import '../models/platform_model.dart';
import '../utils/http_service.dart' as http;

class SupportTicket {
  final int id;
  final String deviceId;
  final String hostname;
  final String username;
  final String ipAddress;
  final String category;
  final String priority;
  final String description;
  final String contactName;
  final String contactPhone;
  final String status;
  final String createdAt;
  final String assignedAdmin;
  final String resolutionNote;

  SupportTicket({
    required this.id,
    required this.deviceId,
    required this.hostname,
    required this.username,
    required this.ipAddress,
    required this.category,
    required this.priority,
    required this.description,
    required this.contactName,
    required this.contactPhone,
    required this.status,
    required this.createdAt,
    this.assignedAdmin = '',
    this.resolutionNote = '',
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      deviceId: (json['device_id'] ?? '').toString(),
      hostname: (json['hostname'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      ipAddress: (json['ip_address'] ?? '').toString(),
      category: (json['category'] ?? 'hardware_other').toString(),
      priority: (json['priority'] ?? 'normal').toString(),
      description: (json['description'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      contactPhone: (json['contact_phone'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      assignedAdmin: (json['assigned_admin'] ?? '').toString(),
      resolutionNote: (json['resolution_note'] ?? '').toString(),
    );
  }

  String get categoryDisplay {
    switch (category) {
      case 'his_lis':
        return 'Phần mềm Bệnh viện (HIS / LIS / PACS)';
      case 'printer':
        return 'Lỗi Máy In / Không in được phiếu';
      case 'network':
        return 'Mất mạng / Không kết nối được Internet';
      case 'slow_pc':
        return 'Máy tính bị chậm / Treo máy';
      case 'software_install':
        return 'Cần cài đặt phần mềm mới';
      case 'hardware_other':
        return 'Sự cố phần cứng / Khác';
      default:
        return category;
    }
  }
}

class SupportTicketListener {
  static final SupportTicketListener instance =
      SupportTicketListener._internal();
  SupportTicketListener._internal();

  final ValueNotifier<int?> adminOpenCount = ValueNotifier(null);
  final ValueNotifier<String?> adminNotificationError = ValueNotifier(null);
  int _adminGeneration = 0;
  String _adminToken = '';

  // Admin polling fields
  Timer? _adminPollingTimer;
  bool _isAdminRunning = false;
  bool _isAdminChecking = false;
  SupportTicketFeedCursor _adminFeed = SupportTicketFeedCursor();

  // Client watcher fields (runs for user on their workstation)
  Timer? _clientPollingTimer;
  bool _isClientChecking = false;
  final _clientState = SupportTicketClientState();

  bool get isRunning => _isAdminRunning;
  bool get isClientWatching => _clientPollingTimer != null;

  // ---------------------------------------------------------------------------
  // ADMIN MODE: Lắng nghe toàn bộ sự cố mới từ nhân viên / phòng khám
  // ---------------------------------------------------------------------------
  void start() {
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token.isEmpty) { stop(); return; }
    if (_isAdminRunning && _adminToken == token) return;
    stop();
    _adminToken = token;
    _isAdminRunning = true;
    _adminFeed = SupportTicketFeedCursor();
    debugPrint('[SupportTicketListener] Started for Admin user');

    // Run first check immediately
    _checkNewTickets();

    // Periodic check every 5 seconds
    _adminPollingTimer?.cancel();
    _adminPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkNewTickets();
    });
  }

  void stop() {
    _adminGeneration++;
    _isAdminChecking = false;
    _adminToken = '';
    adminNotificationError.value = null;
    adminOpenCount.value = null;
    _adminPollingTimer?.cancel();
    _adminPollingTimer = null;
    _isAdminRunning = false;
    _adminFeed = SupportTicketFeedCursor();
    debugPrint('[SupportTicketListener] Stopped Admin listener');
  }

  Future<void> _checkNewTickets() async {
    if (!_isAdminRunning || _isAdminChecking) return;
    final generation = _adminGeneration;
    _isAdminChecking = true;
    try {
      var apiServer = await bind.mainGetApiServer();
      if (apiServer.isEmpty) throw StateError('API server is empty');
      if (!apiServer.startsWith('http://') && !apiServer.startsWith('https://')) {
        apiServer = 'http://$apiServer';
      }
      if (generation != _adminGeneration) return;
      for (var page = 0; page < 10; page++) {
        final cursor = _adminFeed.sinceId;
        final query = cursor == null ? '' : '?since_id=$cursor';
        final response = await http.get(
          Uri.parse('$apiServer/api/support/ticket/feed$query'),
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $_adminToken'},
        ).timeout(const Duration(seconds: 4));
        if (generation != _adminGeneration) return;
        if ([401, 403, 406].contains(response.statusCode)) {
          adminNotificationError.value = 'Phiên hoặc quyền admin không còn hợp lệ. Vui lòng đăng nhập lại.';
          return;
        }
        if (response.statusCode != 200) throw StateError('Feed HTTP ${response.statusCode}');
        final body = json.decode(utf8.decode(response.bodyBytes));
        final tickets = _adminFeed.consume(body as Map<String, dynamic>)
            .map(SupportTicket.fromJson).toList();
        adminOpenCount.value = body['open_count'] as int;
        adminNotificationError.value = null;
        for (final ticket in tickets) {
          _onNewTicketReceived(ticket);
        }
        if (body['has_more'] != true) break;
      }
    } catch (e) {
      if (generation == _adminGeneration) {
        adminNotificationError.value = 'Mất kết nối nhận thông báo. Đang tự động thử lại…';
        debugPrint('[SupportTicketListener] Admin feed failed: $e');
      }
    } finally {
      if (generation == _adminGeneration) _isAdminChecking = false;
    }
  }

  void checkNow() {
    _checkNewTickets();
    if (isClientWatching) _checkClientTicket();
  }

  void _onNewTicketReceived(SupportTicket ticket) {
    debugPrint(
        '[SupportTicketListener] New Ticket #${ticket.id} from ${ticket.hostname} (${ticket.deviceId})');

    // 1. Play audible chime
    _playChime();

    final displayName =
        ticket.hostname.isNotEmpty ? ticket.hostname : ticket.deviceId;
    _showSystemNotification(
      ticketId: ticket.id,
      title: '[BVĐKKH] Yêu cầu hỗ trợ IT: $displayName',
      body: '${ticket.category}: ${ticket.description}\nID: ${ticket.deviceId}',
    );

    // 3. Bring window to front
    if (isDesktop) {
      try {
        windowOnTop(null);
      } catch (e) {
        debugPrint(
            '[SupportTicketListener] Failed to bring window to front: $e');
      }
    }

    // 4. Floating In-App Banner with 1-click connect button
    _showInAppBanner(ticket);
  }

  // ---------------------------------------------------------------------------
  // CLIENT MODE: Theo dõi sự cố của chính máy trạm này & Báo Toast khi IT phản hồi
  // ---------------------------------------------------------------------------
  void initClientWatcher() {
    if (_clientPollingTimer != null) return;
    if (isAndroid || isIOS) _requestMobileNotificationPermission();
    debugPrint('[SupportTicketListener] Initializing Client Watcher');

    // First check after 2 seconds
    Timer(const Duration(seconds: 2), () {
      _checkClientTicket();
    });

    // Check periodically every 15 seconds
    _clientPollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkClientTicket();
    });
  }

  void trackTicket(int ticketId) {
    debugPrint('[SupportTicketListener] Tracking Client Ticket #$ticketId');
    _clientState.track(ticketId);

    // Expedite checking: check immediately and keep 10-second polling
    _clientPollingTimer?.cancel();
    _checkClientTicket();
    _clientPollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkClientTicket();
    });
  }

  void stopClientWatcher() {
    _clientPollingTimer?.cancel();
    _clientPollingTimer = null;
    _clientState.track(0);
  }

  Future<void> _checkClientTicket() async {
    if (_isClientChecking) return;
    _isClientChecking = true;

    try {
      var apiServer = await bind.mainGetApiServer();
      if (apiServer.isEmpty) return;
      if (!apiServer.startsWith('http://') &&
          !apiServer.startsWith('https://')) {
        apiServer = 'http://$apiServer';
      }

      final myId = await bind.mainGetMyId();
      if (myId.isEmpty) return;
      final cleanId = myId.replaceAll(' ', '');

      final url =
          Uri.parse('$apiServer/api/support/ticket/latest?device_id=$cleanId');
      final response = await http.get(url, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return;

      final body = json.decode(utf8.decode(response.bodyBytes));
      if (body['code'] != 200 || body['data'] == null) return;

      final ticket =
          SupportTicket.fromJson(body['data'] as Map<String, dynamic>);

      final event = _clientState.consume(ticket.id, ticket.status);

      // 1. KTV IT đã tiếp nhận (assigned / in_progress)
      if (event == SupportTicketClientEvent.assigned) {
        _onClientTicketAssigned(ticket);
      }

      // 2. KTV IT đã xử lý xong (resolved / closed)
      if (event == SupportTicketClientEvent.resolved) {
        _onClientTicketResolved(ticket);

        // Once resolved, relax the polling interval back to 60s
        _clientPollingTimer?.cancel();
        _clientPollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
          _checkClientTicket();
        });
      }
    } catch (e) {
      debugPrint('[SupportTicketListener] Error checking client ticket: $e');
    } finally {
      _isClientChecking = false;
    }
  }

  void _onClientTicketAssigned(SupportTicket ticket) {
    if (!mainGetBoolOptionSync(kOptionEnableSupportTicketNotifications)) return;
    debugPrint('[SupportTicketListener] Client Ticket #${ticket.id} Assigned');
    _playChime();

    final adminName = ticket.assignedAdmin.isNotEmpty
        ? ticket.assignedAdmin
        : 'Kỹ thuật viên IT';
    final title = '[BVĐKKH IT] Tiếp nhận sự cố #${ticket.id}';
    final body = '$adminName đã tiếp nhận và đang hỗ trợ xử lý sự cố của bạn.';

    _showSystemNotification(ticketId: ticket.id, title: title, body: body);

    _showClientAssignedBanner(ticket);
  }

  void _onClientTicketResolved(SupportTicket ticket) {
    if (!mainGetBoolOptionSync(kOptionEnableSupportTicketNotifications)) return;
    debugPrint('[SupportTicketListener] Client Ticket #${ticket.id} Resolved');
    _playChime();

    final adminName = ticket.assignedAdmin.isNotEmpty
        ? ticket.assignedAdmin
        : 'Kỹ thuật viên IT';
    final title = '[BVĐKKH IT] Sự cố #${ticket.id} đã được xử lý xong!';
    final note = ticket.resolutionNote.isNotEmpty
        ? ticket.resolutionNote
        : 'Sự cố đã được kiểm tra và xử lý hoàn tất.';
    final body = 'KTV: $adminName\nPhản hồi: $note';

    _showSystemNotification(ticketId: ticket.id, title: title, body: body);

    _showClientResolvedBanner(ticket);
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATION UTILITIES: Âm thanh & Native Windows Toast
  // ---------------------------------------------------------------------------
  Future<void> _playChime() async {
    if (isAndroid || isIOS) return;
    if (!mainGetBoolOptionSync(kOptionEnableSupportTicketSound)) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
      if (Platform.isWindows) {
        final user32 = DynamicLibrary.open('user32.dll');
        final messageBeep =
            user32.lookupFunction<Int32 Function(Uint32), int Function(int)>(
                'MessageBeep');
        messageBeep(0x00000030); // MB_ICONEXCLAMATION
      }
    } catch (e) {
      debugPrint('[SupportTicketListener] Error playing chime: $e');
    }
  }

  Future<void> _requestMobileNotificationPermission() async {
    try {
      if (!await requestSupportNotificationPermission()) {
        debugPrint('[SupportTicketListener] Mobile notifications are disabled');
      }
    } catch (e) {
      debugPrint('[SupportTicketListener] Notification permission failed: $e');
    }
  }

  Future<void> _showSystemNotification({
    required int ticketId,
    required String title,
    required String body,
  }) async {
    if (Platform.isWindows) {
      await _showWindowsToast(title: title, body: body);
    } else if (isAndroid || isIOS) {
      try {
        await showMobileSupportNotification(
          ticketId: ticketId,
          title: title,
          body: body,
          sound: mainGetBoolOptionSync(kOptionEnableSupportTicketSound),
        );
      } on PlatformException catch (e) {
        debugPrint('[SupportTicketListener] Mobile notification failed: $e');
        BotToast.showText(text: e.code == 'notifications_disabled'
            ? 'Thông báo hệ thống đang bị tắt. Hãy bật thông báo cho BVĐKKH - Remote trong Cài đặt thiết bị.'
            : 'Không thể hiển thị thông báo hệ thống: ${e.message}');
      } catch (e) {
        debugPrint('[SupportTicketListener] Mobile notification failed: $e');
        BotToast.showText(text: 'Không thể hiển thị thông báo hệ thống: $e');
      }
    }
  }

  Future<void> _showWindowsToast({
    required String title,
    required String body,
    String sound = 'Reminder',
  }) async {
    if (!Platform.isWindows) return;
    final soundEnabled = mainGetBoolOptionSync(kOptionEnableSupportTicketSound);
    try {
      final psScript = '''
\$ErrorActionPreference = 'Stop'
\$ProgressPreference = 'SilentlyContinue'
\$payload = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(\$env:BVDKKH_TOAST_DATA)) | ConvertFrom-Json
\$title = [string]\$payload.title
\$body = [string]\$payload.body
\$xmlTitle = [Security.SecurityElement]::Escape(\$title)
\$xmlBody = [Security.SecurityElement]::Escape(\$body)
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null
    [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > \$null
    \$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe'
    \$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$appId)
    if (\$notifier.Setting.ToString() -ne 'Enabled') {
        [Console]::Error.WriteLine('Windows notifications are disabled: ' + \$notifier.Setting.ToString())
        exit 2
    }
    \$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    \$toastXml = @"
<toast duration="long">
  <visual>
    <binding template="ToastGeneric">
      <text>\$xmlTitle</text>
      <text>\$xmlBody</text>
    </binding>
  </visual>
  <audio ${soundEnabled ? 'src="ms-winsoundevent:Notification.$sound"' : 'silent="true"'}/>
</toast>
"@
    \$xml.LoadXml(\$toastXml)
    \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
    \$notifier.Show(\$toast)
} catch {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        if (-not \$payload.sound) {
            # WinForms ShowBalloonTip does not expose NIIF_NOSOUND.
            Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Drawing;
public static class SilentSupportBalloon {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NotifyIconData {
        public uint cbSize;
        public IntPtr hWnd;
        public uint uID, uFlags, uCallbackMessage;
        public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string szTip;
        public uint dwState, dwStateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string szInfo;
        public uint uTimeout;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string szInfoTitle;
        public uint dwInfoFlags;
        public Guid guidItem;
        public IntPtr hBalloonIcon;
    }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool Shell_NotifyIconW(uint message, ref NotifyIconData data);
    public static void Show(string title, string body) {
        using (var window = new Form()) {
            var data = new NotifyIconData {
                cbSize = (uint)Marshal.SizeOf(typeof(NotifyIconData)),
                hWnd = window.Handle, uID = 1, uFlags = 2 | 4 | 16,
                hIcon = SystemIcons.Information.Handle, szTip = "BVĐKKH IT",
                szInfo = body.Length > 255 ? body.Substring(0, 255) : body,
                szInfoTitle = title.Length > 63 ? title.Substring(0, 63) : title,
                uTimeout = 10000, dwInfoFlags = 1 | 16
            };
            if (!Shell_NotifyIconW(0, ref data))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            try {
                var timer = System.Diagnostics.Stopwatch.StartNew();
                while (timer.ElapsedMilliseconds < 5000) {
                    Application.DoEvents();
                    System.Threading.Thread.Sleep(100);
                }
            } finally { Shell_NotifyIconW(2, ref data); }
        }
    }
}
'@
            [SilentSupportBalloon]::Show(\$title, \$body)
            exit 0
        }
        \$notify = New-Object System.Windows.Forms.NotifyIcon
        \$notify.Icon = [System.Drawing.SystemIcons]::Information
        \$notify.BalloonTipTitle = \$title
        \$notify.BalloonTipText = \$body
        \$notify.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        \$notify.Visible = \$true
        \$notify.ShowBalloonTip(10000)
        \$sw = [System.Diagnostics.Stopwatch]::StartNew()
        while (\$sw.ElapsedMilliseconds -lt 5000) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
        \$notify.Visible = \$false
        \$notify.Dispose()
    } catch {
        [Console]::Error.WriteLine(\$_.Exception.Message)
        exit 1
    }
}
''';

      final utf16leBytes = <int>[];
      for (final char in psScript.codeUnits) {
        utf16leBytes.add(char & 0xFF);
        utf16leBytes.add((char >> 8) & 0xFF);
      }
      final encoded = base64.encode(utf16leBytes);

      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-OutputFormat',
        'Text',
        '-WindowStyle',
        'Hidden',
        '-EncodedCommand',
        encoded,
      ], environment: {
        'BVDKKH_TOAST_DATA': base64.encode(utf8.encode(json.encode(
            {'title': title, 'body': body, 'sound': soundEnabled}))),
      });
      if (result.exitCode != 0) {
        final reason = result.stderr.toString().trim();
        debugPrint('[SupportTicketListener] Windows notification failed: $reason');
        BotToast.showText(
          text: result.exitCode == 2
              ? 'Thông báo Windows đang bị tắt. Hãy bật trong Cài đặt Windows > Hệ thống > Thông báo.'
              : 'Không thể hiển thị thông báo Windows: $reason',
        );
      }
    } catch (e) {
      debugPrint('[SupportTicketListener] Failed to show Windows toast: $e');
      BotToast.showText(text: 'Không thể hiển thị thông báo Windows: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // IN-APP BANNERS: Hiển thị nổi trong app RustDesk
  // ---------------------------------------------------------------------------
  void _showInAppBanner(SupportTicket ticket) {
    final displayName =
        ticket.hostname.isNotEmpty ? ticket.hostname : ticket.deviceId;
    final contact = ticket.contactName.isNotEmpty
        ? '${ticket.contactName} (${ticket.contactPhone})'
        : (ticket.username.isNotEmpty ? ticket.username : '');

    BotToast.showCustomNotification(
      duration: const Duration(seconds: 30),
      toastBuilder: (cancelFunc) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 10,
          color: const Color(0xFF1E293B), // Dark slate blue
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
                color: Color(0xFFE11D48), width: 2), // Rose/Red warning border
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.support_agent,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YÊU CẦU HỖ TRỢ IT MỚI',
                            style: TextStyle(
                              color: Color(0xFFFDA4AF),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Máy: $displayName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 20),
                      onPressed: cancelFunc,
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (contact.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.person,
                                color: Colors.white60, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              contact,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ticket.category,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        ticket.description,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'ID: ${ticket.deviceId}',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontFamily: 'monospace'),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: cancelFunc,
                      child: const Text('Bỏ qua'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text(
                        'KẾT NỐI NGAY',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        cancelFunc();
                        final ctx = Get.context;
                        if (ctx != null) {
                          connect(ctx, ticket.deviceId);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClientAssignedBanner(SupportTicket ticket) {
    final adminName = ticket.assignedAdmin.isNotEmpty
        ? ticket.assignedAdmin
        : 'Kỹ thuật viên IT';

    BotToast.showCustomNotification(
      duration: const Duration(seconds: 15),
      toastBuilder: (cancelFunc) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 10,
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF0284C7), width: 2),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KỸ THUẬT VIÊN ĐÃ TIẾP NHẬN SỰ CỐ #${ticket.id}',
                        style: const TextStyle(
                          color: Color(0xFF7DD3FC),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$adminName đã tiếp nhận và đang hỗ trợ xử lý sự cố của bạn.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: cancelFunc,
                  tooltip: 'Đóng',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClientResolvedBanner(SupportTicket ticket) {
    final adminName = ticket.assignedAdmin.isNotEmpty
        ? ticket.assignedAdmin
        : 'Kỹ thuật viên IT';
    final note = ticket.resolutionNote.isNotEmpty
        ? ticket.resolutionNote
        : 'Sự cố đã được kiểm tra và xử lý xong.';

    BotToast.showCustomNotification(
      duration: const Duration(seconds: 30),
      toastBuilder: (cancelFunc) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 10,
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF10B981), width: 2),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SỰ CỐ #${ticket.id} ĐÃ ĐƯỢC XỬ LÝ XONG!',
                            style: const TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Kỹ thuật viên: $adminName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 18),
                      onPressed: cancelFunc,
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phản hồi từ KTV:',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: cancelFunc,
                    child: const Text('ĐÃ HIỂU & ĐÓNG'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
