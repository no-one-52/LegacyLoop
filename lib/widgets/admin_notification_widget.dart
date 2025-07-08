import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationWidget extends StatelessWidget {
  const AdminNotificationWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_actions')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final actions = snapshot.data?.docs ?? [];

        if (actions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent Admin Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...actions.map((action) {
                final data = action.data() as Map<String, dynamic>;
                final actionType = data['action'] ?? 'Unknown';
                final target = data['target'] ?? 'Unknown';
                final timestamp = data['timestamp'] as Timestamp?;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        _getActionIcon(actionType),
                        size: 16,
                        color: _getActionColor(actionType),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$actionType: $target',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          _formatTime(timestamp),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'ban':
        return Icons.block;
      case 'unban':
        return Icons.check_circle;
      case 'delete':
        return Icons.delete;
      case 'hide':
        return Icons.visibility_off;
      case 'unhide':
        return Icons.visibility;
      case 'announcement':
        return Icons.announcement;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'ban':
      case 'delete':
        return Colors.red;
      case 'unban':
      case 'unhide':
        return Colors.green;
      case 'hide':
        return Colors.orange;
      case 'announcement':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
} 