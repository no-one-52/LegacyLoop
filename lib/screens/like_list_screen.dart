import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';

class LikeListScreen extends StatelessWidget {
  final List<String> userIds;
  const LikeListScreen({super.key, required this.userIds});

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Likes')),
        body: const Center(child: Text('No likes yet.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Likes')),
      body: ListView.builder(
        itemCount: userIds.length,
        itemBuilder: (context, index) {
          final userId = userIds[index];
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(title: Text('Loading...'));
              }
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final nickname = data['nickname'] ?? 'User';
              final photoUrl = data['photoUrl'];
              ImageProvider avatarProvider;
              if (photoUrl != null && photoUrl.isNotEmpty) {
                avatarProvider = NetworkImage(photoUrl);
              } else {
                avatarProvider = const AssetImage('assets/logo.png');
              }
              
              void openUserProfile() {
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
              
              return ListTile(
                leading: GestureDetector(
                  onTap: openUserProfile,
                  child: CircleAvatar(backgroundImage: avatarProvider),
                ),
                title: GestureDetector(
                  onTap: openUserProfile,
                  child: Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                onTap: openUserProfile,
              );
            },
          );
        },
      ),
    );
  }
} 