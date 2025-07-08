import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['isAdmin'] ?? false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get system statistics
  static Future<Map<String, int>> getSystemStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final postsSnapshot = await _firestore.collection('posts').get();
      final groupsSnapshot = await _firestore.collection('groups').get();

      return {
        'totalUsers': usersSnapshot.docs.length,
        'totalPosts': postsSnapshot.docs.length,
        'totalGroups': groupsSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting system stats: $e');
      return {
        'totalUsers': 0,
        'totalPosts': 0,
        'totalGroups': 0,
      };
    }
  }

  // Ban user
  static Future<bool> banUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': true,
        'bannedAt': FieldValue.serverTimestamp(),
      });
      
      // Log admin action
      await _logAdminAction('Ban', 'User $userId');
      
      return true;
    } catch (e) {
      print('Error banning user: $e');
      return false;
    }
  }

  // Unban user
  static Future<bool> unbanUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': false,
        'bannedAt': null,
      });
      
      // Log admin action
      await _logAdminAction('Unban', 'User $userId');
      
      return true;
    } catch (e) {
      print('Error unbanning user: $e');
      return false;
    }
  }

  // Simple test method to delete user posts only
  static Future<bool> deleteUserPostsOnly(String userId) async {
    try {
      print('=== TESTING POST DELETION FOR USER: $userId ===');
      
      // Check if current user is admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('ERROR: Current user is not admin');
        return false;
      }
      
      // Get user info first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('ERROR: User not found: $userId');
        return false;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] ?? 'unknown';
      print('Found user: $userEmail');
      
      // Try to find posts with userId field
      print('Searching for posts with userId field...');
      final postsQuery1 = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      print('Found ${postsQuery1.docs.length} posts with userId field');
      
      // Try to find posts with authorId field
      print('Searching for posts with authorId field...');
      final postsQuery2 = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .get();
      print('Found ${postsQuery2.docs.length} posts with authorId field');
      
      // Combine all posts
      final allPosts = [...postsQuery1.docs, ...postsQuery2.docs];
      print('Total posts to delete: ${allPosts.length}');
      
      if (allPosts.isEmpty) {
        print('No posts found for user $userId');
        return true;
      }
      
      // Delete posts one by one for better debugging
      int deletedCount = 0;
      for (final postDoc in allPosts) {
        try {
          final postData = postDoc.data() as Map<String, dynamic>;
          final postText = postData['text'] ?? 'No text';
          print('Deleting post: ${postDoc.id} - "$postText"');
          
          await postDoc.reference.delete();
          deletedCount++;
          print('Successfully deleted post: ${postDoc.id}');
          
          // Small delay
          await Future.delayed(Duration(milliseconds: 200));
        } catch (e) {
          print('Error deleting post ${postDoc.id}: $e');
        }
      }
      
      print('=== POST DELETION COMPLETE ===');
      print('Successfully deleted $deletedCount out of ${allPosts.length} posts');
      
      return deletedCount == allPosts.length;
    } catch (e) {
      print('ERROR in deleteUserPostsOnly: $e');
      return false;
    }
  }

  // Simple client-side user deletion (no Cloud Function)
  static Future<bool> deleteUser(String userId) async {
    try {
      print('=== STARTING USER DELETION FOR: $userId ===');
      
      // Validate userId
      if (userId.isEmpty) {
        print('ERROR: userId is empty');
        return false;
      }
      
      // Check if current user is admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('ERROR: Current user is not admin');
        return false;
      }
      
      // Get current user email for debugging
      final currentUser = _auth.currentUser;
      final currentUserEmail = currentUser?.email ?? 'unknown';
      print('Current admin user: $currentUserEmail');
      
      // Get user info first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('ERROR: User not found: $userId');
        return false;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] ?? 'unknown';
      print('Found user to delete: $userEmail ($userId)');
      
      print('Starting simple client-side deletion...');
      
      // Use the existing client-side deletion method directly
      final success = await _deleteUserClientSide(userId);
      
      if (success) {
        print('=== USER DELETION SUCCESSFUL ===');
        // Log admin action
        await _logAdminAction('Delete', 'User $userEmail (ID: $userId) - Client-side');
        return true;
      } else {
        print('=== USER DELETION FAILED ===');
        return false;
      }
    } catch (e) {
      print('ERROR in deleteUser: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: $e');
      return false;
    }
  }

  // Delete user with cascade deletion (client-side fallback)
  static Future<bool> _deleteUserClientSide(String userId) async {
    try {
      // Validate userId
      if (userId.isEmpty) {
        print('Error: userId is empty');
        return false;
      }
      
      // Get user data before deletion for cascade operations
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('User not found: $userId');
        return false;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] ?? '';

      print('Starting cascade deletion for user: $userEmail ($userId)');

      // 1. Delete all posts by this user
      await _deleteUserPosts(userId);
      await Future.delayed(Duration(milliseconds: 500)); // Small delay

      // 2. Delete all comments by this user
      await _deleteUserComments(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 3. Remove all likes by this user
      await _removeUserLikes(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 4. Remove user from all groups
      await _removeUserFromGroups(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 5. Delete friend relationships
      await _deleteFriendRelationships(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 6. Delete friend requests
      await _deleteFriendRequests(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 7. Delete user's notifications
      await _deleteUserNotifications(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 8. Delete user's messages
      await _deleteUserMessages(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 9. Delete user's status updates
      await _deleteUserStatus(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 10. Notify other users about the deletion (simplified to avoid memory issues)
      await _notifyUserDeletion(userId, userData['name'] ?? 'Unknown User');
      await Future.delayed(Duration(milliseconds: 500));

      // 11. Update friend lists for remaining users
      await _updateFriendLists(userId);
      await Future.delayed(Duration(milliseconds: 500));

      // 12. Log the deletion for audit
      await _logUserDeletion(userId, userEmail, _auth.currentUser?.uid ?? '');

      // 13. Finally, delete the user document
      await _firestore.collection('users').doc(userId).delete();

      // Log admin action
      await _logAdminAction('Delete', 'User $userEmail (ID: $userId) - All data cascaded');
      
      print('Successfully deleted user: $userEmail ($userId)');
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // Delete all posts by a user
  static Future<void> _deleteUserPosts(String userId) async {
    try {
      // Try both field names since different parts of the app use different field names
      final postsQuery1 = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      final postsQuery2 = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .get();

      // Combine both queries
      final allPosts = [...postsQuery1.docs, ...postsQuery2.docs];
      
      if (allPosts.isEmpty) {
        print('No posts found for user $userId');
        return;
      }

      // Use smaller batches to prevent memory issues
      const int batchSize = 10;
      for (int i = 0; i < allPosts.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < allPosts.length) ? i + batchSize : allPosts.length;
        
        for (int j = i; j < end; j++) {
          batch.delete(allPosts[j].reference);
        }
        
        await batch.commit();
        await Future.delayed(Duration(milliseconds: 100)); // Small delay between batches
      }
      print('Deleted ${allPosts.length} posts for user $userId (${postsQuery1.docs.length} with userId, ${postsQuery2.docs.length} with authorId)');
    } catch (e) {
      print('Error deleting user posts: $e');
    }
  }

  // Delete all comments by a user
  static Future<void> _deleteUserComments(String userId) async {
    try {
      // Try both field names since different parts of the app use different field names
      final commentsQuery1 = await _firestore
          .collection('comments')
          .where('userId', isEqualTo: userId)
          .get();

      final commentsQuery2 = await _firestore
          .collection('comments')
          .where('authorId', isEqualTo: userId)
          .get();

      // Combine both queries
      final allComments = [...commentsQuery1.docs, ...commentsQuery2.docs];
      
      if (allComments.isEmpty) {
        print('No comments found for user $userId');
        return;
      }

      // Use smaller batches to prevent memory issues
      const int batchSize = 10;
      for (int i = 0; i < allComments.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < allComments.length) ? i + batchSize : allComments.length;
        
        for (int j = i; j < end; j++) {
          batch.delete(allComments[j].reference);
        }
        
        await batch.commit();
        await Future.delayed(Duration(milliseconds: 100)); // Small delay between batches
      }
      print('Deleted ${allComments.length} comments for user $userId (${commentsQuery1.docs.length} with userId, ${commentsQuery2.docs.length} with authorId)');
    } catch (e) {
      print('Error deleting user comments: $e');
    }
  }

  // Remove all likes by a user
  static Future<void> _removeUserLikes(String userId) async {
    try {
      final likesQuery = await _firestore
          .collection('likes')
          .where('userId', isEqualTo: userId)
          .get();

      // Use smaller batches to prevent memory issues
      const int batchSize = 10;
      for (int i = 0; i < likesQuery.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < likesQuery.docs.length) ? i + batchSize : likesQuery.docs.length;
        
        for (int j = i; j < end; j++) {
          batch.delete(likesQuery.docs[j].reference);
        }
        
        await batch.commit();
        await Future.delayed(Duration(milliseconds: 100)); // Small delay between batches
      }
      print('Removed ${likesQuery.docs.length} likes for user $userId');
    } catch (e) {
      print('Error removing user likes: $e');
    }
  }

  // Remove user from all groups
  static Future<void> _removeUserFromGroups(String userId) async {
    try {
      // Get all groups where user is a member
      final groupsQuery = await _firestore
          .collection('groups')
          .where('members', arrayContains: userId)
          .get();

      final batch = _firestore.batch();
      for (final groupDoc in groupsQuery.docs) {
        final groupData = groupDoc.data();
        final members = List<String>.from(groupData['members'] ?? []);
        members.remove(userId);
        
        // Update member count
        final memberCount = (groupData['memberCount'] ?? 1) - 1;
        
        batch.update(groupDoc.reference, {
          'members': members,
          'memberCount': memberCount > 0 ? memberCount : 0,
        });
      }
      await batch.commit();
      print('Removed user from ${groupsQuery.docs.length} groups');
    } catch (e) {
      print('Error removing user from groups: $e');
    }
  }

  // Delete friend relationships
  static Future<void> _deleteFriendRelationships(String userId) async {
    try {
      // Delete friendships where user is either user1 or user2
      final friendshipsQuery1 = await _firestore
          .collection('friendships')
          .where('user1Id', isEqualTo: userId)
          .get();

      final friendshipsQuery2 = await _firestore
          .collection('friendships')
          .where('user2Id', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in friendshipsQuery1.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in friendshipsQuery2.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Deleted ${friendshipsQuery1.docs.length + friendshipsQuery2.docs.length} friend relationships');
    } catch (e) {
      print('Error deleting friend relationships: $e');
    }
  }

  // Delete friend requests
  static Future<void> _deleteFriendRequests(String userId) async {
    try {
      // Delete requests sent by user
      final sentRequestsQuery = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: userId)
          .get();

      // Delete requests received by user
      final receivedRequestsQuery = await _firestore
          .collection('friendRequests')
          .where('receiverId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in sentRequestsQuery.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in receivedRequestsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Deleted ${sentRequestsQuery.docs.length + receivedRequestsQuery.docs.length} friend requests');
    } catch (e) {
      print('Error deleting friend requests: $e');
    }
  }

  // Delete user notifications
  static Future<void> _deleteUserNotifications(String userId) async {
    try {
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('Deleted ${notificationsQuery.docs.length} notifications for user $userId');
    } catch (e) {
      print('Error deleting user notifications: $e');
    }
  }

  // Delete user messages
  static Future<void> _deleteUserMessages(String userId) async {
    try {
      // Delete messages sent by user
      final sentMessagesQuery = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .get();

      // Delete messages received by user
      final receivedMessagesQuery = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in sentMessagesQuery.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in receivedMessagesQuery.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Deleted ${sentMessagesQuery.docs.length + receivedMessagesQuery.docs.length} messages');
    } catch (e) {
      print('Error deleting user messages: $e');
    }
  }

  // Delete user status
  static Future<void> _deleteUserStatus(String userId) async {
    try {
      final statusQuery = await _firestore
          .collection('userStatus')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in statusQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('Deleted ${statusQuery.docs.length} status updates for user $userId');
    } catch (e) {
      print('Error deleting user status: $e');
    }
  }

  // Delete post
  static Future<bool> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      
      // Log admin action
      await _logAdminAction('Delete', 'Post $postId');
      
      return true;
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }

  // Hide post
  static Future<bool> hidePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isHidden': true,
      });
      
      // Log admin action
      await _logAdminAction('Hide', 'Post $postId');
      
      return true;
    } catch (e) {
      print('Error hiding post: $e');
      return false;
    }
  }

  // Delete group
  static Future<bool> deleteGroup(String groupId) async {
    try {
      await _firestore.collection('groups').doc(groupId).delete();
      
      // Log admin action
      await _logAdminAction('Delete', 'Group $groupId');
      
      return true;
    } catch (e) {
      print('Error deleting group: $e');
      return false;
    }
  }

  // Create admin announcement
  static Future<bool> createAnnouncement(String title, String message) async {
    try {
      await _firestore.collection('announcements').add({
        'title': title,
        'message': message,
        'createdBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      
      // Log admin action
      await _logAdminAction('Announcement', title);
      
      return true;
    } catch (e) {
      print('Error creating announcement: $e');
      return false;
    }
  }

  // Get reported content
  static Stream<QuerySnapshot> getReportedContent() {
    return _firestore
        .collection('posts')
        .where('reported', isEqualTo: true)
        .snapshots();
  }

  // Get banned users
  static Stream<QuerySnapshot> getBannedUsers() {
    return _firestore
        .collection('users')
        .where('isBanned', isEqualTo: true)
        .snapshots();
  }

  // Get recent activity
  static Stream<QuerySnapshot> getRecentActivity() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Set maintenance mode
  static Future<bool> setMaintenanceMode(bool enabled) async {
    try {
      await _firestore.collection('system').doc('settings').set({
        'maintenanceMode': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Error setting maintenance mode: $e');
      return false;
    }
  }

  // Get maintenance mode status
  static Future<bool> getMaintenanceMode() async {
    try {
      final doc = await _firestore.collection('system').doc('settings').get();
      return doc.data()?['maintenanceMode'] ?? false;
    } catch (e) {
      print('Error getting maintenance mode: $e');
      return false;
    }
  }

  // Export user data
  static Future<List<Map<String, dynamic>>> exportUserData() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error exporting user data: $e');
      return [];
    }
  }

  // Get user by email
  static Future<DocumentSnapshot?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first;
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  // Get post by ID
  static Future<DocumentSnapshot?> getPostById(String postId) async {
    try {
      return await _firestore.collection('posts').doc(postId).get();
    } catch (e) {
      print('Error getting post by ID: $e');
      return null;
    }
  }

  // Get group by ID
  static Future<DocumentSnapshot?> getGroupById(String groupId) async {
    try {
      return await _firestore.collection('groups').doc(groupId).get();
    } catch (e) {
      print('Error getting group by ID: $e');
      return null;
    }
  }

  // Log admin action for notifications
  static Future<void> _logAdminAction(String action, String target) async {
    try {
      await _firestore.collection('admin_actions').add({
        'action': action,
        'target': target,
        'adminId': _auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging admin action: $e');
    }
  }

  // Simplified user deletion notification (to avoid memory issues)
  static Future<void> _notifyUserDeletion(String deletedUserId, String deletedUserName) async {
    try {
      // Only notify a limited number of users to prevent memory issues
      final usersSnapshot = await _firestore.collection('users')
          .limit(100) // Limit to prevent memory issues
          .get();
      
      final batch = _firestore.batch();
      int notificationCount = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        if (userId != deletedUserId && notificationCount < 50) { // Further limit
          final notificationRef = _firestore.collection('notifications').doc();
          batch.set(notificationRef, {
            'userId': userId,
            'type': 'user_deleted',
            'title': 'User Account Deleted',
            'message': 'User "$deletedUserName" has been permanently deleted by admin.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
          notificationCount++;
        }
      }
      
      if (notificationCount > 0) {
        await batch.commit();
        print('Created $notificationCount deletion notifications');
      }
    } catch (e) {
      print('Error notifying users about deletion: $e');
    }
  }

  // Simplified friend list update (to avoid memory issues)
  static Future<void> _updateFriendLists(String deletedUserId) async {
    try {
      // Process users in smaller batches
      final usersSnapshot = await _firestore.collection('users')
          .limit(50) // Limit to prevent memory issues
          .get();
      
      final batch = _firestore.batch();
      int updateCount = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final friends = List<String>.from(userData['friends'] ?? []);
        
        if (friends.contains(deletedUserId)) {
          friends.remove(deletedUserId);
          batch.update(userDoc.reference, {
            'friends': friends,
            'friendCount': friends.length,
          });
          updateCount++;
        }
      }
      
      if (updateCount > 0) {
        await batch.commit();
        print('Updated friend lists for $updateCount users');
      }
    } catch (e) {
      print('Error updating friend lists: $e');
    }
  }

  // Log user deletion for audit
  static Future<void> _logUserDeletion(String deletedUserId, String deletedUserEmail, String adminId) async {
    try {
      await _firestore.collection('deletion_logs').add({
        'deletedUserId': deletedUserId,
        'deletedUserEmail': deletedUserEmail,
        'deletedByAdminId': adminId,
        'deletionTimestamp': FieldValue.serverTimestamp(),
        'reason': 'Admin deletion',
      });
      print('Logged user deletion for audit');
    } catch (e) {
      print('Error logging user deletion: $e');
    }
  }
} 