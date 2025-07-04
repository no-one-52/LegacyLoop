import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'create_post_screen.dart';
import '../widgets/post_widget.dart';
import 'friend_requests_screen.dart';
import 'package:rxdart/rxdart.dart';
import 'messages_screen.dart';
import '../services/user_status_service.dart';
//import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // Optional userId to view someone else's profile
  
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _schoolController = TextEditingController();
  final _collegeController = TextEditingController();
  final _universityController = TextEditingController();
  
  bool _isEditing = false;
  bool _isLoading = false;
  String? _photoUrl;
  String? _email;
  String? _coverPhotoUrl;
  String? _viewingUserId;
  bool _isOwnProfile = true;
  
  // User preferences
  List<String> _interests = [];
  List<String> _preferredPostTypes = ['All Posts'];
  String _privacyLevel = 'public';
  
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _determineProfileType();
  }

  void _determineProfileType() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (widget.userId != null && currentUser != null) {
      // Viewing someone else's profile
      _viewingUserId = widget.userId;
      _isOwnProfile = widget.userId == currentUser.uid;
    } else if (currentUser != null) {
      // Viewing own profile
      _viewingUserId = currentUser.uid;
      _isOwnProfile = true;
    }
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _schoolController.dispose();
    _collegeController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_viewingUserId == null) return;
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_viewingUserId).get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nicknameController.text = data['nickname'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _schoolController.text = data['school'] ?? '';
          _collegeController.text = data['college'] ?? '';
          _universityController.text = data['university'] ?? '';
          _photoUrl = data['photoUrl'];
          _coverPhotoUrl = data['coverPhotoUrl'];
          _email = data['email'] ?? '';
          _interests = List<String>.from(data['interests'] ?? []);
          _preferredPostTypes = List<String>.from(data['preferredPostTypes'] ?? ['All Posts']);
          _privacyLevel = data['privacyLevel'] ?? 'public';
        });
      } else {
        setState(() {
          _nicknameController.text = 'User not found';
          _bioController.text = '';
          _schoolController.text = '';
          _collegeController.text = '';
          _universityController.text = '';
          _photoUrl = null;
          _coverPhotoUrl = null;
          _email = '';
          _interests = [];
          _preferredPostTypes = ['All Posts'];
          _privacyLevel = 'public';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage({bool isCoverPhoto = false}) async {
    if (!_isEditing || !_isOwnProfile) return;
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: isCoverPhoto ? 1200 : 512,
      maxHeight: isCoverPhoto ? 400 : 512,
      imageQuality: 80,
    );
    
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && _isOwnProfile) {
          final file = File(pickedFile.path);
          final fileName = isCoverPhoto ? 'cover_${user.uid}.jpg' : 'profile_${user.uid}.jpg';
          final ref = FirebaseStorage.instance.ref().child('profile_photos/$fileName');
          await ref.putFile(file);
          final url = await ref.getDownloadURL();
          
          final updateData = isCoverPhoto ? {'coverPhotoUrl': url} : {'photoUrl': url};
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updateData);
          
          setState(() {
            if (isCoverPhoto) {
              _coverPhotoUrl = url;
            } else {
              _photoUrl = url;
            }
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${isCoverPhoto ? 'Cover' : 'Profile'} photo updated!')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || !_isOwnProfile) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _isOwnProfile) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'nickname': _nicknameController.text.trim(),
          'bio': _bioController.text.trim(),
          'school': _schoolController.text.trim(),
          'college': _collegeController.text.trim(),
          'university': _universityController.text.trim(),
          'interests': _interests,
          'preferredPostTypes': _preferredPostTypes,
          'privacyLevel': _privacyLevel,
        });
        
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
    _loadUserData();
  }

  Future<void> _signOut() async {
    try {
      // Cleanup user status before signing out
      await UserStatusService().cleanup();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        elevation: 0,
        leading: _isOwnProfile ? null : BackButton(),
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_isEditing && _isOwnProfile)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Cancel',
              onPressed: _cancelEdit,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              tooltip: 'Messages',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MessagesScreen()),
                );
              },
            ),
            if (_isOwnProfile)
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () async {
                  await UserStatusService().cleanup();
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Camera and Save icons row (edit mode only)
                  if (_isEditing && _isOwnProfile)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.camera_alt, color: Color(0xFF1877F2)),
                            tooltip: 'Edit Cover Photo',
                            onPressed: () => _pickImage(isCoverPhoto: true),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.save, color: Color(0xFF1877F2)),
                            tooltip: 'Save',
                            onPressed: _saveProfile,
                          ),
                        ],
                      ),
                    ),
                  // Cover Photo
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: _coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF1877F2), Color(0xFF42A5F5)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          image: _coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_coverPhotoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                      ),
                      // Profile Photo
                      Positioned(
                        bottom: 8, // move higher so full circle is visible
                        left: 24,
                        child: GestureDetector(
                          onTap: (_isEditing && _isOwnProfile) ? () => _pickImage() : null,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                                      ? NetworkImage(_photoUrl!)
                                      : const AssetImage('assets/logo.png') as ImageProvider,
                                  child: _photoUrl == null || _photoUrl!.isEmpty
                                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                      : null,
                                ),
                              ),
                              if (_isEditing && _isOwnProfile)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1877F2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40), // Reduced space for a more compact look
                  // Edit Profile Button
                  if (!_isEditing && _isOwnProfile)
                    Padding(
                      padding: const EdgeInsets.only(right: 24.0),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1877F2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Message Button (only for other users)
                  if (!_isOwnProfile)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7B1FA2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.message),
                          label: const Text('Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  friendId: _viewingUserId!,
                                  friendName: _nicknameController.text,
                                  friendPhotoUrl: _photoUrl,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // Profile Info Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and Bio
                        Text(
                          _nicknameController.text.isNotEmpty 
                              ? _nicknameController.text 
                              : 'Add your name',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1E21),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_bioController.text.isNotEmpty)
                          Text(
                            _bioController.text,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF65676B),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Education Info
                        if (_schoolController.text.isNotEmpty || 
                            _collegeController.text.isNotEmpty || 
                            _universityController.text.isNotEmpty) ...[
                          _buildInfoRow(Icons.school, 'Education', [
                            if (_schoolController.text.isNotEmpty) _schoolController.text,
                            if (_collegeController.text.isNotEmpty) _collegeController.text,
                            if (_universityController.text.isNotEmpty) _universityController.text,
                          ]),
                          const SizedBox(height: 16),
                        ],
                        // Email
                        if (_email != null)
                          _buildInfoRow(Icons.email, 'Email', [_email!]),
                        // Friend Request Button
                        _buildFriendRequestButton(),
                      ],
                    ),
                  ),
                  // Tabs
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE4E6EB), width: 1),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF1877F2),
                      unselectedLabelColor: const Color(0xFF65676B),
                      indicatorColor: const Color(0xFF1877F2),
                      tabs: const [
                        Tab(text: 'Posts'),
                        Tab(text: 'About'),
                        Tab(text: 'Preferences'),
                      ],
                    ),
                  ),
                  // Tab Content
                  SizedBox(
                    height: 600,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostsTab(),
                        _buildAboutTab(),
                        _buildPreferencesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: (_selectedTabIndex == 0 && _isOwnProfile) ? FloatingActionButton(
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildInfoRow(IconData icon, String title, List<String> items) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF65676B), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1E21),
                ),
              ),
              ...items.map((item) => Text(
                item,
                style: const TextStyle(color: Color(0xFF65676B)),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: _viewingUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading posts...'),
              ],
            ),
          );
        }
        
        // Handle error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        // Handle no data state
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Share your first post!',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        final posts = snapshot.data!.docs;
        
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostWidget(post: post);
            },
          ),
        );
      },
    );
  }

  Widget _buildAboutTab() {
    if (_isOwnProfile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('About', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(controller: _nicknameController, decoration: const InputDecoration(labelText: 'Full Name *'), enabled: _isEditing),
              const SizedBox(height: 16),
              TextFormField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'), enabled: _isEditing, maxLines: 3),
              const SizedBox(height: 16),
              TextFormField(controller: _schoolController, decoration: const InputDecoration(labelText: 'School'), enabled: _isEditing),
              const SizedBox(height: 16),
              TextFormField(controller: _collegeController, decoration: const InputDecoration(labelText: 'College'), enabled: _isEditing),
              const SizedBox(height: 16),
              TextFormField(controller: _universityController, decoration: const InputDecoration(labelText: 'University'), enabled: _isEditing),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout), label: const Text('Sign Out'))),
            ],
          ),
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About ${_nicknameController.text.isNotEmpty ? _nicknameController.text : 'User'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (_bioController.text.isNotEmpty) ...[
              _buildInfoRow(Icons.info_outline, 'Bio', [_bioController.text]),
              const SizedBox(height: 16),
            ],
            if (_schoolController.text.isNotEmpty || _collegeController.text.isNotEmpty || _universityController.text.isNotEmpty) ...[
              _buildInfoRow(Icons.school, 'Education', [
                if (_schoolController.text.isNotEmpty) _schoolController.text,
                if (_collegeController.text.isNotEmpty) _collegeController.text,
                if (_universityController.text.isNotEmpty) _universityController.text,
              ]),
              const SizedBox(height: 16),
            ],
            if (_email != null && _email!.isNotEmpty) ...[
              _buildInfoRow(Icons.email, 'Email', [_email!]),
              const SizedBox(height: 16),
            ],
            if (_bioController.text.isEmpty && _schoolController.text.isEmpty && _collegeController.text.isEmpty && _universityController.text.isEmpty && (_email == null || _email!.isEmpty)) ...[
              const Center(child: Column(children: [Icon(Icons.info_outline, size: 64, color: Colors.grey), SizedBox(height: 16), Text('No information available', style: TextStyle(fontSize: 18, color: Colors.grey))])),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildPreferencesTab() {
    return const Center(
      child: Text(
        'Preferences coming soon...',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildFriendRequestButton() {
    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint('FriendRequestButton: currentUser=${currentUser?.uid}, viewingUserId=$_viewingUserId, isOwnProfile=$_isOwnProfile');
    if (_isOwnProfile || _viewingUserId == null || currentUser == null) return const SizedBox();
    ValueNotifier<bool> isSending = ValueNotifier(false);

    final sentStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .where('toUserId', isEqualTo: _viewingUserId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();

    final receivedStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: _viewingUserId)
        .where('toUserId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();

    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([sentStream, receivedStream]),
      builder: (context, snapshot) {
        debugPrint('StreamBuilder snapshot: hasData=[1m${snapshot.hasData}[0m, error=${snapshot.error}, connectionState=${snapshot.connectionState}');
        if (snapshot.hasError) {
          return Center(child: Text('Error: [31m${snapshot.error}[0m'));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final sent = snapshot.data![0].docs.isNotEmpty ? snapshot.data![0].docs.first : null;
        final received = snapshot.data![1].docs.isNotEmpty ? snapshot.data![1].docs.first : null;

        // Fallback: If both are null, show Add Friend
        if (sent == null && received == null) {
          return ValueListenableBuilder<bool>(
            valueListenable: isSending,
            builder: (context, loading, _) {
              return ElevatedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        isSending.value = true;
                        final docRef = await FirebaseFirestore.instance.collection('friend_requests').add({
                          'fromUserId': currentUser.uid,
                          'toUserId': _viewingUserId,
                          'status': 'pending',
                          'timestamp': FieldValue.serverTimestamp(),
                          'viewedByReceiver': false,
                        });
                        // Create notification for receiver
                        await FirebaseFirestore.instance.collection('notifications').add({
                          'userId': _viewingUserId,
                          'type': 'friend_request',
                          'fromUserId': currentUser.uid,
                          'timestamp': FieldValue.serverTimestamp(),
                          'read': false,
                        });
                        debugPrint('Notification created for $_viewingUserId');
                        if (!mounted) return;
                        isSending.value = false;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Friend request sent!'), backgroundColor: Colors.blue, duration: Duration(seconds: 1)),
                        );
                      },
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add),
                label: Text(loading ? 'Sending...' : 'Add Friend'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B1FA2)),
              );
            },
          );
        }

        Map<String, dynamic>? latest;
        String? requestId;
        bool isSender = false;
        bool isReceiver = false;
        Timestamp? sentTime;
        Timestamp? receivedTime;

        if (sent != null) sentTime = (sent.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
        if (received != null) receivedTime = (received.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;

        if (sent != null && received != null) {
          if (sentTime != null && receivedTime != null) {
            if (sentTime.compareTo(receivedTime) >= 0) {
              latest = sent.data() as Map<String, dynamic>;
              requestId = sent.id;
              isSender = true;
            } else {
              latest = received.data() as Map<String, dynamic>;
              requestId = received.id;
              isReceiver = true;
            }
          } else if (sentTime != null) {
            latest = sent.data() as Map<String, dynamic>;
            requestId = sent.id;
            isSender = true;
          } else if (receivedTime != null) {
            latest = received.data() as Map<String, dynamic>;
            requestId = received.id;
            isReceiver = true;
          }
        } else if (sent != null) {
          latest = sent.data() as Map<String, dynamic>;
          requestId = sent.id;
          isSender = true;
        } else if (received != null) {
          latest = received.data() as Map<String, dynamic>;
          requestId = received.id;
          isReceiver = true;
        }

        final status = latest != null ? latest['status'] : null;

        debugPrint('FriendRequestButton: isSender=$isSender, isReceiver=$isReceiver, status=$status, requestId=$requestId');

        // If accepted, show Unfriend button
        if (status == 'accepted') {
          return ElevatedButton.icon(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({'status': 'unfriended'});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unfriended successfully'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
              );
            },
            icon: const Icon(Icons.person_remove),
            label: const Text('Unfriend'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          );
        }
        // If I sent a pending request, show 'Cancel Request' (enabled)
        if (status == 'pending' && isSender) {
          return ElevatedButton.icon(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({'status': 'cancelled'});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Friend request cancelled'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
              );
            },
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel Request'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          );
        }
        // If I received a pending request, show Accept/Decline
        if (status == 'pending' && isReceiver) {
          return Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({'status': 'accepted'});
                    // Create notification for sender
                    await FirebaseFirestore.instance.collection('notifications').add({
                      'userId': latest!['fromUserId'],
                      'type': 'friend_accept',
                      'fromUserId': currentUser.uid,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend request accepted!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF26A69A)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({'status': 'declined'});
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend request declined'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          );
        }
        // If declined/cancelled/unfriended or no request, show Add Friend
        if (status == 'declined' || status == 'cancelled' || status == 'unfriended' || latest == null) {
          return ValueListenableBuilder<bool>(
            valueListenable: isSending,
            builder: (context, loading, _) {
              return ElevatedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        isSending.value = true;
                        final docRef = await FirebaseFirestore.instance.collection('friend_requests').add({
                          'fromUserId': currentUser.uid,
                          'toUserId': _viewingUserId,
                          'status': 'pending',
                          'timestamp': FieldValue.serverTimestamp(),
                          'viewedByReceiver': false,
                        });
                        // Create notification for receiver
                        await FirebaseFirestore.instance.collection('notifications').add({
                          'userId': _viewingUserId,
                          'type': 'friend_request',
                          'fromUserId': currentUser.uid,
                          'timestamp': FieldValue.serverTimestamp(),
                          'read': false,
                        });
                        debugPrint('Notification created for $_viewingUserId');
                        if (!mounted) return;
                        isSending.value = false;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Friend request sent!'), backgroundColor: Colors.blue, duration: Duration(seconds: 1)),
                        );
                      },
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add),
                label: Text(loading ? 'Sending...' : 'Add Friend'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B1FA2)),
              );
            },
          );
        }
        // Fallback (should not be reached)
        return const SizedBox();
      },
    );
  }
}

// Add a placeholder messaging screen
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