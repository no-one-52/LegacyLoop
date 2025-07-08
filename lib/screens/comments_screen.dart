import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import '../services/notification_service.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final bool isGroupPost;
  const CommentsScreen({super.key, required this.postId, this.isGroupPost = false});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _commentController.text.trim().isEmpty) return;
    setState(() { _isLoading = true; });
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final postDoc = await FirebaseFirestore.instance
        .collection(widget.isGroupPost ? 'group_posts' : 'posts')
        .doc(widget.postId)
        .get();
    final postData = postDoc.data() ?? {};
    await FirebaseFirestore.instance
        .collection(widget.isGroupPost ? 'group_posts' : 'posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'userId': user.uid,
      'userNickname': userData['nickname'] ?? user.email,
      'userPhotoUrl': userData['photoUrl'],
      'text': _commentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Create notification for post owner (if not own post)
    final postOwnerId = widget.isGroupPost ? postData['authorId'] : postData['userId'];
    
    if (postOwnerId != null && postOwnerId != user.uid) {
      if (widget.isGroupPost) {
        debugPrint('Creating group post comment notification');
        debugPrint('Post owner: $postOwnerId');
        debugPrint('Post ID: ${widget.postId}');
        debugPrint('Group ID: ${postData['groupId']}');
        debugPrint('Post data: $postData');
        
        if (postData['groupId'] != null) {
          await NotificationService.createGroupPostCommentNotification(postOwnerId, widget.postId, postData['groupId']);
        } else {
          debugPrint('ERROR: groupId is null in post data');
        }
      } else {
        await NotificationService.createCommentNotification(postOwnerId, widget.postId);
      }
    } else {
      debugPrint('Skipping notification: own post or no post owner');
    }
    _commentController.clear();
    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(widget.isGroupPost ? 'group_posts' : 'posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data!.docs;
                if (comments.isEmpty) {
                  return const Center(child: Text('No comments yet.'));
                }
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc((comment.data() as Map<String, dynamic>)['userId'])
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          return _buildCommentTile(comment);
                          } else {
                          return const SizedBox.shrink();
                          }
                        },
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                    ),
                  ),
                ),
                IconButton(
                  icon: _isLoading
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send, color: Color(0xFF4A90E2)),
                  onPressed: _isLoading ? null : _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(DocumentSnapshot comment) {
    final data = comment.data() as Map<String, dynamic>;
    final userPhotoUrl = data['userPhotoUrl'];
    final userNickname = data['userNickname'] ?? 'User';
    final text = data['text'] ?? '';
    final timestamp = data['timestamp'] != null && data['timestamp'] is Timestamp
        ? (data['timestamp'] as Timestamp).toDate()
        : null;
    final userId = data['userId'];

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          if (userId != null) {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && userId == currentUser.uid) {
              // Navigate to own profile
              Navigator.pushNamed(context, '/profile');
            } else {
              // Navigate to public profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: userId),
                ),
              );
            }
          }
        },
        child: CircleAvatar(
          backgroundImage: userPhotoUrl != null && userPhotoUrl.isNotEmpty
              ? NetworkImage(userPhotoUrl)
              : const AssetImage('assets/logo.png') as ImageProvider,
        ),
      ),
      title: GestureDetector(
        onTap: () {
          if (userId != null) {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && userId == currentUser.uid) {
              // Navigate to own profile
              Navigator.pushNamed(context, '/profile');
            } else {
              // Navigate to public profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: userId),
                ),
              );
            }
          }
        },
        child: Text(
          userNickname, 
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (timestamp != null)
            Text(
              '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} ${timestamp.day}/${timestamp.month}/${timestamp.year}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
} 