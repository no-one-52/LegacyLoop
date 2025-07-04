import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FriendRequestService {
  static final _firestore = FirebaseFirestore.instance;
  static final _requests = _firestore.collection('friend_requests');

  static Future<void> sendRequest(String toUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == toUserId) return;
    // Prevent duplicate requests
    final existing = await _requests.where('fromUserId', isEqualTo: user.uid).where('toUserId', isEqualTo: toUserId).where('status', isEqualTo: 'pending').get();
    if (existing.docs.isNotEmpty) {
      debugPrint('sendRequest: duplicate request');
      return;
    }
    await _requests.add({
      'fromUserId': user.uid,
      'toUserId': toUserId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    debugPrint('sendRequest: request sent');
    
    // Create notification for the receiver
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': toUserId,
      'type': 'friend_request',
      'fromUserId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
    debugPrint('sendRequest: notification created for receiver');
  }

  static Future<void> cancelRequest(String requestId) async {
    await _requests.doc(requestId).update({'status': 'cancelled'});
    debugPrint('cancelRequest: request cancelled');
  }

  static Future<void> acceptRequest(String requestId) async {
    final doc = await _requests.doc(requestId).get();
    if (!doc.exists) {
      debugPrint('acceptRequest: request not found');
      return;
    }
    final data = doc.data() as Map<String, dynamic>;
    await _requests.doc(requestId).update({'status': 'accepted'});
    debugPrint('acceptRequest: request accepted');
    // Create notification for sender
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': data['fromUserId'],
      'type': 'friend_accept',
      'fromUserId': data['toUserId'], // the receiver who accepted
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
    debugPrint('acceptRequest: notification created');
  }

  static Future<void> declineRequest(String requestId) async {
    await _requests.doc(requestId).update({'status': 'declined'});
    debugPrint('declineRequest: request declined');
  }

  static Stream<QuerySnapshot> sentRequests(String userId) {
    return _requests
      .where('fromUserId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('timestamp', descending: true)
      .snapshots();
  }

  static Stream<QuerySnapshot> receivedRequests(String userId) {
    return _requests
      .where('toUserId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('timestamp', descending: true)
      .snapshots();
  }
} 