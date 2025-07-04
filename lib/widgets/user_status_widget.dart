import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_status_service.dart';

class UserStatusWidget extends StatelessWidget {
  final String userId;
  final double dotSize;
  final bool showLastSeen;
  final TextStyle? lastSeenStyle;

  const UserStatusWidget({
    super.key,
    required this.userId,
    this.dotSize = 12.0,
    this.showLastSeen = true,
    this.lastSeenStyle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserStatusService().getUserStatusStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data;
        final isOnline = UserStatusService().isUserOnline(status);
        final lastSeen = status?['lastSeen'] as Timestamp?;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Online indicator dot
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
            // Last seen text (optional)
            if (showLastSeen && !isOnline && lastSeen != null) ...[
              const SizedBox(height: 2),
              Text(
                UserStatusService().formatLastSeen(lastSeen),
                style: lastSeenStyle ?? const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// Compact version for use in lists
class UserStatusIndicator extends StatelessWidget {
  final String userId;
  final double size;
  final Color? backgroundColor;

  const UserStatusIndicator({
    super.key,
    required this.userId,
    this.size = 12.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserStatusService().getUserStatusStream(userId),
      builder: (context, snapshot) {
        final isOnline = snapshot.hasData && UserStatusService().isUserOnline(snapshot.data);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(
              color: backgroundColor ?? Colors.white,
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

// Status text widget
class UserStatusText extends StatelessWidget {
  final String userId;
  final TextStyle? style;

  const UserStatusText({
    super.key,
    required this.userId,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserStatusService().getUserStatusStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            'Offline',
            style: style ?? const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          );
        }

        final status = snapshot.data;
        final isOnline = UserStatusService().isUserOnline(status);
        final lastSeen = status?['lastSeen'] as Timestamp?;

        return Text(
          UserStatusService().getStatusText(status),
          style: style ?? TextStyle(
            fontSize: 12,
            color: isOnline ? Colors.green : Colors.grey,
            fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
          ),
        );
      },
    );
  }
} 