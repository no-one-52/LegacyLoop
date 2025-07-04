import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/friend_request_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
        backgroundColor: const Color(0xFF7B1FA2),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF26A69A),
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Received Requests
          StreamBuilder<QuerySnapshot>(
            stream: FriendRequestService.receivedRequests(user.uid),
            builder: (context, snapshot) {
              debugPrint('ReceivedRequests: hasData=[1m${snapshot.hasData}[0m, hasError=${snapshot.hasError}, error=${snapshot.error}, docs=${snapshot.data?.docs.length}');
              if (snapshot.hasError) {
                return Center(child: Text('Error: [31m${snapshot.error}[0m'));
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final requests = snapshot.data!.docs;
              if (requests.isEmpty) return const Center(child: Text('No received requests.'));
              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, i) {
                  final req = requests[i];
                  final data = req.data() as Map<String, dynamic>;
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(data['fromUserId']).get(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data() as Map<String, dynamic>?;
                      final nickname = userData?['nickname'] ?? data['fromUserId'];
                      final photoUrl = userData?['photoUrl'];
                      return Card(
                        color: const Color(0xFFF3E5F5),
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : const AssetImage('assets/logo.png') as ImageProvider,
                          ),
                          title: Text(nickname),
                          subtitle: Text('Status: ${data['status']}'),
                          trailing: data['status'] == 'pending'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Color(0xFF26A69A)),
                                      onPressed: () => FriendRequestService.acceptRequest(req.id),
                                      tooltip: 'Accept',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => FriendRequestService.declineRequest(req.id),
                                      tooltip: 'Decline',
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          // Sent Requests
          StreamBuilder<QuerySnapshot>(
            stream: FriendRequestService.sentRequests(user.uid),
            builder: (context, snapshot) {
              debugPrint('SentRequests: hasData=[1m${snapshot.hasData}[0m, hasError=${snapshot.hasError}, error=${snapshot.error}, docs=${snapshot.data?.docs.length}');
              if (snapshot.hasError) {
                return Center(child: Text('Error: [31m${snapshot.error}[0m'));
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final requests = snapshot.data!.docs;
              if (requests.isEmpty) return const Center(child: Text('No sent requests.'));
              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, i) {
                  final req = requests[i];
                  final data = req.data() as Map<String, dynamic>;
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(data['toUserId']).get(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data() as Map<String, dynamic>?;
                      final nickname = userData?['nickname'] ?? data['toUserId'];
                      final photoUrl = userData?['photoUrl'];
                      return Card(
                        color: const Color(0xFFE0F2F1),
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : const AssetImage('assets/logo.png') as ImageProvider,
                          ),
                          title: Text(nickname),
                          subtitle: Text('Status: ${data['status']}'),
                          trailing: data['status'] == 'pending'
                              ? IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => FriendRequestService.cancelRequest(req.id),
                                  tooltip: 'Cancel',
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
} 