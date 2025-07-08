import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'notification_service.dart';

class GroupService {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;
  GroupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new group
  Future<String> createGroup({
    required String name,
    required String description,
    required bool isPrivate,
    File? coverImage,
    String? category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    String? coverImageUrl;
    if (coverImage != null) {
      final ref = _storage
          .ref()
          .child('group_covers')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(coverImage);
      coverImageUrl = await ref.getDownloadURL();
    }

    final groupRef = await _firestore.collection('groups').add({
      'name': name,
      'description': description,
      'isPrivate': isPrivate,
      'coverImageUrl': coverImageUrl,
      'category': category,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'memberCount': 1,
      'postCount': 0,
    });

    // Add creator as admin
    await _firestore.collection('group_members').add({
      'groupId': groupRef.id,
      'userId': user.uid,
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
      'approvedAt': FieldValue.serverTimestamp(),
    });

    return groupRef.id;
  }

  // Join a group (request to join)
  Future<void> joinGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if already a member or has pending request
    final existingMember = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existingMember.docs.isNotEmpty) {
      final status = existingMember.docs.first.data()['role'] as String;
      if (status == 'pending') {
        throw Exception(
            'You already have a pending request to join this group');
      } else {
        throw Exception('You are already a member of this group');
      }
    }

    // Get group info
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');

    // Add member request (always pending for Facebook-like behavior)
    await _firestore.collection('group_members').add({
      'groupId': groupId,
      'userId': user.uid,
      'role': 'pending',
      'joinedAt': FieldValue.serverTimestamp(),
      'approvedAt': null,
    });

    // Send notification to group admins
    await _sendJoinRequestNotification(groupId, user.uid);

