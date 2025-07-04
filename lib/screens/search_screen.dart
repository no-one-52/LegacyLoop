import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;
import 'profile_screen.dart';
import '../widgets/post_widget.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  final bool selectUserMode;
  const SearchScreen({super.key, this.selectUserMode = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Posts', icon: Icon(Icons.article)),
            Tab(text: 'Hashtags', icon: Icon(Icons.tag)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7B1FA2)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _UsersTab(searchQuery: _searchQuery, selectUserMode: widget.selectUserMode),
                _PostsTab(searchQuery: _searchQuery),
                _HashtagsTab(searchQuery: _searchQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  final String searchQuery;
  final bool selectUserMode;
  const _UsersTab({required this.searchQuery, this.selectUserMode = false});

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Search for users by name, nickname, or email', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').limit(100).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!.docs;
        final query = searchQuery.toLowerCase();
        final filtered = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nickname = (data['nickname'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final name = (data['name'] ?? '').toString().toLowerCase();
          return nickname.contains(query) || email.contains(query) || name.contains(query);
        }).toList();
        // Sort by best match (startsWith > contains)
        filtered.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final nicknameA = (dataA['nickname'] ?? '').toString().toLowerCase();
          final emailA = (dataA['email'] ?? '').toString().toLowerCase();
          final nameA = (dataA['name'] ?? '').toString().toLowerCase();
          final nicknameB = (dataB['nickname'] ?? '').toString().toLowerCase();
          final emailB = (dataB['email'] ?? '').toString().toLowerCase();
          final nameB = (dataB['name'] ?? '').toString().toLowerCase();
          int score(String s) {
            if (s.startsWith(query)) return 0;
            if (s.contains(query)) return 1;
            return 2;
          }
          final scoreA = [score(nicknameA), score(emailA), score(nameA)].reduce((a, b) => a < b ? a : b);
          final scoreB = [score(nicknameB), score(emailB), score(nameB)].reduce((a, b) => a < b ? a : b);
          return scoreA.compareTo(scoreB);
        });
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No users found for "$searchQuery"', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final userData = filtered[index].data() as Map<String, dynamic>;
            final userId = filtered[index].id;
            final nickname = userData['nickname'] ?? 'Unknown User';
            final photoUrl = userData['photoUrl'];
            final currentUser = FirebaseAuth.instance.currentUser;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : const AssetImage('assets/logo.png') as ImageProvider,
                radius: 25,
              ),
              title: Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(userData['email'] ?? ''),
              trailing: selectUserMode
                  ? ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, userId);
                      },
                      child: const Text('Select'),
                    )
                  : currentUser?.uid != userId
                      ? _buildFriendRequestButton(userId)
                      : const Chip(label: Text('You', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF7B1FA2)),
              onTap: selectUserMode
                  ? () {
                      Navigator.pop(context, userId);
                    }
                  : () {
                      if (currentUser?.uid == userId) {
                        Navigator.pushNamed(context, '/profile');
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
                        );
                      }
                    },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendRequestButton(String targetUserId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: targetUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final requests = snapshot.data!.docs;
        String buttonText = 'Add Friend';
        Color buttonColor = const Color(0xFF7B1FA2);
        VoidCallback? onPressed;

        if (requests.isNotEmpty) {
          final requestData = requests.first.data() as Map<String, dynamic>;
          final status = requestData['status'] as String?;
          
          switch (status) {
            case 'pending':
              buttonText = 'Request Sent';
              buttonColor = Colors.orange;
              break;
            case 'accepted':
              buttonText = 'Friends';
              buttonColor = Colors.green;
              break;
            case 'declined':
              buttonText = 'Add Friend';
              buttonColor = const Color(0xFF7B1FA2);
              onPressed = () => _sendFriendRequest(targetUserId);
              break;
          }
        } else {
          onPressed = () => _sendFriendRequest(targetUserId);
        }

        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(buttonText, style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }

  void _sendFriendRequest(String targetUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance.collection('friend_requests').add({
        'fromUserId': currentUser.uid,
        'toUserId': targetUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': targetUserId,
        'type': 'friend_request',
        'fromUserId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }
}

class _PostsTab extends StatelessWidget {
  final String searchQuery;
  const _PostsTab({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Search for posts by content or hashtags', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('posts').orderBy('timestamp', descending: true).limit(100).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data!.docs;
        final query = searchQuery.toLowerCase();
        final filtered = posts.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final text = (data['text'] ?? '').toString().toLowerCase();
          final nickname = (data['userNickname'] ?? '').toString().toLowerCase();
          return text.contains(query) || nickname.contains(query);
        }).toList();
        // Sort by best match (startsWith > contains)
        filtered.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final textA = (dataA['text'] ?? '').toString().toLowerCase();
          final nicknameA = (dataA['userNickname'] ?? '').toString().toLowerCase();
          final textB = (dataB['text'] ?? '').toString().toLowerCase();
          final nicknameB = (dataB['userNickname'] ?? '').toString().toLowerCase();
          int score(String s) {
            if (s.startsWith(query)) return 0;
            if (s.contains(query)) return 1;
            return 2;
          }
          final scoreA = [score(textA), score(nicknameA)].reduce((a, b) => a < b ? a : b);
          final scoreB = [score(textB), score(nicknameB)].reduce((a, b) => a < b ? a : b);
          return scoreA.compareTo(scoreB);
        });
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No posts found for "$searchQuery"', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final post = filtered[index];
            return PostWidget(post: post);
          },
        );
      },
    );
  }
}

class _HashtagsTab extends StatelessWidget {
  final String searchQuery;
  const _HashtagsTab({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Search for hashtags', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('posts').orderBy('timestamp', descending: true).limit(100).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data!.docs;
        final query = searchQuery.toLowerCase().replaceAll('#', '');
        final hashtags = <String, int>{};
        for (var doc in posts) {
          final data = doc.data() as Map<String, dynamic>;
          final tags = (data['hashtags'] ?? []) as List?;
          if (tags != null) {
            for (var tag in tags) {
              final tagStr = tag.toString().toLowerCase();
              if (tagStr.contains(query)) {
                hashtags[tagStr] = (hashtags[tagStr] ?? 0) + 1;
              }
            }
          }
        }
        final sortedTags = hashtags.keys.toList()
          ..sort((a, b) => hashtags[b]!.compareTo(hashtags[a]!));
        if (sortedTags.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No hashtags found for "$searchQuery"', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: sortedTags.length,
          itemBuilder: (context, index) {
            final tag = sortedTags[index];
            return ListTile(
              leading: const Icon(Icons.tag, color: Color(0xFF7B1FA2)),
              title: Text('#$tag', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${hashtags[tag]} posts'),
            );
          },
        );
      },
    );
  }
} 