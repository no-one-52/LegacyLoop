import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/group_service.dart';
import '../widgets/post_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
//import '../screens/public_profile_screen.dart';
import '../widgets/user_header.dart';
import '../widgets/user_search_dialog.dart';
import '../screens/profile_screen.dart';
import 'search_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with TickerProviderStateMixin {
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
          content: Text('Request to join group sent!'),
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
    showDialog(
      context: context,
      builder: (context) => _CreatePostDialog(groupId: widget.groupId),
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
    final createdAt = _groupData!['createdAt'] as Timestamp?;
    final createdBy = _groupData!['createdBy'] as String?;

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
        bottom: TabBar(
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
      body: Column(
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AboutTab(groupData: _groupData!),
                _PostsTab(groupId: widget.groupId, isAdmin: _isAdmin),
                _MembersTab(groupId: widget.groupId, isAdmin: _isAdmin, isMember: _isMember),
              ],
            ),
          ),
        ],
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
                  future: FirebaseFirestore.instance.collection('users').doc(createdBy).get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Loading...');
                    }
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const Text('Unknown User');
                    }
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
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
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            return Center(child: SelectableText('Error: ' + errorString));
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
            
            return _GroupPostCard(post: post);
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
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            return Center(child: SelectableText('Error: ' + errorString));
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

class _GroupPostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _GroupPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final content = post['content'] as String? ?? '';
    final imageUrl = post['imageUrl'] as String?;
    final authorId = post['authorId'] as String?;
    final createdAt = post['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ID: $authorId', // You could fetch user name here
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
            
            const SizedBox(height: 12),
            
            // Content
            Text(content),
            
            // Image
            if (imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
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

class _PendingPostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PendingPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final content = post['content'] as String? ?? '';
    final imageUrl = post['imageUrl'] as String?;
    final authorId = post['authorId'] as String?;
    final createdAt = post['createdAt'] as Timestamp?;

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
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: const Icon(Icons.person),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User ID: $authorId',
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            
            // Image
            if (imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
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

  const _MembersTab({required this.groupId, required this.isAdmin, required this.isMember});

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
                        MaterialPageRoute(builder: (context) => const SearchScreen(selectUserMode: true)),
                      );
                      if (userId != null) {
                        try {
                          await GroupService().addMemberAsAdmin(groupId, userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Member added!'), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                        MaterialPageRoute(builder: (context) => const SearchScreen(selectUserMode: true)),
                      );
                      if (userId != null) {
                        try {
                          await GroupService().inviteMember(groupId, userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invite sent!'), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
                  final member = approvedMembers[index].data() as Map<String, dynamic>;
                  final userId = member['userId'] as String?;
                  final role = member['role'] as String?;
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
                                  builder: (context) => ProfileScreen(userId: userId!),
                                ),
                              );
                            }
                          },
                    leading: null,
                    title: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
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
                                  content: const Text('Are you sure you want to remove this member?'),
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
                                    const SnackBar(content: Text('Member removed!'), backgroundColor: Colors.orange),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreatePostDialog extends StatefulWidget {
  final String groupId;

  const _CreatePostDialog({required this.groupId});

  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  final TextEditingController _contentController = TextEditingController();
  File? _selectedImage;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty) return;
    
    try {
      await GroupService().createGroupPost(
        groupId: widget.groupId,
        content: _contentController.text.trim(),
        image: _selectedImage,
      );
      
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post submitted for approval'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
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
    return AlertDialog(
      title: const Text('Create Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              labelText: 'Post Content',
              hintText: 'What\'s on your mind?',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null) ...[
            Image.file(
              _selectedImage!,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image),
            label: const Text('Add Image'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createPost,
          child: const Text('Post'),
        ),
      ],
    );
  }
}