import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/comments_screen.dart';
import '../screens/like_list_screen.dart';
import '../screens/edit_post_screen.dart';
import '../screens/profile_screen.dart';
//import '../screens/public_profile_screen.dart';

class PostWidget extends StatefulWidget {
  final DocumentSnapshot post;
  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  int _currentImageIndex = 0;

  Future<void> _deletePost() async {
    try {
      // Delete the post document
      await widget.post.reference.delete();
      
      // Delete associated comments
      final commentsSnapshot = await widget.post.reference.collection('comments').get();
      
      for (var comment in commentsSnapshot.docs) {
        await comment.reference.delete();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePost();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFriendRequestButtonForPost(String userId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == userId) return const SizedBox.shrink();
    // Check for accepted friend request in either direction using two queries
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, sentSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where('fromUserId', isEqualTo: userId)
              .where('toUserId', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
          builder: (context, receivedSnapshot) {
            final isFriends = (sentSnapshot.data?.docs.isNotEmpty == true) ||
                              (receivedSnapshot.data?.docs.isNotEmpty == true);
            if (isFriends) {
              return const Icon(Icons.check_circle, color: Color(0xFF26A69A), size: 22);
            }
            // ...existing friend request button logic...
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('friend_requests')
                  .where('fromUserId', isEqualTo: currentUser.uid)
                  .where('toUserId', isEqualTo: userId)
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, sentSnapshot2) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('friend_requests')
                      .where('fromUserId', isEqualTo: userId)
                      .where('toUserId', isEqualTo: currentUser.uid)
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, receivedSnapshot2) {
                    final sent = sentSnapshot2.data?.docs.isNotEmpty == true ? sentSnapshot2.data!.docs.first : null;
                    final received = receivedSnapshot2.data?.docs.isNotEmpty == true ? receivedSnapshot2.data!.docs.first : null;
                    final sentStatus = sent != null ? (sent.data() as Map<String, dynamic>)['status'] : null;
                    final receivedStatus = received != null ? (received.data() as Map<String, dynamic>)['status'] : null;

                    if (sentStatus == 'pending') {
                      return Tooltip(
                        message: 'Request Sent',
                        child: IconButton(
                          icon: const Icon(Icons.hourglass_top, color: Colors.grey),
                          onPressed: null,
                        ),
                      );
                    } else if (receivedStatus == 'pending') {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Color(0xFF26A69A)),
                            tooltip: 'Accept',
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('friend_requests').doc(received!.id).update({'status': 'accepted'});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Decline',
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('friend_requests').doc(received!.id).update({'status': 'declined'});
                            },
                          ),
                        ],
                      );
                    } else {
                      return IconButton(
                        icon: const Icon(Icons.person_add, color: Color(0xFF7B1FA2)),
                        tooltip: 'Add Friend',
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('friend_requests').add({
                            'fromUserId': currentUser.uid,
                            'toUserId': userId,
                            'status': 'pending',
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                        },
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.post.data() as Map<String, dynamic>;
    final userPhotoUrl = data['userPhotoUrl'];
    final userNickname = data['userNickname'] ?? 'User';
    final text = data['text'] ?? '';
    final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];
    final imageUrl = data['imageUrl'];
    final timestamp = data['timestamp'] != null && data['timestamp'] is Timestamp
        ? (data['timestamp'] as Timestamp).toDate()
        : null;
    final likes = List<String>.from(data['likes'] ?? []);
    final likeCount = likes.length;
    final user = FirebaseAuth.instance.currentUser;
    final hasLiked = user != null && likes.contains(user.uid);
    final isOwnPost = user != null && data['userId'] == user.uid;

    void toggleLike() async {
      if (user == null) return;
      final postRef = widget.post.reference;
      if (hasLiked) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([user.uid])
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([user.uid])
        });
        // Create notification for post owner (if not own post)
        if (!isOwnPost) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': data['userId'],
            'type': 'like',
            'fromUserId': user.uid,
            'postId': widget.post.id,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }
    }

    void openComments() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommentsScreen(postId: widget.post.id),
        ),
      );
    }

    void openLikeList() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LikeListScreen(userIds: likes),
        ),
      );
    }

    void openUserProfile() {
      final userId = data['userId'];
      final currentUser = FirebaseAuth.instance.currentUser;
      if (userId != null) {
        if (currentUser != null && userId == currentUser.uid) {
          // Navigate to own profile screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        } else {
          // Navigate to public profile as a new page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: userId),
            ),
          );
        }
      }
    }

    void editPost() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditPostScreen(post: widget.post),
        ),
      );
    }

    List<String> displayImages = [];
    if (imageUrls.isNotEmpty) {
      displayImages = imageUrls;
    } else if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      displayImages = [imageUrl];
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: openUserProfile,
                  child: CircleAvatar(
                    backgroundImage: userPhotoUrl != null && userPhotoUrl.isNotEmpty
                        ? NetworkImage(userPhotoUrl)
                        : const AssetImage('assets/logo.png') as ImageProvider,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: openUserProfile,
                  child: Text(
                    userNickname,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                // Friend Request Button (compact)
                _buildFriendRequestButtonForPost(data['userId']),
                const Spacer(),
                if (timestamp != null)
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}\n${timestamp.day}/${timestamp.month}/${timestamp.year}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.right,
                  ),
                if (isOwnPost) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'edit') {
                        editPost();
                      } else if (value == 'delete') {
                        _showDeleteConfirmation();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edit Post'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Post', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(text, style: const TextStyle(fontSize: 15)),
            ],
            if (displayImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    SizedBox(
                      height: 260,
                      child: PageView.builder(
                        itemCount: displayImages.length,
                        controller: PageController(initialPage: _currentImageIndex),
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Image.network(
                            displayImages[index],
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
                    if (displayImages.length > 1)
                      Positioned(
                        bottom: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            displayImages.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index
                                    ? Colors.blue
                                    : Colors.white,
                                border: Border.all(color: Colors.blue, width: 1),
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
            FutureBuilder<QuerySnapshot>(
              future: widget.post.reference.collection('comments').get(),
              builder: (context, snapshot) {
                final commentCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        hasLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                        color: hasLiked ? Colors.blue : Colors.grey,
                      ),
                      onPressed: toggleLike,
                    ),
                    GestureDetector(
                      onTap: openLikeList,
                      child: Row(
                        children: [
                          Text('$likeCount'),
                          const SizedBox(width: 4),
                          const Text('Likes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.comment_outlined),
                      onPressed: openComments,
                    ),
                    Text('$commentCount', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    const Text('Comments', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 