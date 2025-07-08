import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/group_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
//import '../screens/public_profile_screen.dart';
import '../widgets/user_header.dart';
import '../screens/profile_screen.dart';
import 'search_screen.dart';
import '../screens/like_list_screen.dart';
import '../screens/comments_screen.dart';
import '../services/notification_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _groupData;
  bool _isMember = false;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    try {
      final groupData = await GroupService().getGroupDetails(widget.groupId);
      final isMember = await GroupService().isGroupMember(widget.groupId);
      final isAdmin = await GroupService().isGroupAdmin(widget.groupId);

      if (mounted) {
        setState(() {
          _groupData = groupData;
          _isMember = isMember;
          _isAdmin = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group: $e')),
        );
      }
    }
  }

  Future<void> _joinGroup() async {
    try {
      await GroupService().joinGroup(widget.groupId);
      await _loadGroupData(); // Reload data

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join request sent! Wait for admin approval.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error joining group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await GroupService().leaveGroup(widget.groupId);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the group'),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.pop(context); // Go back to groups screen
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreatePostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GroupCreatePostSheet(groupId: widget.groupId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_groupData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Group Not Found'),
          backgroundColor: const Color(0xFF7B1FA2),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('This group does not exist or has been deleted.'),
        ),
      );
    }

    final name = _groupData!['name'] as String? ?? 'Unknown Group';
    final description = _groupData!['description'] as String? ?? '';
    final coverImageUrl = _groupData!['coverImageUrl'] as String?;
    final memberCount = _groupData!['memberCount'] as int? ?? 0;
    final postCount = _groupData!['postCount'] as int? ?? 0;
    final isPrivate = _groupData!['isPrivate'] as bool? ?? false;
    final category = _groupData!['category'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        actions: [
          if (_isMember) ...[
            IconButton(
              icon: const Icon(Icons.post_add),
              onPressed: _showCreatePostDialog,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'leave':
                    _leaveGroup();
                    break;
                  case 'settings':
                    // TODO: Navigate to group settings
                    break;
                }
              },
              itemBuilder: (context) => [
                if (_isAdmin)
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Group Settings'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app),
                      SizedBox(width: 8),
                      Text('Leave Group'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Group Header
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    image: coverImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(coverImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: coverImageUrl == null ? Colors.grey[300] : null,
                  ),
                  child: coverImageUrl == null
                      ? const Center(
                          child: Icon(Icons.group, size: 64, color: Colors.grey),
                        )
                      : null,
                ),
                // Group Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            isPrivate ? Icons.lock : Icons.public,
                            color: isPrivate ? Colors.orange : Colors.green,
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$memberCount members',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.post_add, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$postCount posts',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (category != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Join/Leave Button
                      if (!_isMember)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _joinGroup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7B1FA2),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Join Group'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Posts'),
                  Tab(text: 'Members'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _AboutTab(groupData: _groupData!),
            _PostsTab(groupId: widget.groupId, isAdmin: _isAdmin),
            _MembersTab(
                groupId: widget.groupId,
                isAdmin: _isAdmin,
                isMember: _isMember),
          ],
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  final Map<String, dynamic> groupData;

  const _AboutTab({required this.groupData});

  @override
  Widget build(BuildContext context) {
    final description = groupData['description'] as String? ?? '';
    final category = groupData['category'] as String?;
    final createdAt = groupData['createdAt'] as Timestamp?;
    final createdBy = groupData['createdBy'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
          ],
          if (category != null) ...[
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          const Text(
            'Group Info',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (createdAt != null) ...[
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Created',
              value: _formatDate(createdAt.toDate()),
            ),
          ],
          if (createdBy != null) ...[
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text(
                  'Created by: ',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(createdBy)
                      .get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Text('Loading...');
                    }
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const Text('Unknown User');
                    }
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    final nickname = userData['nickname'] ?? createdBy;
                    final photoUrl = userData['photoUrl'] as String? ?? '';
                    return UserHeader(
                      userId: createdBy,
                      userPhotoUrl: photoUrl,
                      userNickname: nickname,
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  final String groupId;
  final bool isAdmin;

  const _PostsTab({required this.groupId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: isAdmin ? 2 : 1,
      child: Column(
        children: [
          if (isAdmin)
            const TabBar(
              tabs: [
                Tab(text: 'Approved Posts'),
                Tab(text: 'Pending Approval'),
              ],
            ),
          Expanded(
            child: TabBarView(
              children: [
                _ApprovedPostsTab(groupId: groupId),
                if (isAdmin) _PendingPostsTab(groupId: groupId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovedPostsTab extends StatelessWidget {
  final String groupId;

  const _ApprovedPostsTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: GroupService().getGroupPosts(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final errorString = snapshot.error.toString();
          final urlRegExp = RegExp(r'(https?://[^\s]+)');
          final match = urlRegExp.firstMatch(errorString);
          if (match != null) {
            final url = match.group(0)!;
            final beforeUrl = errorString.substring(0, match.start);
            final afterUrl = errorString.substring(match.end);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: beforeUrl),
                      TextSpan(
                        text: url,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                      ),
                      TextSpan(text: afterUrl),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return Center(child: SelectableText('Error: $errorString'));
          }
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(
            child: Text('No posts yet in this group'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            post['id'] = posts[index].id;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(post['authorId'])
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
            return _GroupPostCard(post: post);
                } else {
                  return const SizedBox.shrink();
                }
              },
            );
          },
        );
      },
    );
  }
}

class _PendingPostsTab extends StatelessWidget {
  final String groupId;

  const _PendingPostsTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: GroupService().getPendingPosts(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final errorString = snapshot.error.toString();
          final urlRegExp = RegExp(r'(https?://[^\s]+)');
          final match = urlRegExp.firstMatch(errorString);
          if (match != null) {
            final url = match.group(0)!;
            final beforeUrl = errorString.substring(0, match.start);
            final afterUrl = errorString.substring(match.end);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: beforeUrl),
                      TextSpan(
                        text: url,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                      ),
                      TextSpan(text: afterUrl),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return Center(child: SelectableText('Error: $errorString'));
          }
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(
            child: Text('No pending posts'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            post['id'] = posts[index].id;

            return _PendingPostCard(post: post);
          },
        );
      },
    );
  }
}

class _GroupPostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const _GroupPostCard({required this.post});

  @override
  State<_GroupPostCard> createState() => _GroupPostCardState();
}

class _GroupPostCardState extends State<_GroupPostCard> {
  late List<String> likes;
  late bool hasLiked;
  late String? postId;
  late String? authorId;
  final ValueNotifier<int> _currentImageIndex = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    likes = List<String>.from(widget.post['likes'] ?? []);
    final user = FirebaseAuth.instance.currentUser;
    hasLiked = user != null && likes.contains(user.uid);
    postId = widget.post['id'] as String?;
    authorId = widget.post['authorId'] as String?;
  }

  void _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || postId == null) return;
    final postRef = FirebaseFirestore.instance.collection('group_posts').doc(postId);
    setState(() {
      if (hasLiked) {
        likes.remove(user.uid);
      } else {
        likes.add(user.uid);
      }
      hasLiked = !hasLiked;
    });
    if (hasLiked) {
      await postRef.update({'likes': FieldValue.arrayUnion([user.uid])});
      // Send notification to post author if not self
      if (authorId != null && authorId != user.uid) {
        await NotificationService.createGroupPostLikeNotification(authorId!, postId!, widget.post['groupId']);
      }
    } else {
      await postRef.update({'likes': FieldValue.arrayRemove([user.uid])});
    }
  }

  void _openLikeList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LikeListScreen(userIds: likes),
      ),
    );
  }

  void _openComments() {
    if (postId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(postId: postId!, isGroupPost: true),
      ),
    );
  }

  void _openUserProfile(BuildContext context, String userId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (userId == currentUser?.uid) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.post['content'] as String? ?? '';
    final imageUrls = (widget.post['imageUrls'] as List?)?.cast<String>() ?? [];
    final authorId = widget.post['authorId'] as String?;
    final createdAt = widget.post['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            FutureBuilder<DocumentSnapshot>(
              future: authorId != null
                  ? FirebaseFirestore.instance.collection('users').doc(authorId).get()
                  : Future.value(null),
              builder: (context, snapshot) {
                String? nickname;
                String? photoUrl;
                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  nickname = data?['nickname'] as String?;
                  photoUrl = data?['photoUrl'] as String?;
                }
                return GestureDetector(
                  onTap: authorId != null ? () => _openUserProfile(context, authorId) : null,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : const AssetImage('assets/logo.png') as ImageProvider,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nickname ?? authorId ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (createdAt != null)
                              Text(
                                _formatDate(createdAt.toDate()),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Content
            Text(content),

            // Images (carousel)
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    SizedBox(
                      height: 260,
                      child: PageView.builder(
                        itemCount: imageUrls.length,
                        onPageChanged: (idx) => _currentImageIndex.value = idx,
                        itemBuilder: (context, idx) {
                          return Image.network(
                            imageUrls[idx],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.error, size: 50, color: Colors.grey),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (imageUrls.length > 1)
                      Positioned(
                        bottom: 8,
                        child: ValueListenableBuilder<int>(
                          valueListenable: _currentImageIndex,
                          builder: (context, idx, _) => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              imageUrls.length,
                              (i) => Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: idx == i ? Colors.blue : Colors.white,
                                  border: Border.all(color: Colors.blue, width: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: postId != null
                  ? FirebaseFirestore.instance.collection('group_posts').doc(postId).snapshots()
                  : null,
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final likeList = List<String>.from(data?['likes'] ?? likes);
                final likeCount = likeList.length;
                final user = FirebaseAuth.instance.currentUser;
                final hasLiked = user != null && likeList.contains(user.uid);
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        hasLiked
                            ? Icons.thumb_up_alt
                            : Icons.thumb_up_alt_outlined,
                        color: hasLiked ? Colors.blue : Colors.grey,
                      ),
                      onPressed: _toggleLike,
                    ),
                    GestureDetector(
                      onTap: _openLikeList,
                      child: Row(
                        children: [
                          Text('$likeCount'),
                          const SizedBox(width: 4),
                          const Text('Likes',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: postId != null
                          ? FirebaseFirestore.instance
                              .collection('group_posts')
                              .doc(postId)
                              .collection('comments')
                              .snapshots()
                          : null,
                      builder: (context, commentSnap) {
                        final commentCount =
                            commentSnap.data?.docs.length ?? 0;
                        return Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.comment_outlined),
                              onPressed: _openComments,
                            ),
                            Text('$commentCount',
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            const Text('Comments',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _PendingPostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PendingPostCard({required this.post});

  void _openUserProfile(BuildContext context, String userId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (userId == currentUser?.uid) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = post['content'] as String? ?? '';
    final imageUrls = (post['imageUrls'] as List?)?.cast<String>() ?? [];
    final authorId = post['authorId'] as String?;
    final createdAt = post['createdAt'] as Timestamp?;
    final currentImageIndex = ValueNotifier<int>(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with approval buttons
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<DocumentSnapshot>(
                    future: authorId != null
                        ? FirebaseFirestore.instance.collection('users').doc(authorId).get()
                        : Future.value(null),
                    builder: (context, snapshot) {
                      String? nickname;
                      String? photoUrl;
                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        nickname = data?['nickname'] as String?;
                        photoUrl = data?['photoUrl'] as String?;
                      }
                      return GestureDetector(
                        onTap: authorId != null ? () => _openUserProfile(context, authorId) : null,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? NetworkImage(photoUrl)
                                  : const AssetImage('assets/logo.png') as ImageProvider,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nickname ?? authorId ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (createdAt != null)
                                    Text(
                                      _formatDate(createdAt.toDate()),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        GroupService().approvePost(post['id']).then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post approved'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }).catchError((e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error approving post: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Approve'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        GroupService().rejectPost(post['id']).then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post rejected'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }).catchError((e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error rejecting post: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            Text(content),

            // Images (carousel)
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    SizedBox(
                      height: 260,
                      child: PageView.builder(
                        itemCount: imageUrls.length,
                        onPageChanged: (idx) => currentImageIndex.value = idx,
                        itemBuilder: (context, idx) {
                          return Image.network(
                            imageUrls[idx],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.error, size: 50, color: Colors.grey),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (imageUrls.length > 1)
                      Positioned(
                        bottom: 8,
                        child: ValueListenableBuilder<int>(
                          valueListenable: currentImageIndex,
                          builder: (context, idx, _) => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              imageUrls.length,
                              (i) => Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: idx == i ? Colors.blue : Colors.white,
                                  border: Border.all(color: Colors.blue, width: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _MembersTab extends StatelessWidget {
  final String groupId;
  final bool isAdmin;
  final bool isMember;

  const _MembersTab(
      {required this.groupId, required this.isAdmin, required this.isMember});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isAdmin || isMember)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (isAdmin)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Member'),
                    onPressed: () async {
                      final userId = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const SearchScreen(selectUserMode: true)),
                      );
                      if (userId != null) {
                        try {
                          await GroupService()
                              .addMemberAsAdmin(groupId, userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Member added!'),
                                backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                if (!isAdmin && isMember)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite Member'),
                    onPressed: () async {
                      final userId = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const SearchScreen(selectUserMode: true)),
                      );
                      if (userId != null) {
                        try {
                          await GroupService().inviteMember(groupId, userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Invite sent!'),
                                backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        Expanded(
          child: DefaultTabController(
            length: isAdmin ? 2 : 1,
            child: Column(
              children: [
                if (isAdmin)
                  const TabBar(
                    tabs: [
                      Tab(text: 'Members'),
                      Tab(text: 'Pending'),
                    ],
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildMembersView(),
                      if (isAdmin) _buildPendingView(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersView() {
    return StreamBuilder<QuerySnapshot>(
      stream: GroupService().getGroupMembers(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final approvedMembers = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] == 'admin' || data['role'] == 'member';
        }).toList();
        if (approvedMembers.isEmpty) {
          return const Center(child: Text('No members yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: approvedMembers.length,
          itemBuilder: (context, index) {
            final member =
                approvedMembers[index].data() as Map<String, dynamic>;
            final userId = member['userId'] as String?;
            final role = member['role'] as String?;
            return _buildMemberTile(
                userId, role, approvedMembers[index].id, context);
          },
        );
      },
    );
  }

  Widget _buildPendingView() {
    return StreamBuilder<QuerySnapshot>(
      stream: GroupService().getPendingMembers(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pendingMembers = snapshot.data!.docs;
        if (pendingMembers.isEmpty) {
          return const Center(child: Text('No pending requests'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingMembers.length,
          itemBuilder: (context, index) {
            final member = pendingMembers[index].data() as Map<String, dynamic>;
            final userId = member['userId'] as String?;
            final membershipId = pendingMembers[index].id;
            return _buildPendingMemberTile(userId, membershipId, context);
          },
        );
      },
    );
  }

  Widget _buildMemberTile(
      String? userId, String? role, String membershipId, BuildContext context) {
    return ListTile(
      onTap: userId == null
          ? null
          : () {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null && userId == currentUser.uid) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: userId),
                  ),
                );
              }
            },
      leading: null,
      title: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading...');
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Text('Unknown User');
          }
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final nickname = userData['nickname'] ?? userId!;
          final photoUrl = userData['photoUrl'] as String? ?? '';
          return UserHeader(
            userId: userId!,
            userPhotoUrl: photoUrl,
            userNickname: nickname,
          );
        },
      ),
      subtitle: Text(role == 'admin' ? 'Admin' : 'Member'),
      trailing: isAdmin && userId != null && role != 'admin'
          ? IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              tooltip: 'Remove Member',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Member'),
                    content: const Text(
                        'Are you sure you want to remove this member?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await GroupService().removeMember(groupId, userId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Member removed!'),
                          backgroundColor: Colors.orange),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
            )
          : null,
    );
  }

  Widget _buildPendingMemberTile(
      String? userId, String membershipId, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: null,
        title: FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Text('Unknown User');
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final nickname = userData['nickname'] ?? userId!;
            final photoUrl = userData['photoUrl'] as String? ?? '';
            return UserHeader(
              userId: userId!,
              userPhotoUrl: photoUrl,
              userNickname: nickname,
            );
          },
        ),
        subtitle: const Text('Pending approval'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Approve',
              onPressed: () async {
                try {
                  await GroupService().approveMember(membershipId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Member approved!'),
                        backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Reject',
              onPressed: () async {
                try {
                  await GroupService().rejectMember(membershipId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Member request rejected!'),
                        backgroundColor: Colors.orange),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GroupCreatePostSheet extends StatefulWidget {
  final String groupId;
  const GroupCreatePostSheet({super.key, required this.groupId});
  @override
  State<GroupCreatePostSheet> createState() => _GroupCreatePostSheetState();
}

class _GroupCreatePostSheetState extends State<GroupCreatePostSheet> {
  final TextEditingController _contentController = TextEditingController();
  List<File> _selectedImages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (pickedFiles.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedImages = pickedFiles.map((f) => File(f.path)).toList();
      });
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty) return;
    if (_isLoading) return;

    try {
      if (mounted) setState(() { _isLoading = true; });
      final isAdmin = await GroupService().isGroupAdmin(widget.groupId);
      await GroupService().createGroupPost(
        groupId: widget.groupId,
        content: _contentController.text.trim(),
        images: _selectedImages,
      );
      if (!mounted) return;
      setState(() { _isLoading = false; });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdmin
              ? 'Post created successfully!'
              : 'Post submitted for approval'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).dialogBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Post Content',
                  hintText: 'What\'s on your mind?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              if (_selectedImages.isNotEmpty) ...[
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) => Stack(
                      children: [
                        Image.file(
                          _selectedImages[idx],
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isLoading ? null : () {
                              setState(() {
                                _selectedImages.removeAt(idx);
                              });
                            },
                            child: Container(
                              color: Colors.black54,
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImages,
                    icon: const Icon(Icons.image),
                    label: const Text('Add Images'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createPost,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Post'),
                  ),
                ],
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF7B1FA2),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
