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
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final userId = request['fromUserId'] ?? request['userId'];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userData['photoUrl'] != null && userData['photoUrl'].isNotEmpty
                                ? NetworkImage(userData['photoUrl'])
                                : const AssetImage('assets/logo.png') as ImageProvider,
                          ),
                          title: Text(userData['nickname'] ?? 'User'),
                          subtitle: Text('Status: ${request['status']}'),
                          trailing: request['status'] == 'pending'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Color(0xFF26A69A)),
                                      onPressed: () => FriendRequestService.acceptRequest(request.id),
                                      tooltip: 'Accept',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => FriendRequestService.declineRequest(request.id),
                                      tooltip: 'Decline',
                                    ),
                                  ],
                                )
                              : null,
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
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
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final userId = request['toUserId'] ?? request['userId'];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userData['photoUrl'] != null && userData['photoUrl'].isNotEmpty
                                ? NetworkImage(userData['photoUrl'])
                                : const AssetImage('assets/logo.png') as ImageProvider,
                          ),
                          title: Text(userData['nickname'] ?? 'User'),
                          subtitle: Text('Status: ${request['status']}'),
                          trailing: request['status'] == 'pending'
                              ? IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => FriendRequestService.cancelRequest(request.id),
                                  tooltip: 'Cancel',
                                )
                              : null,
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
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