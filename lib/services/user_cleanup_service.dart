import 'package:cloud_firestore/cloud_firestore.dart';

class UserCleanupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notify other users about the deletion
  static Future<void> notifyUserDeletion(String deletedUserId, String deletedUserName) async {
    try {
      // Get all users who might be affected
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        if (userId != deletedUserId) {
          // Create notification for each user
          await _firestore.collection('notifications').add({
            'userId': userId,
            'type': 'user_deleted',
            'title': 'User Account Deleted',
            'message': 'User "$deletedUserName" has been permanently deleted by admin.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }
    } catch (e) {
      print('Error notifying users about deletion: $e');
    }
  }

  // Clean up any remaining references to deleted user
  static Future<void> cleanupDeletedUserReferences(String deletedUserId) async {
    try {
      // Update posts that might reference the deleted user
      final postsQuery = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: deletedUserId)
          .get();

      final batch = _firestore.batch();
      for (final doc in postsQuery.docs) {
        batch.update(doc.reference, {
          'authorName': 'Deleted User',
          'authorId': null,
          'isAuthorDeleted': true,
        });
      }
      await batch.commit();

      // Update comments that reference the deleted user
      final commentsQuery = await _firestore
          .collection('comments')
          .where('authorId', isEqualTo: deletedUserId)
          .get();

      final commentBatch = _firestore.batch();
      for (final doc in commentsQuery.docs) {
        commentBatch.update(doc.reference, {
          'authorName': 'Deleted User',
          'authorId': null,
          'isAuthorDeleted': true,
        });
      }
      await commentBatch.commit();

    } catch (e) {
      print('Error cleaning up user references: $e');
    }
  }

  // Update friend lists for users who had the deleted user as a friend
  static Future<void> updateFriendLists(String deletedUserId) async {
    try {
      // Get all users who might have the deleted user in their friends list
      final usersSnapshot = await _firestore.collection('users').get();
      
      final batch = _firestore.batch();
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final friends = List<String>.from(userData['friends'] ?? []);
        
        if (friends.contains(deletedUserId)) {
          friends.remove(deletedUserId);
          batch.update(userDoc.reference, {
            'friends': friends,
            'friendCount': friends.length,
          });
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error updating friend lists: $e');
    }
  }

  // Log the deletion for audit purposes
  static Future<void> logUserDeletion(String deletedUserId, String deletedUserEmail, String adminId) async {
    try {
      await _firestore.collection('deletion_logs').add({
        'deletedUserId': deletedUserId,
        'deletedUserEmail': deletedUserEmail,
        'deletedByAdminId': adminId,
        'deletionTimestamp': FieldValue.serverTimestamp(),
        'reason': 'Admin deletion',
      });
    } catch (e) {
      print('Error logging user deletion: $e');
    }
  }
} 