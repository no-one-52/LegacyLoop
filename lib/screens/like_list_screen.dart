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
                );
              } else {
                return const SizedBox.shrink();
                }
            },
          );
        },
      ),
    );
  }
} 