import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Timer? _statusTimer;
  bool _isOnline = false;
  StreamSubscription? _statusSubscription;

  // Initialize status tracking
  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Set user as online
    await _setOnlineStatus(true);
    
    // Start periodic status updates
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateLastSeen();
    });

    // Listen for app lifecycle changes
    _setupAppLifecycleListener();
  }

  // Set online/offline status
  Future<void> _setOnlineStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isOnline = isOnline;
    
    try {
      await _firestore.collection('user_status').doc(user.uid).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // Update last seen timestamp
  Future<void> _updateLastSeen() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('user_status').doc(user.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
        if (!_isOnline) 'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last seen: $e');
    }
  }

  // Manually update user activity (call this when user interacts with the app)
  Future<void> updateActivity() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('user_status').doc(user.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating activity: $e');
    }
  }

  // Set user as offline
  Future<void> setOffline() async {
    await _setOnlineStatus(false);
    await _updateLastSeen();
  }

  // Set user as online
  Future<void> setOnline() async {
    await _setOnlineStatus(true);
  }

  // Get user status stream
  Stream<Map<String, dynamic>?> getUserStatusStream(String userId) {
    return _firestore
        .collection('user_status')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  // Get user status once
  Future<Map<String, dynamic>?> getUserStatus(String userId) async {
    try {
      final doc = await _firestore.collection('user_status').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user status: $e');
      return null;
    }
  }

  // Setup app lifecycle listener
  void _setupAppLifecycleListener() {
    // This would typically be called from main.dart or a lifecycle-aware widget
    // For now, we'll handle it manually
  }

  // Handle app pause (user leaves app)
  Future<void> onAppPause() async {
    await setOffline();
  }

  // Handle app resume (user returns to app)
  Future<void> onAppResume() async {
    await setOnline();
  }

  // Cleanup when user logs out
  Future<void> cleanup() async {
    await setOffline();
    _statusTimer?.cancel();
    _statusSubscription?.cancel();
  }

  // Format last seen time
  String formatLastSeen(Timestamp? lastSeen) {
    if (lastSeen == null) return 'Never';
    
    final now = DateTime.now();
    final lastSeenTime = lastSeen.toDate();
    final difference = now.difference(lastSeenTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${lastSeenTime.day}/${lastSeenTime.month}/${lastSeenTime.year}';
    }
  }

  // Check if user is currently online
  bool isUserOnline(Map<String, dynamic>? status) {
    if (status == null) return false;
    
    final isOnline = status['isOnline'] as bool? ?? false;
    if (!isOnline) return false;

    // Consider user offline if last active was more than 5 minutes ago
    final lastActive = status['lastActive'] as Timestamp?;
    if (lastActive == null) return false;

    final now = DateTime.now();
    final lastActiveTime = lastActive.toDate();
    final difference = now.difference(lastActiveTime);

    return difference.inMinutes < 5;
  }

  // Get formatted status text
  String getStatusText(Map<String, dynamic>? status) {
    if (status == null) return 'Offline';
    
    if (isUserOnline(status)) {
      return 'Online';
    } else {
      final lastSeen = status['lastSeen'] as Timestamp?;
      return formatLastSeen(lastSeen);
    }
  }
} 