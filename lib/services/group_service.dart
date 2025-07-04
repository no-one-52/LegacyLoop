import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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

  // Join a group
  Future<void> joinGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if already a member
    final existingMember = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existingMember.docs.isNotEmpty) {
      throw Exception('Already a member of this group');
    }

    // Get group info to check if it's private
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');

    final groupData = groupDoc.data() as Map<String, dynamic>;
    final isPrivate = groupData['isPrivate'] as bool? ?? false;

    // Add member
    await _firestore.collection('group_members').add({
      'groupId': groupId,
      'userId': user.uid,
      'role': isPrivate ? 'pending' : 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'approvedAt': isPrivate ? null : FieldValue.serverTimestamp(),
    });

    // Update member count
    await _firestore.collection('groups').doc(groupId).update({
      'memberCount': FieldValue.increment(1),
    });
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
        .where('role', whereIn: ['admin', 'member'])
        .snapshots();
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

  // Approve pending member
  Future<void> approveMember(String membershipId) async {
    await _firestore.collection('group_members').doc(membershipId).update({
      'role': 'member',
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Reject pending member
  Future<void> rejectMember(String membershipId) async {
    final membership = await _firestore.collection('group_members').doc(membershipId).get();
    if (membership.exists) {
      final data = membership.data() as Map<String, dynamic>;
      final groupId = data['groupId'] as String;
      
      await membership.reference.delete();
      
      // Update member count
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(-1),
      });
    }
  }

  // Create a post in group (requires approval)
  Future<String> createGroupPost({
    required String groupId,
    required String content,
    File? image,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if user is approved member
    final membership = await _firestore
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: user.uid)
        .where('role', whereIn: ['admin', 'member'])
        .get();

    if (membership.docs.isEmpty) {
      throw Exception('You must be an approved member to post in this group');
    }

    String? imageUrl;
    if (image != null) {
      final ref = _storage
          .ref()
          .child('group_posts')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      imageUrl = await ref.getDownloadURL();
    }

    final postRef = await _firestore.collection('group_posts').add({
      'groupId': groupId,
      'content': content,
      'imageUrl': imageUrl,
      'authorId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending', // pending, approved, rejected
      'approvedBy': null,
      'approvedAt': null,
    });

    return postRef.id;
  }

  // Get group posts (approved only)
  Stream<QuerySnapshot> getGroupPosts(String groupId) {
    return _firestore
        .collection('group_posts')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
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
        .where('role', whereIn: ['admin', 'member'])
        .get();

    return membership.docs.isNotEmpty;
  }

  // Search groups
  Stream<QuerySnapshot> searchGroups(String query) {
    return _firestore
        .collection('groups')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + '\uf8ff')
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

  // Admin adds member directly (no approval)
  Future<void> addMemberAsAdmin(String groupId, String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final isAdmin = await isGroupAdmin(groupId);
    if (!isAdmin) throw Exception('Only admins can add members directly');

    await _firestore.collection('group_members').add({
      'groupId': groupId,
      'userId': userId,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('groups').doc(groupId).update({
      'memberCount': FieldValue.increment(1),
    });
  }

  // Member invites new user (pending approval)
  Future<void> inviteMember(String groupId, String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final isMember = await isGroupMember(groupId);
    if (!isMember) throw Exception('Only members can invite');

    await _firestore.collection('group_members').add({
      'groupId': groupId,
      'userId': userId,
      'role': 'pending',
      'joinedAt': FieldValue.serverTimestamp(),
      'approvedAt': null,
    });
    await _firestore.collection('groups').doc(groupId).update({
      'memberCount': FieldValue.increment(1),
    });
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
} 