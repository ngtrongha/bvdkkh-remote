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
        final internal = origin == internalApiOrigin;
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
            ? colors.error
            : origin == null
                ? colors.onSurfaceVariant
                : internal
                    ? colors.primary
                    : colors.secondary;
        final detail = origin == null
            ? 'Chưa có phản hồi API trong phiên này.'
            : '$origin\n${connection.failed ? 'Yêu cầu gần nhất gặp lỗi kết nối.' : 'Đường API của phản hồi gần nhất.'}';
        return Tooltip(
          message:
              '$label\n$detail\nTrạng thái API độc lập với phiên điều khiển từ xa.',
          triggerMode: TooltipTriggerMode.tap,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    connection.failed
                        ? Icons.cloud_off_outlined
                        : internal
                            ? Icons.lan_outlined
                            : Icons.cloud_outlined,
                    size: 14,
                    color: color),
                const SizedBox(width: 5),
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