    // Note: Don't increment memberCount until approved
  }

  // Leave a group
  Future<void> leaveGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Find and delete membership
    final membership = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (membership.docs.isNotEmpty) {
      await membership.docs.first.reference.delete();

      // Update member count
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(-1),
      });
    }
  }

  // Get user's groups
  Stream<QuerySnapshot> getUserGroups() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();

    return _firestore
        .collection('group_members')
        .where('userId', isEqualTo: user.uid)
        .where('role', whereIn: ['admin', 'member']).snapshots();
  }

  // Get group details
  Future<Map<String, dynamic>?> getGroupDetails(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  // Get group members
  Stream<QuerySnapshot> getGroupMembers(String groupId) {
    return _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .snapshots();
  }

  // Get pending members (for admin approval)
  Stream<QuerySnapshot> getPendingMembers(String groupId) {
    return _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('role', isEqualTo: 'pending')
        .snapshots();
  }

  // Get user's pending join requests
  Future<List<Map<String, dynamic>>> getUserPendingRequests() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final pendingRequests = await _firestore
        .collection('group_members')
        .where('userId', isEqualTo: user.uid)
        .where('role', isEqualTo: 'pending')
        .get();

    final List<Map<String, dynamic>> requests = [];
    for (var doc in pendingRequests.docs) {
      final data = doc.data();
      final groupId = data['groupId'] as String;
      final groupData = await getGroupDetails(groupId);

      if (groupData != null) {
        requests.add({
          'membershipId': doc.id,
          'groupId': groupId,
          'groupName': groupData['name'],
          'groupCover': groupData['coverImageUrl'],
          'joinedAt': data['joinedAt'],
          'invitedBy': data['invitedBy'], // If invited by someone
          ...data,
        });
      }
    }

    return requests;
  }

  // Cancel pending join request
  Future<void> cancelJoinRequest(String membershipId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.collection('group_members').doc(membershipId).delete();
  }

  // Approve pending member
  Future<void> approveMember(String membershipId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get membership details
    final membershipDoc =
        await _firestore.collection('group_members').doc(membershipId).get();
    if (!membershipDoc.exists) throw Exception('Membership not found');

    final membershipData = membershipDoc.data() as Map<String, dynamic>;
    final groupId = membershipData['groupId'] as String;
    final userId = membershipData['userId'] as String;

    // Check if current user is admin
    final isAdmin = await isGroupAdmin(groupId);
    if (!isAdmin) throw Exception('Only admins can approve members');

    // Update membership to approved
    await _firestore.collection('group_members').doc(membershipId).update({
      'role': 'member',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    // Update member count (only now)
    await _firestore.collection('groups').doc(groupId).update({
      'memberCount': FieldValue.increment(1),
    });

    // Send approval notification
    await _sendJoinApprovalNotification(groupId, userId);
  }

  // Reject pending member
  Future<void> rejectMember(String membershipId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get membership details
    final membershipDoc =
        await _firestore.collection('group_members').doc(membershipId).get();
    if (!membershipDoc.exists) throw Exception('Membership not found');

    final membershipData = membershipDoc.data() as Map<String, dynamic>;
    final groupId = membershipData['groupId'] as String;
    final userId = membershipData['userId'] as String;

    // Check if current user is admin
    final isAdmin = await isGroupAdmin(groupId);
    if (!isAdmin) throw Exception('Only admins can reject members');

    // Delete the membership request
    await membershipDoc.reference.delete();

    // Send rejection notification
    await _sendJoinRejectionNotification(groupId, userId);
  }

  // Create a post in group (admins can post directly, members need approval)
  Future<String> createGroupPost({
    required String groupId,
    required String content,
    List<File>? images,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if user is approved member
    final membership = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: user.uid)
        .where('role', whereIn: ['admin', 'member']).get();

    if (membership.docs.isEmpty) {
      throw Exception('You must be an approved member to post in this group');
    }

    // Check if user is admin
    final isAdmin = membership.docs.first.data()['role'] == 'admin';

    List<String> imageUrls = [];
    if (images != null && images.isNotEmpty) {
      for (final image in images) {
        final ref = _storage
            .ref()
            .child('group_posts')
            .child('${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}');
        await ref.putFile(image);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }
    }

    final postRef = await _firestore.collection('group_posts').add({
      'groupId': groupId,
      'content': content,
      'imageUrls': imageUrls,
      'authorId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': isAdmin ? 'approved' : 'pending', // Admins post directly, members need approval
      'approvedBy': isAdmin ? user.uid : null,
      'approvedAt': isAdmin ? FieldValue.serverTimestamp() : null,
    });

    // If admin posted, update group post count immediately
    if (isAdmin) {
      await _firestore.collection('groups').doc(groupId).update({
        'postCount': FieldValue.increment(1),
      });
    }

    return postRef.id;
  }

  // Get group posts (approved only)
  Stream<QuerySnapshot> getGroupPosts(String groupId) {
    return _firestore
        .collection('group_posts')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .limit(30) // Limit posts for better performance
        .snapshots();
  }

  // Get pending posts (for admin approval)
  Stream<QuerySnapshot> getPendingPosts(String groupId) {
    return _firestore
        .collection('group_posts')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Approve post
  Future<void> approvePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.collection('group_posts').doc(postId).update({
      'status': 'approved',
      'approvedBy': user.uid,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    // Update group post count
    final post = await _firestore.collection('group_posts').doc(postId).get();
    if (post.exists) {
      final data = post.data() as Map<String, dynamic>;
      final groupId = data['groupId'] as String;
      await _firestore.collection('groups').doc(groupId).update({
        'postCount': FieldValue.increment(1),
      });
    }
  }

  // Reject post
  Future<void> rejectPost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.collection('group_posts').doc(postId).update({
      'status': 'rejected',
      'approvedBy': user.uid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if user is admin of group
  Future<bool> isGroupAdmin(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final membership = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: user.uid)
        .where('role', isEqualTo: 'admin')
        .get();

    return membership.docs.isNotEmpty;
  }

  // Check if user is member of group
  Future<bool> isGroupMember(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final membership = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: user.uid)
        .where('role', whereIn: ['admin', 'member']).get();

    return membership.docs.isNotEmpty;
  }

  // Search groups
  Stream<QuerySnapshot> searchGroups(String query) {
    return _firestore
        .collection('groups')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: '$query\uf8ff')
        .limit(20)
        .snapshots();
  }

  // Get popular groups
  Stream<QuerySnapshot> getPopularGroups() {
    return _firestore
        .collection('groups')
        .orderBy('memberCount', descending: true)
        .limit(10)
        .snapshots();
  }

  // Update group settings (admin only)
  Future<void> updateGroupSettings({
    required String groupId,
    String? name,
    String? description,
    bool? isPrivate,
    File? coverImage,
    String? category,
  }) async {
    final isAdmin = await isGroupAdmin(groupId);
    if (!isAdmin) throw Exception('Only admins can update group settings');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (isPrivate != null) updates['isPrivate'] = isPrivate;
    if (category != null) updates['category'] = category;

    if (coverImage != null) {
      final ref = _storage
          .ref()
          .child('group_covers')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(coverImage);
      updates['coverImageUrl'] = await ref.getDownloadURL();
    }

    await _firestore.collection('groups').doc(groupId).update(updates);
  }

  // Delete group (admin only)
  Future<void> deleteGroup(String groupId) async {
    final isAdmin = await isGroupAdmin(groupId);
    if (!isAdmin) throw Exception('Only admins can delete groups');

    // Delete all group posts
    final posts = await _firestore
        .collection('group_posts')
        .where('groupId', isEqualTo: groupId)
        .get();

    final batch = _firestore.batch();
    for (var doc in posts.docs) {
      batch.delete(doc.reference);
    }

    // Delete all memberships
    final memberships = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .get();

    for (var doc in memberships.docs) {
      batch.delete(doc.reference);
    }

    // Delete the group
    batch.delete(_firestore.collection('groups').doc(groupId));

    await batch.commit();
  }

  // Admin adds member directly (no approval needed)
  Future<void> addMemberAsAdmin(String groupId, String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    final isAdmin = await isGroupAdmin(groupId);
    if (!isAdmin) throw Exception('Only admins can add members directly');

    // Check if user is already a member
    final existingMember = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: userId)
        .get();

    if (existingMember.docs.isNotEmpty) {
      throw Exception('User is already a member or has a pending request');
    }

    await _firestore.collection('group_members').add({
      'groupId': groupId,
      'userId': userId,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'approvedAt': FieldValue.serverTimestamp(),
    });

    // Update member count
    await _firestore.collection('groups').doc(groupId).update({
      'memberCount': FieldValue.increment(1),
    });

    // Send notification to added user
    await _sendMemberAddedNotification(groupId, userId);
  }

  // Member invites new user (creates pending request)
  Future<void> inviteMember(String groupId, String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    final isMember = await isGroupMember(groupId);
    if (!isMember) throw Exception('Only members can invite others');

    // Check if user is already a member or has pending request
    final existingMember = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: userId)
        .get();

    if (existingMember.docs.isNotEmpty) {
      throw Exception('User is already a member or has a pending request');
    }

    await _firestore.collection('group_members').add({
      'groupId': groupId,
      'userId': userId,
      'role': 'pending',
      'joinedAt': FieldValue.serverTimestamp(),
      'approvedAt': null,
      'invitedBy': currentUser.uid,
    });

    // Send invitation notification to invited user
    await _sendMemberInvitationNotification(groupId, userId, currentUser.uid);

    // Send notification to admin about the invitation
    await _sendInvitationPendingNotification(groupId, userId, currentUser.uid);
  }

  // Admin removes member (with notification)
  Future<void> removeMember(String groupId, String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final isAdmin = await isGroupAdmin(groupId);
    if (!isAdmin) throw Exception('Only admins can remove members');

    final membership = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: userId)
        .get();

    if (membership.docs.isNotEmpty) {
      await membership.docs.first.reference.delete();
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(-1),
      });
      // Send notification to removed user
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'removed_from_group',
        'groupId': groupId,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'You have been removed from the group by an admin.',
      });
    }
  }

  // Get accurate member count (only approved members)
  Future<int> getAccurateMemberCount(String groupId) async {
    final members = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('role', whereIn: ['admin', 'member']).get();

    return members.docs.length;
  }

  // Update member count in group document
  Future<void> updateMemberCount(String groupId) async {
    final accurateCount = await getAccurateMemberCount(groupId);
    await _firestore.collection('groups').doc(groupId).update({
      'memberCount': accurateCount,
    });
  }

  // Fix all group member counts (utility method)
  Future<void> fixAllGroupMemberCounts() async {
    try {
      final groups = await _firestore.collection('groups').get();

      for (var group in groups.docs) {
        await updateMemberCount(group.id);
      }

      print('Fixed member counts for ${groups.docs.length} groups');
    } catch (e) {
      print('Error fixing group member counts: $e');
    }
  }

  // Notification methods
  Future<void> _sendJoinRequestNotification(
      String groupId, String userId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final groupName = groupData['name'] as String;

      // Send notification to all admins
      final admins = await _firestore
          .collection('group_members')
          .where('groupId', isEqualTo: groupId)
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        final adminData = admin.data();
        final adminId = adminData['userId'] as String;

        await NotificationService.createNotification(
          userId: adminId,
          type: 'group_join_request',
          fromUserId: userId,
          additionalData: {
            'groupId': groupId,
            'groupName': groupName,
            'message': 'New group join request',
          },
        );
      }
    } catch (e) {
      print('Error sending join request notification: $e');
    }
  }

  Future<void> _sendJoinApprovalNotification(
      String groupId, String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final groupName = groupData['name'] as String;

      await NotificationService.createNotification(
        userId: userId,
        type: 'group_join_approved',
        fromUserId: currentUser.uid,
        additionalData: {
          'groupId': groupId,
          'groupName': groupName,
          'message': 'Your group join request was approved',
        },
      );
    } catch (e) {
      print('Error sending join approval notification: $e');
    }
  }

  Future<void> _sendJoinRejectionNotification(
      String groupId, String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final groupName = groupData['name'] as String;

      await NotificationService.createNotification(
        userId: userId,
        type: 'group_join_rejected',
        fromUserId: currentUser.uid,
        additionalData: {
          'groupId': groupId,
          'groupName': groupName,
          'message': 'Your group join request was rejected',
        },
      );
    } catch (e) {
      print('Error sending join rejection notification: $e');
    }
  }

  Future<void> _sendMemberAddedNotification(
      String groupId, String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final groupName = groupData['name'] as String;

      await NotificationService.createNotification(
        userId: userId,
        type: 'group_member_added',
        fromUserId: currentUser.uid,
        additionalData: {
          'groupId': groupId,
          'groupName': groupName,
          'message': 'You were added to a group',
        },
      );
    } catch (e) {
      print('Error sending member added notification: $e');
    }
  }

  Future<void> _sendMemberInvitationNotification(
      String groupId, String userId, String inviterId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final groupName = groupData['name'] as String;

      await NotificationService.createNotification(
        userId: userId,
        type: 'group_invitation',
        fromUserId: inviterId,
        additionalData: {
          'groupId': groupId,
          'groupName': groupName,
          'message': 'You were invited to join a group',
        },
      );
    } catch (e) {
      print('Error sending member invitation notification: $e');
    }
  }

  Future<void> _sendInvitationPendingNotification(
      String groupId, String invitedUserId, String inviterId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final groupName = groupData['name'] as String;

      // Send notification to all admins
      final admins = await _firestore
          .collection('group_members')
          .where('groupId', isEqualTo: groupId)
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        final adminData = admin.data();
        final adminId = adminData['userId'] as String;

        await NotificationService.createNotification(
          userId: adminId,
          type: 'group_invitation_pending',
          fromUserId: inviterId,
          additionalData: {
            'groupId': groupId,
            'groupName': groupName,
            'invitedUserId': invitedUserId,
            'message': 'A member invited someone to join the group',
          },
        );
      }
    } catch (e) {
      print('Error sending invitation pending notification: $e');
    }
  }
}
