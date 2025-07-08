import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:async';
import '../services/user_status_service.dart';
import '../widgets/user_status_widget.dart';

class MessagesScreen extends StatefulWidget {
  final VoidCallback? onUnreadReset;
  const MessagesScreen({super.key, this.onUnreadReset});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
      ),
      body: _MessagesBody(onUnreadReset: widget.onUnreadReset),
    );
  }
}

class _MessagesBody extends StatefulWidget {
  final VoidCallback? onUnreadReset;
  const _MessagesBody({this.onUnreadReset});

  @override
  State<_MessagesBody> createState() => _MessagesBodyState();
}

class _MessagesBodyState extends State<_MessagesBody> {
  final user = FirebaseAuth.instance.currentUser;
  final Set<String> _viewedConversations = {};

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: user!.uid)
          .orderBy('lastTimestamp', descending: true)
          .snapshots(),
      builder: (context, convoSnapshot) {
        if (convoSnapshot.hasError) {
          return Center(child: Text('Error: ${convoSnapshot.error}'));
        }
        if (!convoSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final conversations = convoSnapshot.data!.docs;
        // Collect userIds from conversations
        final convoUserIds = <String>{};
        for (var doc in conversations) {
          final participants = List<String>.from(doc['participants'] ?? []);
          for (var p in participants) {
            if (p != user!.uid) convoUserIds.add(p);
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where('status', isEqualTo: 'accepted')
              .where('fromUserId', isEqualTo: user!.uid)
              .snapshots(),
          builder: (context, sentSnapshot) {
            if (!sentSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final sentFriends = sentSnapshot.data!.docs.map((doc) => doc['toUserId'] as String).toSet();

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('friend_requests')
                  .where('status', isEqualTo: 'accepted')
                  .where('toUserId', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, receivedSnapshot) {
                if (!receivedSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final receivedFriends = receivedSnapshot.data!.docs.map((doc) => doc['fromUserId'] as String).toSet();

                // Merge all userIds: friends + conversation partners
                final allUserIds = <String>{}
                  ..addAll(convoUserIds)
                  ..addAll(sentFriends)
                  ..addAll(receivedFriends);

                if (allUserIds.isEmpty) {
                  return const Center(child: Text('No messages or friends yet.'));
                }

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where(FieldPath.documentId, whereIn: allUserIds.toList())
                      .get(),
                  builder: (context, usersSnapshot) {
                    if (!usersSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = usersSnapshot.data!.docs;
                    // Map userId to user data
                    final userMap = {for (var u in users) u.id: u.data() as Map<String, dynamic>};

                    // Build the list of message/friend tiles
                    return ListView.separated(
                      itemCount: allUserIds.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final friendId = allUserIds.elementAt(index);
                        final userData = userMap[friendId];
                        final photoUrl = userData?['photoUrl'] as String?;
                        final name = userData?['nickname'] ?? userData?['email'] ?? 'User';

                        // Find the conversation doc for this user (if any)
                        QueryDocumentSnapshot? convoDoc;
                        for (var doc in conversations) {
                          if ((List<String>.from(doc['participants'] ?? [])).contains(friendId)) {
                            convoDoc = doc;
                            break;
                          }
                        }
                        final lastMessage = convoDoc != null
                            ? (convoDoc.get('lastMessage') ?? '')
                            : '';
                        
                        // Calculate unread count for this conversation
                        int unread = 0;
                        if (convoDoc != null) {
                          final data = convoDoc.data() as Map<String, dynamic>;
                          final lastMessageSenderId = data.containsKey('lastMessageSenderId') ? data['lastMessageSenderId'] : null;
                          final seenBy = List<String>.from(data['seenBy'] ?? []);
                          final unreadCount = data['unreadCount'] ?? 0;
                          
                          // Show unread count only if:
                          // 1. The last message is from the friend
                          // 2. The current user hasn't seen it
                          // 3. There are actually unread messages
                          // 4. The conversation hasn't been viewed in this session
                          if (lastMessageSenderId != null && 
                              lastMessageSenderId == friendId && 
                              !seenBy.contains(user!.uid) &&
                              unreadCount > 0 &&
                              !_viewedConversations.contains(friendId)) {
                            unread = unreadCount;
                          }
                        }

                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : const AssetImage('assets/logo.png') as ImageProvider,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: UserStatusIndicator(
                                  userId: friendId,
                                  size: 16,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(name)),
                              UserStatusText(
                                userId: friendId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: unread > 0
                              ? CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF7B1FA2),
                                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                )
                              : null,
                          onTap: () async {
                            // Mark this conversation as viewed
                            _viewedConversations.add(friendId);
                            
                            // Reset unread count immediately for this conversation
                            if (convoDoc != null) {
                              await _resetUnreadCountForConversation(convoDoc.id);
                            }
                            
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  friendId: friendId,
                                  friendName: name,
                                  friendPhotoUrl: photoUrl,
                                  onUnreadReset: widget.onUnreadReset,
                                ),
                              ),
                            );
                            
                            // Force rebuild to update unread counts
                            setState(() {});
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
      },
    );
  }

  Future<void> _resetUnreadCountForConversation(String conversationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
        'unreadCount': 0,
        'seenBy': FieldValue.arrayUnion([user!.uid]),
      });
      
      if (widget.onUnreadReset != null) {
        widget.onUnreadReset!();
      }
    } catch (e) {
      print('Error resetting unread count: $e');
    }
  }
}

class ChatScreen extends StatefulWidget {
  final String friendName;
  final String? friendPhotoUrl;
  final String friendId;
  final VoidCallback? onUnreadReset;
  const ChatScreen({super.key, required this.friendName, this.friendPhotoUrl, required this.friendId, this.onUnreadReset});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;
  bool _isTyping = false;
  Timer? _typingTimer;
  final ScrollController _scrollController = ScrollController();

  String get conversationId {
    final ids = [user!.uid, widget.friendId]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    // Listen for typing indicators
    _listenToTyping();
    // Reset unread count immediately when chat opens
    _resetUnreadCountOnOpen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset unread count when dependencies change
    _resetUnreadCountOnOpen();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _stopTyping();
    _controller.dispose();
    _scrollController.dispose();
    // Call the callback to update the parent screen when leaving
    if (widget.onUnreadReset != null) {
      widget.onUnreadReset!();
    }
    super.dispose();
  }

  void _listenToTyping() {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('typing')
        .doc(widget.friendId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data()?['isTyping'] == true) {
        setState(() {
          _isTyping = true;
        });
      } else {
        setState(() {
          _isTyping = false;
        });
      }
    });
  }

  void _startTyping() {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('typing')
        .doc(user!.uid)
        .set({'isTyping': true});
  }

  void _stopTyping() {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('typing')
        .doc(user!.uid)
        .set({'isTyping': false});
  }

  void _onTextChanged(String value) {
    _startTyping();
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _stopTyping();
    });
  }

  Future<void> _resetUnreadCountOnOpen() async {
    try {
      // Reset unread count for this conversation
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
        'unreadCount': 0,
        'seenBy': FieldValue.arrayUnion([user!.uid]),
      });
      
      // Mark all messages from friend as seen
      final messages = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.friendId)
          .get();
      
      for (var doc in messages.docs) {
        await doc.reference.update({
          'status': 'seen',
          'seenBy': FieldValue.arrayUnion([user!.uid]),
        });
      }
      
      // Call callback to update parent
      if (widget.onUnreadReset != null) {
        widget.onUnreadReset!();
      }
    } catch (e) {
      print('Error resetting unread count: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _stopTyping(); // Stop typing when sending message
    final msgRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();
    await msgRef.set({
      'senderId': user!.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'seenBy': [],
      'reactions': {},
    });
    // Update conversation doc for last message
    // Only increment unreadCount if the recipient hasn't seen the message
    final convoDoc = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .get();
    int newUnread = 1;
    if (convoDoc.exists) {
      final data = convoDoc.data() as Map<String, dynamic>;
      final seenBy = List<String>.from(data['seenBy'] ?? []);
      if (!seenBy.contains(widget.friendId)) {
        newUnread = (data['unreadCount'] is int ? data['unreadCount'] : 0) + 1;
      }
    }
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .set({
      'participants': [user!.uid, widget.friendId],
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': user!.uid,
      'unreadCount': newUnread,
      'seenBy': [user!.uid], // Mark as seen by sender
    }, SetOptions(merge: true));
  }

  Future<void> _addReaction(String messageId, String reaction) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions.$reaction': FieldValue.arrayUnion([user!.uid]),
    });
  }

  Future<void> _removeReaction(String messageId, String reaction) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions.$reaction': FieldValue.arrayRemove([user!.uid]),
    });
  }

  void _showReactionDialog(String messageId, Map<String, dynamic> currentReactions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('React to message'),
        content: Wrap(
          spacing: 8,
          children: ['❤️', '👍', '👎', '😂', '😮', '😢', '😡'].map((emoji) {
            final reactions = List<String>.from(currentReactions[emoji] ?? []);
            final hasReacted = reactions.contains(user!.uid);
            return InkWell(
              onTap: () {
                if (hasReacted) {
                  _removeReaction(messageId, emoji);
                } else {
                  _addReaction(messageId, emoji);
                }
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasReacted ? Colors.blue[100] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _handleDelivered(QuerySnapshot snapshot) async {
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'sent' && data['senderId'] != user!.uid) {
        print('Delivering message: ${doc.id}');
        await doc.reference.update({'status': 'delivered'});
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _sendImage(image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _sendImage(XFile imageFile) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sending image...')),
      );

      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child('${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}');
      
      final file = File(imageFile.path);
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      // Send image message
      final msgRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();
      
      await msgRef.set({
        'senderId': user!.uid,
        'type': 'image',
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'seenBy': [],
      });

      // Update conversation doc
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .set({
        'participants': [user!.uid, widget.friendId],
        'lastMessage': '📷 Image',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user!.uid,
        'unreadCount': FieldValue.increment(1),
        'seenBy': [user!.uid],
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundImage: (widget.friendPhotoUrl != null && widget.friendPhotoUrl!.isNotEmpty)
                      ? NetworkImage(widget.friendPhotoUrl!)
                      : const AssetImage('assets/logo.png') as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: UserStatusIndicator(
                    userId: widget.friendId,
                    size: 14,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.friendName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  UserStatusText(
                    userId: widget.friendId,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: \\${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Mark delivered for all received messages
                _handleDelivered(snapshot.data!);
                final messages = snapshot.data!.docs;

                // Scroll to bottom after build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && _isTyping) {
                      // Show typing indicator
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.friendName} is typing...',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final fromMe = msg['senderId'] == user!.uid;
                    final status = msg['status'] as String?;
                    final messageType = msg['type'] as String? ?? 'text';
                    final reactions = Map<String, dynamic>.from(msg['reactions'] ?? {});
                    
                    return Align(
                      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                fromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!fromMe) ...[
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: () => _showReactionDialog(messages[index].id, reactions),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: messageType == 'image' 
                                          ? _buildImageMessage(msg['imageUrl'] as String)
                                          : Text(
                                              msg['text'] as String,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: () => _showReactionDialog(messages[index].id, reactions),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7B1FA2),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: messageType == 'image'
                                          ? _buildImageMessage(msg['imageUrl'] as String)
                                          : Text(
                                              msg['text'] as String,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildStatusIcon(status),
                              ],
                            ],
                          ),
                          // Show reactions if any
                          if (reactions.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildReactionsDisplay(reactions),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Color(0xFF7B1FA2)),
                  onPressed: _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: _onTextChanged,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF7B1FA2)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String? status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.check, size: 18, color: Colors.grey);
      case 'delivered':
        return const Icon(Icons.done_all, size: 18, color: Colors.grey);
      case 'seen':
        return const Icon(Icons.done_all, size: 18, color: Color(0xFF2196F3));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImageMessage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error, color: Colors.red),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReactionsDisplay(Map<String, dynamic> reactions) {
    final reactionWidgets = <Widget>[];
    
    reactions.forEach((emoji, userIds) {
      final users = List<String>.from(userIds);
      if (users.isNotEmpty) {
        reactionWidgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                if (users.length > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${users.length}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    });
    
    return Wrap(
      spacing: 4,
      children: reactionWidgets,
    );
  }
}
