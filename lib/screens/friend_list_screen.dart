import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/user_status_widget.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';

class FriendListScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  final bool isOwnProfile;

  const FriendListScreen({
    super.key,
    required this.userId,
    this.userName,
    this.isOwnProfile = false,
  });

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildTitleWithCount(),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        actions: [
          if (widget.isOwnProfile)
            IconButton(
              icon: const Icon(Icons.message, color: Colors.white),
              tooltip: 'Messages',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MessagesScreen()),
                );
              },
            ),
        ],
      ),
      body: _buildFriendsList(),
    );
  }

  Widget _buildTitleWithCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('status', isEqualTo: 'accepted')
          .where('fromUserId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, sentSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where('status', isEqualTo: 'accepted')
              .where('toUserId', isEqualTo: widget.userId)
              .snapshots(),
          builder: (context, receivedSnapshot) {
            int friendCount = 0;
            
            if (sentSnapshot.hasData) {
              friendCount += sentSnapshot.data!.docs.length;
            }
            
            if (receivedSnapshot.hasData) {
              friendCount += receivedSnapshot.data!.docs.length;
            }

            String title = widget.isOwnProfile 
                ? 'My Friends ($friendCount)' 
                : '${widget.userName ?? 'User'}\'s Friends ($friendCount)';

            return Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('status', isEqualTo: 'accepted')
          .where('fromUserId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, sentSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where('status', isEqualTo: 'accepted')
              .where('toUserId', isEqualTo: widget.userId)
              .snapshots(),
          builder: (context, receivedSnapshot) {
            if (sentSnapshot.connectionState == ConnectionState.waiting ||
                receivedSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (sentSnapshot.hasError || receivedSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading friends: ${sentSnapshot.error ?? receivedSnapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Collect all friend IDs
            final Set<String> friendIds = {};
            
            if (sentSnapshot.hasData) {
              for (var doc in sentSnapshot.data!.docs) {
                friendIds.add(doc['toUserId'] as String);
              }
            }
            
            if (receivedSnapshot.hasData) {
              for (var doc in receivedSnapshot.data!.docs) {
                friendIds.add(doc['fromUserId'] as String);
              }
            }

            if (friendIds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isOwnProfile ? Icons.people_outline : Icons.person_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isOwnProfile 
                        ? 'No friends yet'
                        : '${widget.userName ?? 'User'} has no friends yet',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    if (widget.isOwnProfile) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Start connecting with people!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              );
            }

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .where(FieldPath.documentId, whereIn: friendIds.toList())
                  .get(),
              builder: (context, usersSnapshot) {
                if (!usersSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = usersSnapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userId = users[index].id;
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          final name = userData['nickname'] ?? userData['email'] ?? 'User';
                          final photoUrl = userData['photoUrl'] as String?;
                          final email = userData['email'] as String?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                        ? NetworkImage(photoUrl)
                                        : const AssetImage('assets/logo.png') as ImageProvider,
                                    child: (photoUrl == null || photoUrl.isEmpty)
                                        ? const Icon(Icons.person, size: 25, color: Colors.grey)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: UserStatusIndicator(
                                      userId: userId,
                                      size: 16,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  UserStatusText(
                                    userId: userId,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: email != null ? Text(email) : null,
                              trailing: widget.isOwnProfile
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'message':
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => MessagesScreen(),
                                              ),
                                            );
                                            break;
                                          case 'profile':
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ProfileScreen(
                                                  userId: userId,
                                                ),
                                              ),
                                            );
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'message',
                                          child: Row(
                                            children: [
                                              Icon(Icons.message, size: 20),
                                              SizedBox(width: 8),
                                              Text('Message'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'profile',
                                          child: Row(
                                            children: [
                                              Icon(Icons.person, size: 20),
                                              SizedBox(width: 8),
                                              Text('View Profile'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                      userId: userId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
} 