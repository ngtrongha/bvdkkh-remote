// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'package:flutter/material.dart';
import '../../utils/api_connection_status.dart';
import '../../utils/api_endpoint_selector.dart';

class ApiConnectionBadge extends StatelessWidget {
  const ApiConnectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ApiConnection>(
      valueListenable: apiConnectionStatus,
      builder: (context, connection, _) {
        final origin = connection.origin;
        final internal = isInternalApiOrigin(origin);
        final route = origin == null
            ? 'Chưa xác định'
            : internal
                ? 'Nội bộ'
                : origin == publicApiOrigin
                    ? 'Public'
                    : 'Tùy chỉnh';
        final label = 'API: $route${connection.failed ? ' · Lỗi' : ''}';
        final colors = Theme.of(context).colorScheme;
        final color = connection.failed
            ? const Color(0xFFEF4444)
            : origin == null
                ? colors.onSurfaceVariant
                : internal
                    ? const Color(0xFF10B981)
                    : const Color(0xFF0284C7);
        final detail = origin == null
            ? 'Chưa có phản hồi API trong phiên này.'
            : '$origin\n${connection.failed ? 'Yêu cầu gần nhất gặp lỗi kết nối.' : 'Đường API của phản hồi gần nhất.'}';
        return Tooltip(
          message:
              '$label\n$detail\nTrạng thái API độc lập với phiên điều khiển từ xa.',
          triggerMode: TooltipTriggerMode.tap,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 168),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withAlpha(72), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color))),
              ],
            ),
          ),
        );
      },
    );
  }
}
