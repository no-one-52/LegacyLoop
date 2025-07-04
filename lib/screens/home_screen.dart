import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import '../widgets/post_widget.dart';
import 'friend_requests_screen.dart';
import '../widgets/universal_app_bar.dart';
import 'package:badges/badges.dart' as badges;
import 'comments_screen.dart';
import 'edit_post_screen.dart';
import 'feed_screen.dart';
import 'like_list_screen.dart';
import 'login_screen.dart';
//import 'public_profile_screen.dart';
import 'signup_screen.dart';
import 'search_screen.dart';
import 'messages_screen.dart';
import '../services/user_status_service.dart';
import 'groups_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUserStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        UserStatusService().onAppResume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        UserStatusService().onAppPause();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await UserStatusService().initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String? photoUrl;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists && doc.data() != null && doc.data()!['photoUrl'] != null) {
          photoUrl = doc.data()!['photoUrl'];
        }
      });
    }
    final List<Widget> _screens = [
      _FeedTab(),
      _InterestedFeedTab(),
      FriendRequestsScreen(),
      GroupsScreen(),
      _NotificationsTab(userId: user?.uid),
      ProfileScreen(),
    ];

    return StreamBuilder<QuerySnapshot>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance
              .collection('friend_requests')
              .where('toUserId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'pending')
              .where('viewedByReceiver', isEqualTo: false)
              .snapshots(),
      builder: (context, snapshot) {
        int requestCount = 0;
        if (snapshot.hasData) {
          requestCount = snapshot.data!.docs.length;
        }
        return StreamBuilder<QuerySnapshot>(
          stream: user == null
              ? null
              : FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
          builder: (context, notifSnapshot) {
            int notifCount = 0;
            if (notifSnapshot.hasData) {
              notifCount = notifSnapshot.data!.docs.length;
            }
            // Facebook-style: Use a StreamBuilder for unread messages
            return StreamBuilder<QuerySnapshot>(
              stream: user == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection('conversations')
                      .where('participants', arrayContains: user.uid)
                      .snapshots(),
              builder: (context, convoSnapshot) {
                int totalUnread = 0;
                if (convoSnapshot.hasData && user != null) {
                  for (var doc in convoSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final lastMessageSenderId = data.containsKey('lastMessageSenderId') ? data['lastMessageSenderId'] : null;
                    final seenBy = List<String>.from(data['seenBy'] ?? []);
                    int unread = 1;
                    if (data['unreadCount'] != null && data['unreadCount'] is int) {
                      unread = data['unreadCount'];
                    }
                    // Only count if the last message is a real message and not sent by the user
                    final lastType = data['lastType'] ?? 'text';
                    if ((lastType == 'text' || lastType == 'image') && lastMessageSenderId != null && lastMessageSenderId != user.uid && !seenBy.contains(user.uid)) {
                      totalUnread += unread;
                    }
                  }
                }
                final showRequestsBadge = requestCount > 0;
                return Scaffold(
                  appBar: _selectedIndex == 5
                      ? null
                      : UniversalAppBar(
                          profilePhotoUrl: photoUrl,
                          onProfileTap: () {
                            setState(() {
                              _selectedIndex = 4;
                            });
                          },
                          onMessageTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => MessagesScreen(onUnreadReset: () { setState(() {}); })),
                            );
                          },
                          onSearch: (query) {},
                          unreadMessagesCount: totalUnread,
                        ),
                  body: _screens[_selectedIndex],
                  bottomNavigationBar: BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: const Color(0xFF7B1FA2),
                    unselectedItemColor: Colors.grey,
                    showUnselectedLabels: true,
                    currentIndex: _selectedIndex,
                    onTap: (index) async {
                      setState(() {
                        _selectedIndex = index;
                      });
                      if (index == 5 && user != null) {
                        final batch = FirebaseFirestore.instance.batch();
                        final unread = await FirebaseFirestore.instance
                            .collection('notifications')
                            .where('userId', isEqualTo: user.uid)
                            .where('read', isEqualTo: false)
                            .get();
                        for (var doc in unread.docs) {
                          batch.update(doc.reference, {'read': true});
                        }
                        await batch.commit();
                      }
                      if (index == 2 && user != null) {
                        // Mark all pending requests as viewed
                        final pending = await FirebaseFirestore.instance
                            .collection('friend_requests')
                            .where('toUserId', isEqualTo: user.uid)
                            .where('status', isEqualTo: 'pending')
                            .where('viewedByReceiver', isEqualTo: false)
                            .get();
                        final batch = FirebaseFirestore.instance.batch();
                        for (var doc in pending.docs) {
                          batch.update(doc.reference, {'viewedByReceiver': true});
                        }
                        await batch.commit();
                      }
                    },
                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Feed',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.star),
                        label: 'Interested',
                      ),
                      BottomNavigationBarItem(
                        icon: badges.Badge(
                          showBadge: showRequestsBadge,
                          badgeContent: Text('$requestCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          position: badges.BadgePosition.topEnd(top: -8, end: -8),
                          child: const Icon(Icons.people_alt),
                        ),
                        label: 'Requests',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.group),
                        label: 'Groups',
                      ),
                      BottomNavigationBarItem(
                        icon: badges.Badge(
                          showBadge: notifCount > 0,
                          badgeContent: Text('$notifCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          position: badges.BadgePosition.topEnd(top: -8, end: -8),
                          child: const Icon(Icons.notifications),
                        ),
                        label: 'Notifications',
                      ),
                      BottomNavigationBarItem(
                        icon: (user != null)
                            ? FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
                                builder: (context, snapshot) {
                                  String? photoUrl;
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                                    photoUrl = data?['photoUrl'] as String?;
                                  }
                                  if (photoUrl != null && photoUrl.isNotEmpty) {
                                    return CircleAvatar(
                                      radius: 14,
                                      backgroundImage: NetworkImage(photoUrl),
                                      backgroundColor: Colors.grey[200],
                                    );
                                  } else {
                                    return const Icon(Icons.account_circle);
                                  }
                                },
                              )
                            : const Icon(Icons.account_circle),
                        label: 'Profile',
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Feed';
      case 1:
        return 'Interested Feed';
      case 2:
        return 'Friend Requests';
      case 3:
        return 'Groups';
      case 4:
        return 'Notifications';
      case 5:
        return 'Profile';
      default:
        return '';
    }
  }

  Color _getAppBarColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF4A90E2);
      case 1:
        return const Color(0xFF26A69A);
      case 2:
        return const Color(0xFF7B1FA2);
      case 3:
        return const Color(0xFF7B1FA2);
      case 4:
        return const Color(0xFF7B1FA2);
      case 5:
        return const Color(0xFF4A90E2);
      default:
        return Colors.blue;
    }
  }
}

