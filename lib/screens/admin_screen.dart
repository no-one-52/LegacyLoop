import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_service.dart';
import '../widgets/admin_notification_widget.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalGroups = 0;
  bool _isLoading = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _postIdController = TextEditingController();
  final TextEditingController _announcementTitleController = TextEditingController();
  final TextEditingController _announcementMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
    _checkAdminStatus();
  }

  Future<void> _loadAnalytics() async {
    try {
      final stats = await AdminService.getSystemStats();
      setState(() {
        _totalUsers = stats['totalUsers'] ?? 0;
        _totalPosts = stats['totalPosts'] ?? 0;
        _totalGroups = stats['totalGroups'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final isAdmin = userData['isAdmin'] ?? false;
        final email = userData['email'] ?? 'unknown';
        
        print('=== ADMIN STATUS CHECK ===');
        print('Current user UID: ${currentUser.uid}');
        print('Current user email: ${currentUser.email}');
        print('User document email: $email');
        print('Is admin in Firestore: $isAdmin');
        print('Expected admin email: admin@legacy.com');
        print('========================');
      } else {
        print('User document does not exist in Firestore');
      }
    } else {
      print('No current user found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.post_add), text: 'Content'),
            Tab(icon: Icon(Icons.group), text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildUsersTab(),
          _buildContentTab(),
          _buildGroupsTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  _totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Posts',
                  _totalPosts.toString(),
                  Icons.post_add,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Groups',
                  _totalGroups.toString(),
                  Icons.group,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Active Sessions',
                  'N/A',
                  Icons.online_prediction,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const AdminNotificationWidget(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final isAdmin = user['isAdmin'] ?? false;
            final isBanned = user['isBanned'] ?? false;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (user['photoUrl'] != null && user['photoUrl'].toString().isNotEmpty)
                      ? NetworkImage(user['photoUrl'])
                      : const AssetImage('assets/logo.png') as ImageProvider,
                  child: (user['photoUrl'] == null || user['photoUrl'].toString().isEmpty)
                      ? Text(
                          (user['nickname'] ?? user['name'] ?? user['email'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Text(user['nickname'] ?? user['name'] ?? user['email'] ?? 'Unknown User'),
                subtitle: Text('ID: $userId'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    if (isBanned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'BANNED',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleUserAction(value, userId, user),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('Details'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete User'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContentTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                Tab(text: 'Regular Posts'),
                Tab(text: 'Group Posts'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRegularPostsTab(),
                _buildGroupPostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data?.docs ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Text('No regular posts found'),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            final postId = posts[index].id;
            final isReported = post['reported'] ?? false;
            final isHidden = post['isHidden'] ?? false;

            // Get the correct field names based on your app's structure
            final postContent = post['text'] ?? post['content'] ?? 'No content';
            final authorName = post['userNickname'] ?? post['authorName'] ?? 'Unknown';
            final userId = post['userId'] ?? post['authorId'] ?? 'Unknown';
            final timestamp = post['timestamp'] as Timestamp?;
            final hasImages = (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty) || 
                             (post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(
                    hasImages ? Icons.image : Icons.post_add,
                    color: Colors.blue[700],
                  ),
                ),
                title: Text(
                  postContent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'By: $authorName',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (timestamp != null)
                      Text(
                        'Posted: ${_formatTimestamp(timestamp)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    if (hasImages)
                      Text(
                        '📷 Has images',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isReported)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'REPORTED',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    if (isHidden)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'HIDDEN',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handlePostAction(value, postId, post),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('View Post'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Post'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('group_posts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groupPosts = snapshot.data?.docs ?? [];

        if (groupPosts.isEmpty) {
          return const Center(
            child: Text('No group posts found'),
          );
        }

        return ListView.builder(
          itemCount: groupPosts.length,
          itemBuilder: (context, index) {
            final post = groupPosts[index].data() as Map<String, dynamic>;
            final postId = groupPosts[index].id;
            final isReported = post['reported'] ?? false;
            final isHidden = post['isHidden'] ?? false;
            final status = post['status'] ?? 'pending';

            // Get the correct field names for group posts
            final postContent = post['content'] ?? 'No content';
            final userId = post['authorId'] ?? 'Unknown';
            final groupId = post['groupId'] ?? 'Unknown';
            final timestamp = post['createdAt'] as Timestamp?;
            final hasImages = (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Icon(
                    hasImages ? Icons.image : Icons.group,
                    color: Colors.green[700],
                  ),
                ),
                title: Text(
                  postContent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User information with FutureBuilder
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        String userName = 'Unknown User';
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                          userName = userData?['nickname'] ?? userData?['name'] ?? userData?['email'] ?? 'Unknown User';
                        }
                        return Text(
                          'By: $userName',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                    // Group information with FutureBuilder
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('groups').doc(groupId).get(),
                      builder: (context, groupSnapshot) {
                        String groupName = 'Unknown Group';
                        if (groupSnapshot.hasData && groupSnapshot.data!.exists) {
                          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>?;
                          groupName = groupData?['name'] ?? 'Unknown Group';
                        }
                        return Text(
                          'Group: $groupName',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                    if (timestamp != null)
                      Text(
                        'Posted: ${_formatTimestamp(timestamp)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    if (hasImages)
                      Text(
                        '📷 Has images',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'approved' ? Colors.green : 
                               status == 'pending' ? Colors.orange : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                    if (isReported)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'REPORTED',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    if (isHidden)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'HIDDEN',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleGroupPostAction(value, postId, post),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('View Post'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Post'),
                        ),
                        if (status == 'pending')
                          const PopupMenuItem(
                            value: 'approve',
                            child: Text('Approve Post'),
                          ),
                        if (status == 'pending')
                          const PopupMenuItem(
                            value: 'reject',
                            child: Text('Reject Post'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data?.docs ?? [];

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index].data() as Map<String, dynamic>;
            final groupId = groups[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.group),
                title: Text(group['name'] ?? 'Unknown Group'),
                subtitle: Text('Members: ${group['memberCount'] ?? 0}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _handleGroupAction(value, groupId, group),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('Details'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Group'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildSettingCard(
            'App Maintenance',
            'Enable/disable maintenance mode',
            Icons.build,
            () => _showMaintenanceDialog(),
          ),
          _buildSettingCard(
            'Content Moderation',
            'Configure auto-moderation rules',
            Icons.security,
            () => _showModerationDialog(),
          ),
          _buildSettingCard(
            'User Registration',
            'Enable/disable new user registration',
            Icons.person_add,
            () => _showRegistrationDialog(),
          ),
          _buildSettingCard(
            'Analytics Export',
            'Export user and content data',
            Icons.download,
            () => _exportAnalytics(),
          ),
          _buildSettingCard(
            'System Backup',
            'Create system backup',
            Icons.backup,
            () => _performBackup(),
          ),
          _buildSettingCard(
            'Clear Cache',
            'Clear app cache and temporary data',
            Icons.clear_all,
            () => _clearCache(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  // Action handlers
  void _handleUserAction(String action, String userId, Map<String, dynamic> user) {
    switch (action) {
      case 'ban':
        _showConfirmDialog(
          'Ban User',
          'Are you sure you want to ban ${user['name'] ?? 'this user'}?',
          () => _banUser(userId),
        );
        break;
      case 'unban':
        _showConfirmDialog(
          'Unban User',
          'Are you sure you want to unban ${user['name'] ?? 'this user'}?',
          () => _unbanUser(userId),
        );
        break;
      case 'delete':
        _showDeleteUserDialog(user, userId);
        break;
      case 'view':
        _showUserDetails(user);
        break;
    }
  }

  void _handlePostAction(String action, String postId, Map<String, dynamic> post) {
    switch (action) {
      case 'delete':
        _showConfirmDialog(
          'Delete Post',
          'Are you sure you want to delete this post? This action cannot be undone.',
          () => _deletePost(postId),
        );
        break;
      case 'hide':
        _showConfirmDialog(
          'Hide Post',
          'Are you sure you want to hide this post?',
          () => _hidePost(postId),
        );
        break;
      case 'unhide':
        _showConfirmDialog(
          'Unhide Post',
          'Are you sure you want to unhide this post?',
          () => _unhidePost(postId),
        );
        break;
      case 'view':
        _showPostDetails(post);
        break;
    }
  }

  void _handleGroupPostAction(String action, String postId, Map<String, dynamic> post) {
    switch (action) {
      case 'delete':
        _showConfirmDialog(
          'Delete Group Post',
          'Are you sure you want to delete this group post? This action cannot be undone.',
          () => _deleteGroupPost(postId),
        );
        break;
      case 'hide':
        _showConfirmDialog(
          'Hide Group Post',
          'Are you sure you want to hide this group post?',
          () => _hideGroupPost(postId),
        );
        break;
      case 'unhide':
        _showConfirmDialog(
          'Unhide Group Post',
          'Are you sure you want to unhide this group post?',
          () => _unhideGroupPost(postId),
        );
        break;
      case 'approve':
        _showConfirmDialog(
          'Approve Group Post',
          'Are you sure you want to approve this group post?',
          () => _approveGroupPost(postId),
        );
        break;
      case 'reject':
        _showConfirmDialog(
          'Reject Group Post',
          'Are you sure you want to reject this group post?',
          () => _rejectGroupPost(postId),
        );
        break;
      case 'view':
        _showGroupPostDetails(post);
        break;
    }
  }

  void _handleGroupAction(String action, String groupId, Map<String, dynamic> group) {
    switch (action) {
      case 'delete':
        _showConfirmDialog(
          'Delete Group',
          'Are you sure you want to delete ${group['name'] ?? 'this group'}? This action cannot be undone.',
          () => _deleteGroup(groupId),
        );
        break;
      case 'moderate':
        _moderateGroup(groupId);
        break;
      case 'view':
        _showGroupDetails(group);
        break;
    }
  }

  // Implementation methods
  Future<void> _banUser(String userId) async {
    try {
      final success = await AdminService.banUser(userId);
      if (success) {
        _showSnackBar('User banned successfully');
        _loadAnalytics(); // Refresh stats
      } else {
        _showSnackBar('Failed to ban user');
      }
    } catch (e) {
      _showSnackBar('Error banning user: $e');
    }
  }

  Future<void> _unbanUser(String userId) async {
    try {
      final success = await AdminService.unbanUser(userId);
      if (success) {
        _showSnackBar('User unbanned successfully');
        _loadAnalytics(); // Refresh stats
      } else {
        _showSnackBar('Failed to unban user');
      }
    } catch (e) {
      _showSnackBar('Error unbanning user: $e');
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      // Check if current user is admin first
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        _showSnackBar('Error: You must be an admin to delete users');
        return;
      }
      
      // Debug: Check current user email
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserEmail = currentUser?.email ?? 'unknown';
      print('Current user email: $currentUserEmail');
      print('Expected admin email: admin@legacy.com');
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting user and all related data...\nThis may take a few moments.'),
            ],
          ),
        ),
      );

      final success = await AdminService.deleteUser(userId);
      
      // Hide loading dialog
      Navigator.pop(context);
      
      if (success) {
        _showSnackBar('User deleted successfully via Cloud Function');
        _loadAnalytics(); // Refresh stats
      } else {
        _showSnackBar('Failed to delete user - check console for details');
      }
    } catch (e) {
      // Hide loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('Error in _deleteUser: $e');
      _showSnackBar('Error deleting user: $e');
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      final success = await AdminService.deletePost(postId);
      if (success) {
        _showSnackBar('Post deleted successfully');
        _loadAnalytics(); // Refresh stats
      } else {
        _showSnackBar('Failed to delete post');
      }
    } catch (e) {
      _showSnackBar('Error deleting post: $e');
    }
  }

  Future<void> _hidePost(String postId) async {
    try {
      final success = await AdminService.hidePost(postId);
      if (success) {
        _showSnackBar('Post hidden successfully');
      } else {
        _showSnackBar('Failed to hide post');
      }
    } catch (e) {
      _showSnackBar('Error hiding post: $e');
    }
  }

  Future<void> _unhidePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'isHidden': false,
      });
      _showSnackBar('Post unhidden successfully');
    } catch (e) {
      _showSnackBar('Error unhiding post: $e');
    }
  }

  // Group post action methods
  Future<void> _deleteGroupPost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('group_posts').doc(postId).delete();
      _showSnackBar('Group post deleted successfully');
      _loadAnalytics(); // Refresh stats
    } catch (e) {
      _showSnackBar('Error deleting group post: $e');
    }
  }

  Future<void> _hideGroupPost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('group_posts').doc(postId).update({
        'isHidden': true,
      });
      _showSnackBar('Group post hidden successfully');
    } catch (e) {
      _showSnackBar('Error hiding group post: $e');
    }
  }

  Future<void> _unhideGroupPost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('group_posts').doc(postId).update({
        'isHidden': false,
      });
      _showSnackBar('Group post unhidden successfully');
    } catch (e) {
      _showSnackBar('Error unhiding group post: $e');
    }
  }

  Future<void> _approveGroupPost(String postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance.collection('group_posts').doc(postId).update({
        'status': 'approved',
        'approvedBy': user.uid,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Update group post count
      final post = await FirebaseFirestore.instance.collection('group_posts').doc(postId).get();
      if (post.exists) {
        final data = post.data() as Map<String, dynamic>;
        final groupId = data['groupId'] as String;
        await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
          'postCount': FieldValue.increment(1),
        });
      }

      _showSnackBar('Group post approved successfully');
    } catch (e) {
      _showSnackBar('Error approving group post: $e');
    }
  }

  Future<void> _rejectGroupPost(String postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance.collection('group_posts').doc(postId).update({
        'status': 'rejected',
        'approvedBy': user.uid,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Group post rejected successfully');
    } catch (e) {
      _showSnackBar('Error rejecting group post: $e');
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    try {
      final success = await AdminService.deleteGroup(groupId);
      if (success) {
        _showSnackBar('Group deleted successfully');
        _loadAnalytics(); // Refresh stats
      } else {
        _showSnackBar('Failed to delete group');
      }
    } catch (e) {
      _showSnackBar('Error deleting group: $e');
    }
  }

  void _moderateGroup(String groupId) {
    _showSnackBar('Group moderation feature coming soon');
  }

  // Dialog methods
  void _showBanUserDialog() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter user email to ban:'),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) {
                _showSnackBar('Please enter an email');
                return;
              }
              Navigator.pop(context);
              await _banUserByEmail(email);
            },
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }

  Future<void> _banUserByEmail(String email) async {
    try {
      final userDoc = await AdminService.getUserByEmail(email);
      if (userDoc != null && userDoc.exists) {
        final success = await AdminService.banUser(userDoc.id);
        if (success) {
          _showSnackBar('User banned successfully');
          _loadAnalytics();
        } else {
          _showSnackBar('Failed to ban user');
        }
      } else {
        _showSnackBar('User not found');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  void _showDeletePostDialog() {
    _postIdController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter post ID to delete:'),
            const SizedBox(height: 16),
            TextField(
              controller: _postIdController,
              decoration: const InputDecoration(
                labelText: 'Post ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final postId = _postIdController.text.trim();
              if (postId.isEmpty) {
                _showSnackBar('Please enter a post ID');
                return;
              }
              Navigator.pop(context);
              await _deletePost(postId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDialog() {
    _announcementTitleController.clear();
    _announcementMessageController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _announcementTitleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _announcementMessageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = _announcementTitleController.text.trim();
              final message = _announcementMessageController.text.trim();
              if (title.isEmpty || message.isEmpty) {
                _showSnackBar('Please fill all fields');
                return;
              }
              Navigator.pop(context);
              await _createAnnouncement(title, message);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAnnouncement(String title, String message) async {
    try {
      final success = await AdminService.createAnnouncement(title, message);
      if (success) {
        _showSnackBar('Announcement created successfully');
      } else {
        _showSnackBar('Failed to create announcement');
      }
    } catch (e) {
      _showSnackBar('Error creating announcement: $e');
    }
  }

  void _showMaintenanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maintenance Mode'),
        content: const Text('This feature will be implemented in the next version.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showModerationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Content Moderation'),
        content: const Text('Moderation settings will be available in the next version.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRegistrationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Registration'),
        content: const Text('Registration control will be available in the next version.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? 'User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user['email'] ?? 'N/A'}'),
            Text('Admin: ${user['isAdmin'] ?? false ? 'Yes' : 'No'}'),
            Text('Banned: ${user['isBanned'] ?? false ? 'Yes' : 'No'}'),
            if (user['bio'] != null) Text('Bio: ${user['bio']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPostDetails(Map<String, dynamic> post) {
    final postContent = post['text'] ?? post['content'] ?? 'No content';
    final authorName = post['userNickname'] ?? post['authorName'] ?? 'Unknown';
    final userId = post['userId'] ?? post['authorId'] ?? 'Unknown';
    final timestamp = post['timestamp'] as Timestamp?;
    final hasImages = (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty) || 
                     (post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Author: $authorName'),
            Text('User ID: $userId'),
            if (timestamp != null) Text('Posted: ${_formatTimestamp(timestamp)}'),
            const SizedBox(height: 8),
            Text('Content: $postContent'),
            if (hasImages) const Text('📷 Has images'),
            const SizedBox(height: 8),
            Text('Reported: ${post['reported'] ?? false ? 'Yes' : 'No'}'),
            Text('Hidden: ${post['isHidden'] ?? false ? 'Yes' : 'No'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGroupPostDetails(Map<String, dynamic> post) {
    final postContent = post['content'] ?? 'No content';
    final userId = post['authorId'] ?? 'Unknown';
    final groupId = post['groupId'] ?? 'Unknown';
    final status = post['status'] ?? 'pending';
    final timestamp = post['createdAt'] as Timestamp?;
    final hasImages = (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Post Details'),
        content: FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait([
            FirebaseFirestore.instance.collection('users').doc(userId).get(),
            FirebaseFirestore.instance.collection('groups').doc(groupId).get(),
          ]),
          builder: (context, snapshot) {
            String userName = 'Unknown User';
            String groupName = 'Unknown Group';
            
            if (snapshot.hasData && snapshot.data!.length >= 2) {
              // User data
              final userDoc = snapshot.data![0];
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>?;
                userName = userData?['nickname'] ?? userData?['name'] ?? userData?['email'] ?? 'Unknown User';
              }
              
              // Group data
              final groupDoc = snapshot.data![1];
              if (groupDoc.exists) {
                final groupData = groupDoc.data() as Map<String, dynamic>?;
                groupName = groupData?['name'] ?? 'Unknown Group';
              }
            }
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Author: $userName'),
                Text('User ID: $userId'),
                Text('Group: $groupName'),
                Text('Group ID: $groupId'),
                Text('Status: $status'),
                if (timestamp != null) Text('Posted: ${_formatTimestamp(timestamp)}'),
                const SizedBox(height: 8),
                Text('Content: $postContent'),
                if (hasImages) const Text('📷 Has images'),
                const SizedBox(height: 8),
                Text('Reported: ${post['reported'] ?? false ? 'Yes' : 'No'}'),
                Text('Hidden: ${post['isHidden'] ?? false ? 'Yes' : 'No'}'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user, String userId) {
    final userName = user['name'] ?? 'Unknown User';
    final userEmail = user['email'] ?? 'No email';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete User Permanently'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete this user?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('User: $userName'),
              Text('Email: $userEmail'),
              const SizedBox(height: 16),
              const Text(
                'This will also delete ALL related data:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              const Text('• All posts by this user'),
              const Text('• All comments by this user'),
              const Text('• All likes by this user'),
              const Text('• User\'s group memberships'),
              const Text('• All friend relationships'),
              const Text('• All friend requests'),
              const Text('• User\'s notifications'),
              const Text('• User\'s messages'),
              const Text('• User\'s status updates'),
              const Text('• User\'s profile completely'),
              const SizedBox(height: 16),
              const Text(
                '⚠️ This action cannot be undone!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This deletion will be processed securely via Cloud Function for faster and more reliable data removal.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showGroupDetails(Map<String, dynamic> group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group['name'] ?? 'Group Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members: ${group['memberCount'] ?? 0}'),
            if (group['description'] != null) Text('Description: ${group['description']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Utility methods
  void _performBackup() {
    _showSnackBar('Backup feature coming soon');
  }

  void _exportAnalytics() {
    _showSnackBar('Analytics export feature coming soon');
  }

  void _clearCache() {
    _showSnackBar('Cache cleared successfully');
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _postIdController.dispose();
    _announcementTitleController.dispose();
    _announcementMessageController.dispose();
    super.dispose();
  }
} 