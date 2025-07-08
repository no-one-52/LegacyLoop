import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _notifications = _firestore.collection('notifications');

  /// Create a notification for a user
  static Future<void> createNotification({
    required String userId,
    required String type,
    required String fromUserId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      debugPrint(
          'Creating notification: type=$type, userId=$userId, fromUserId=$fromUserId');

      final notificationData = {
        'userId': userId,
        'type': type,
        'fromUserId': fromUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        ...?additionalData,
      };

      final docRef = await _notifications.add(notificationData);
      debugPrint('Notification created successfully with ID: ${docRef.id}');

      // Verify the notification was created
      final doc = await docRef.get();
      if (doc.exists) {
        debugPrint('Notification verified in database: ${doc.data()}');
      } else {
        debugPrint('ERROR: Notification not found in database after creation');
      }
    } catch (e) {
      debugPrint('ERROR creating notification: $e');
      rethrow;
    }
  }

  /// Create a friend request notification
  static Future<void> createFriendRequestNotification(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('ERROR: No current user for friend request notification');
      return;
    }

    await createNotification(
      userId: toUserId,
      type: 'friend_request',
      fromUserId: currentUser.uid,
    );
  }

  /// Create a friend accept notification
  static Future<void> createFriendAcceptNotification(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('ERROR: No current user for friend accept notification');
      return;
    }

    await createNotification(
      userId: toUserId,
      type: 'friend_accept',
      fromUserId: currentUser.uid,
    );
  }

  /// Create a like notification
  static Future<void> createLikeNotification(
      String postOwnerId, String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == postOwnerId) {
      return; // Don't create notification for own posts
    }

    await createNotification(
      userId: postOwnerId,
      type: 'like',
      fromUserId: currentUser.uid,
      additionalData: {'postId': postId},
    );
  }

  /// Create a comment notification
  static Future<void> createCommentNotification(
      String postOwnerId, String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == postOwnerId) {
      return; // Don't create notification for own posts
    }

    await createNotification(
      userId: postOwnerId,
      type: 'comment',
      fromUserId: currentUser.uid,
      additionalData: {'postId': postId},
    );
  }

  /// Create group join request notification
  static Future<void> createGroupJoinRequestNotification(
      String groupId, String adminUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('ERROR: No current user for group join request notification');
      return;
    }

    await createNotification(
      userId: adminUserId,
      type: 'group_join_request',
      fromUserId: currentUser.uid,
      additionalData: {'groupId': groupId},
    );
  }

  /// Create group join approval notification
  static Future<void> createGroupJoinApprovalNotification(
      String toUserId, String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('ERROR: No current user for group join approval notification');
      return;
    }

    await createNotification(
      userId: toUserId,
      type: 'group_join_approved',
      fromUserId: currentUser.uid,
      additionalData: {'groupId': groupId},
    );
  }

  /// Create group post notification for all group members
  static Future<void> createGroupPostNotification(
      String groupId, String postId, List<String> memberIds) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('ERROR: No current user for group post notification');
      return;
    }

    // Create notifications for all group members except the poster
    for (String memberId in memberIds) {
      if (memberId != currentUser.uid) {
        await createNotification(
          userId: memberId,
          type: 'group_post',
          fromUserId: currentUser.uid,
          additionalData: {'groupId': groupId, 'postId': postId},
        );
      }
    }
  }

  /// Create a like notification for group posts
  static Future<void> createGroupPostLikeNotification(String postOwnerId, String postId, String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == postOwnerId) {
      debugPrint('Skipping group post like notification: own post or no user');
      return; // Don't create notification for own posts
    }
    
    debugPrint('Creating group post like notification for post $postId in group $groupId');
    
    // Get group name for the notification
    String groupName = 'a group';
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        final groupData = groupDoc.data() as Map<String, dynamic>;
        groupName = groupData['name'] ?? 'a group';
        debugPrint('Found group name: $groupName');
      }
    } catch (e) {
      debugPrint('Error getting group name: $e');
    }
    
    await createNotification(
      userId: postOwnerId,
      type: 'group_post_like',
      fromUserId: currentUser.uid,
      additionalData: {
        'postId': postId,
        'groupId': groupId,
        'groupName': groupName,
      },
    );
    
    debugPrint('Group post like notification created successfully');
  }

  /// Create a comment notification for group posts
  static Future<void> createGroupPostCommentNotification(String postOwnerId, String postId, String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == postOwnerId) {
      debugPrint('Skipping group post comment notification: own post or no user');
      return; // Don't create notification for own posts
    }
    
    debugPrint('Creating group post comment notification for post $postId in group $groupId');
    
    // Get group name for the notification
    String groupName = 'a group';
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        final groupData = groupDoc.data() as Map<String, dynamic>;
        groupName = groupData['name'] ?? 'a group';
        debugPrint('Found group name: $groupName');
      }
    } catch (e) {
      debugPrint('Error getting group name: $e');
    }
    
    await createNotification(
      userId: postOwnerId,
      type: 'group_post_comment',
      fromUserId: currentUser.uid,
      additionalData: {
        'postId': postId,
        'groupId': groupId,
        'groupName': groupName,
      },
    );
    
    debugPrint('Group post comment notification created successfully');
  }

  /// Mark all notifications as read for a user
  static Future<void> markAllAsRead(String userId) async {
    try {
      final unreadNotifications = await _notifications
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      if (unreadNotifications.docs.isEmpty) {
        debugPrint('No unread notifications to mark as read');
        return;
      }

      final batch = _firestore.batch();
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
      debugPrint(
          'Marked ${unreadNotifications.docs.length} notifications as read');
    } catch (e) {
      debugPrint('ERROR marking notifications as read: $e');
    }
  }

  /// Mark a specific notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _notifications.doc(notificationId).update({'read': true});
      debugPrint('Marked notification $notificationId as read');
    } catch (e) {
      debugPrint('ERROR marking notification as read: $e');
    }
  }

  /// Get unread notification count for a user
  static Stream<int> getUnreadCount(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get all notifications for a user
  static Stream<QuerySnapshot> getNotifications(String userId) {
    return _notifications.where('userId', isEqualTo: userId).snapshots();
  }

  /// Test notification creation (for debugging)
  static Future<void> testNotificationCreation(String userId) async {
    debugPrint('Testing notification creation for user: $userId');

    try {
      await createNotification(
        userId: userId,
        type: 'test',
        fromUserId: 'system',
        additionalData: {'message': 'Test notification'},
      );
      debugPrint('Test notification created successfully');
    } catch (e) {
      debugPrint('Test notification failed: $e');
    }
  }
}