// Feed Tab (existing feed logic)
class _FeedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data!.docs;
        if (posts.isEmpty) {
          return const Center(child: Text('No posts yet.'));
        }
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostWidget(post: post);
          },
        );
      },
    );
  }
}

// Interested Feed Tab (placeholder, filter by interests)
class _InterestedFeedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Implement filtering by user interests
    return const Center(
      child: Text('Show posts based on your interests here.'),
    );
  }
}

// Notifications Tab
class _NotificationsTab extends StatelessWidget {
  final String? userId;
  const _NotificationsTab({this.userId});
  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notifications = snapshot.data!.docs;
        if (notifications.isEmpty) {
          return const Center(child: Text('No notifications yet.'));
        }
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index].data() as Map<String, dynamic>;
            final fromUserId = notif['fromUserId'] as String?;
            return FutureBuilder<DocumentSnapshot>(
              future: fromUserId != null
                  ? FirebaseFirestore.instance.collection('users').doc(fromUserId).get()
                  : Future.value(null),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data() as Map<String, dynamic>?;
                final senderName = userData?['nickname'] ?? fromUserId ?? 'Someone';
                final senderPhoto = userData?['photoUrl'];
                String text = '';
                if (notif['type'] == 'friend_accept') {
                  text = 'Your friend request was accepted by $senderName.';
                } else if (notif['type'] == 'friend_request') {
                  text = 'You received a friend request from $senderName.';
                } else if (notif['type'] == 'like') {
                  text = '$senderName liked your post.';
                } else if (notif['type'] == 'comment') {
                  text = '$senderName commented on your post.';
                } else {
                  text = 'You have a new notification.';
                }
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: senderPhoto != null && senderPhoto.isNotEmpty
                        ? NetworkImage(senderPhoto)
                        : const AssetImage('assets/logo.png') as ImageProvider,
                  ),
                  title: Text(text),
                  subtitle: notif['timestamp'] != null
                      ? Text((notif['timestamp'] as Timestamp).toDate().toString())
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
}

// Add a placeholder messaging screen if not already present
class _MessagingPlaceholderScreen extends StatelessWidget {
  const _MessagingPlaceholderScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: const Center(child: Text('Messaging coming soon!')),
    );
  }
} 