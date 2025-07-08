import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import '../widgets/post_widget.dart';
import 'friend_requests_screen.dart';
import '../widgets/universal_app_bar.dart';
import 'package:badges/badges.dart' as badges;
import 'messages_screen.dart';
import '../services/user_status_service.dart';
import '../services/notification_service.dart';
import 'groups_screen.dart';
import 'group_detail_screen.dart';

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
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then((doc) {
        if (doc.exists &&
            doc.data() != null &&
            doc.data()!['photoUrl'] != null) {
          photoUrl = doc.data()!['photoUrl'];
        }
      });
    }
    final List<Widget> screens = [
      _FeedTab(),
      _InterestedFeedTab(),
      FriendRequestsScreen(),
      GroupsScreen(),
      _NotificationsTab(
        userId: user?.uid,
        onNavigateToRequests: () {
          setState(() {
            _selectedIndex = 2;
          });
        },
      ),
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
                    final lastMessageSenderId =
                        data.containsKey('lastMessageSenderId')
                            ? data['lastMessageSenderId']
                            : null;
                    final seenBy = List<String>.from(data['seenBy'] ?? []);
                    int unread = 1;
                    if (data['unreadCount'] != null &&
                        data['unreadCount'] is int) {
                      unread = data['unreadCount'];
                    }
                    // Only count if the last message is a real message and not sent by the user
                    final lastType = data['lastType'] ?? 'text';
                    if ((lastType == 'text' || lastType == 'image') &&
                        lastMessageSenderId != null &&
                        lastMessageSenderId != user.uid &&
                        !seenBy.contains(user.uid)) {
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
                              MaterialPageRoute(
                                  builder: (context) =>
                                      MessagesScreen(onUnreadReset: () {
                                        setState(() {});
                                      })),
                            );
                          },
                          onSearch: (query) {},
                          unreadMessagesCount: totalUnread,
                        ),
                  body: screens[_selectedIndex],
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
                      // Mark notifications as read when user taps on notifications tab
                      if (index == 4 && user != null) {
                        await NotificationService.markAllAsRead(user.uid);
                      }
                      // Mark friend requests as viewed when user taps on requests tab
                      if (index == 2 && user != null) {
                        final pending = await FirebaseFirestore.instance
                            .collection('friend_requests')
                            .where('toUserId', isEqualTo: user.uid)
                            .where('status', isEqualTo: 'pending')
                            .where('viewedByReceiver', isEqualTo: false)
                            .get();
                        final batch = FirebaseFirestore.instance.batch();
                        for (var doc in pending.docs) {
                          batch.update(
                              doc.reference, {'viewedByReceiver': true});
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
                          badgeContent: Text('$requestCount',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                          position:
                              badges.BadgePosition.topEnd(top: -8, end: -8),
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
                          badgeContent: Text('$notifCount',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                          position:
                              badges.BadgePosition.topEnd(top: -8, end: -8),
                          child: const Icon(Icons.notifications),
                        ),
                        label: 'Notifications',
                      ),
                      BottomNavigationBarItem(
                        icon: (user != null)
                            ? FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .get(),
                                builder: (context, snapshot) {
                                  String? photoUrl;
                                  if (snapshot.hasData &&
                                      snapshot.data!.exists) {
                                    final data = snapshot.data!.data()
                                        as Map<String, dynamic>?;
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

// Interested Feed Tab (filter by user interests)
class _InterestedFeedTab extends StatelessWidget {
  const _InterestedFeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: Text('Failed to load user data.'));
        }
        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final List<String> interests = List<String>.from(userData?['interests'] ?? []);
        final List<String> preferredPostTypes = List<String>.from(userData?['preferredPostTypes'] ?? ['All Posts']);
        
        if (interests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have not selected any interests.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Update Interests'),
                  onPressed: () {
                    // Navigate to ProfileScreen and open Preferences tab
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(initialTabIndex: 3), // 3 = Preferences tab
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }
        
        // Lowercase interests for comparison
        final Set<String> interestSet = interests.map((e) => e.toLowerCase()).toSet();
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, postSnapshot) {
            if (!postSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = postSnapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              
              // Check if post matches user's preferred post types
              final postType = data['postType'] ?? 'Text Posts'; // Default to Text Posts
              final hasImage = (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty) || 
                              (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty);
              final hasVideo = data['videoUrl'] != null && data['videoUrl'].toString().isNotEmpty;
              final isGroupPost = data['groupId'] != null;
              final isFriendPost = data['isFriendPost'] == true;
              
              // Determine actual post type
              String actualPostType = 'Text Posts';
              if (hasVideo) {
                actualPostType = 'Video Posts';
              } else if (hasImage) {
                actualPostType = 'Image Posts';
              } else if (isGroupPost) {
                actualPostType = 'Group Posts';
              } else if (isFriendPost) {
                actualPostType = 'Friend Posts';
              }
              
              // Check if post type is in user's preferences
              final postTypeMatches = preferredPostTypes.contains('All Posts') || 
                                    preferredPostTypes.contains(actualPostType);
              
              if (!postTypeMatches) return false;
              
              // Check if post matches user's interests (both hashtags and text content)
              final hashtags = (data['hashtags'] ?? []) as List?;
              final postText = (data['text'] ?? '').toString().toLowerCase();
              
              // Check hashtags
              bool hashtagMatches = false;
              if (hashtags != null && hashtags.isNotEmpty) {
                final tagSet = hashtags
                    .map((tag) => tag.toString().replaceAll('#', '').toLowerCase())
                    .toSet();
                hashtagMatches = tagSet.intersection(interestSet).isNotEmpty;
              }
              
              // Check text content for interest keywords
              bool textMatches = false;
              for (String interest in interests) {
                if (postText.contains(interest.toLowerCase())) {
                  textMatches = true;
                  break;
                }
              }
              
              // Post matches if either hashtags OR text content matches interests
              return hashtagMatches || textMatches;
            }).toList();
            if (posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No posts found for your interests.'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Update Interests'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(initialTabIndex: 3), // 3 = Preferences tab
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                // Filter info section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(8),
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
                          const Icon(Icons.filter_list, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Active Filters:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProfileScreen(initialTabIndex: 3),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Update', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Interests: ${interests.take(3).join(', ')}${interests.length > 3 ? ' +${interests.length - 3} more' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Post Types: ${preferredPostTypes.join(', ')}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Showing ${posts.length} matching posts',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                // Posts list
                Expanded(
                  child: ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return PostWidget(post: post);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Notifications Tab
class _NotificationsTab extends StatelessWidget {
  final String? userId;
  final VoidCallback? onNavigateToRequests;

  const _NotificationsTab({
    this.userId,
    this.onNavigateToRequests,
  });

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading notifications: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Trigger rebuild by calling setState in parent
                    // This is a simple retry mechanism
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notifications = snapshot.data!.docs;
        if (notifications.isEmpty) {
          return const Center(child: Text('No notifications yet.'));
        }

        // Sort notifications by timestamp in Dart since Firestore orderBy might need an index
        notifications.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTimestamp = aData['timestamp'] as Timestamp?;
          final bTimestamp = bData['timestamp'] as Timestamp?;

          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;

          return bTimestamp.compareTo(aTimestamp);
        });
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index].data() as Map<String, dynamic>;
            final fromUserId = notif['fromUserId'] as String?;
            return FutureBuilder<DocumentSnapshot?>(
              future: fromUserId != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(fromUserId)
                      .get()
                  : Future.value(null),
              builder: (context, userSnap) {
                if (userSnap.hasError) {
                  return ListTile(
                    leading: const Icon(Icons.error, color: Colors.red),
                    title: const Text('Error loading user info'),
                    subtitle: Text(userSnap.error.toString()),
                  );
                }
                Map<String, dynamic>? userData;
                if (userSnap.hasData && userSnap.data != null) {
                  userData = userSnap.data!.data() as Map<String, dynamic>?;
                }
                final senderName =
                    userData?['nickname'] ?? fromUserId ?? 'Someone';
                final senderPhoto = userData?['photoUrl'];
                String text = '';
                String notificationType = '';

                if (notif['type'] == 'friend_accept') {
                  notificationType = 'Friend Request Accepted';
                  text = '$senderName accepted your friend request.';
                } else if (notif['type'] == 'friend_request') {
                  notificationType = 'Friend Request';
                  text = '$senderName sent you a friend request.';
                } else if (notif['type'] == 'like') {
                  notificationType = 'Post Liked';
                  text = '$senderName liked your post.';
                } else if (notif['type'] == 'comment') {
                  notificationType = 'New Comment';
                  text = '$senderName commented on your post.';
                } else if (notif['type'] == 'group_post_like') {
                  notificationType = 'Group Post Liked';
                  final groupName = notif['groupName'] ?? 'a group';
                  text = '$senderName liked your post in "$groupName".';
                } else if (notif['type'] == 'group_post_comment') {
                  notificationType = 'Group Post Comment';
                  final groupName = notif['groupName'] ?? 'a group';
                  text = '$senderName commented on your post in "$groupName".';
                } else if (notif['type'] == 'group_join_request') {
                  notificationType = 'Group Join Request';
                  final groupName = notif['groupName'] ?? 'a group';
                  text = '$senderName requested to join "$groupName".';
                } else if (notif['type'] == 'group_join_approved') {
                  notificationType = 'Group Join Approved';
                  final groupName = notif['groupName'] ?? 'a group';
                  text =
                      'Your request to join "$groupName" was approved by $senderName.';
                } else if (notif['type'] == 'group_join_rejected') {
                  notificationType = 'Group Join Rejected';
                  final groupName = notif['groupName'] ?? 'a group';
                  text =
                      'Your request to join "$groupName" was rejected by $senderName.';
                } else if (notif['type'] == 'group_member_added') {
                  notificationType = 'Added to Group';
                  final groupName = notif['groupName'] ?? 'a group';
                  text = 'You were added to "$groupName" by $senderName.';
                } else if (notif['type'] == 'group_invitation') {
                  notificationType = 'Group Invitation';
                  final groupName = notif['groupName'] ?? 'a group';
                  text = '$senderName invited you to join "$groupName".';
                } else if (notif['type'] == 'group_invitation_pending') {
                  notificationType = 'Group Invitation Pending';
                  final groupName = notif['groupName'] ?? 'a group';
                  text =
                      '$senderName invited someone to join "$groupName". Review pending requests.';
                } else if (notif['type'] == 'group_post') {
                  notificationType = 'Group Post';
                  final groupName = notif['groupName'] ?? 'a group';
                  text = '$senderName posted in "$groupName".';
                } else {
                  notificationType = 'Notification';
                  text = 'You have a new notification.';
                }
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: senderPhoto != null &&
                            senderPhoto.isNotEmpty
                        ? NetworkImage(senderPhoto)
                        : const AssetImage('assets/logo.png') as ImageProvider,
                  ),
                  title: Text(
                    notificationType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text),
                      if (notif['timestamp'] != null)
                        Text(
                          _formatTimestamp(notif['timestamp'] as Timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: notif['read'] == false
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  onTap: () async {
                    // Mark this notification as read when tapped
                    if (notif['read'] == false) {
                      await NotificationService.markAsRead(
                          notifications[index].id);
                    }

                    // Navigate to relevant screen based on notification type
                    if (notif['type'] == 'friend_request') {
                      // Navigate to friend requests screen by calling the callback
                      if (onNavigateToRequests != null) {
                        onNavigateToRequests!();
                      }
                    } else if (notif['type'] == 'friend_accept') {
                      // Navigate to the sender's profile
                      if (fromUserId != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfileScreen(userId: fromUserId),
                          ),
                        );
                      }
                    } else if (notif['type'] == 'group_join_request' ||
                        notif['type'] == 'group_join_approved' ||
                        notif['type'] == 'group_join_rejected' ||
                        notif['type'] == 'group_member_added' ||
                        notif['type'] == 'group_invitation' ||
                        notif['type'] == 'group_invitation_pending' ||
                        notif['type'] == 'group_post' ||
                        notif['type'] == 'group_post_like' ||
                        notif['type'] == 'group_post_comment') {
                      // Navigate to group detail screen
                      final groupId = notif['groupId'] as String?;
                      if (groupId != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                GroupDetailScreen(groupId: groupId),
                          ),
                        );
                      }
                    }
                  },
                  tileColor: notif['read'] == false
                      ? Colors.blue.withOpacity(0.1)
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
