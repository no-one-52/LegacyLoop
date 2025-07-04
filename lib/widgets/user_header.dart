import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/profile_screen.dart';
//import '../screens/public_profile_screen.dart';

class UserHeader extends StatelessWidget {
  final String userId;
  final String userPhotoUrl;
  final String userNickname;

  const UserHeader({
    required this.userId,
    required this.userPhotoUrl,
    required this.userNickname,
    super.key,
  });

  void _openUserProfile(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && userId == currentUser.uid) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUserProfile(context),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: userPhotoUrl.isNotEmpty
                ? NetworkImage(userPhotoUrl)
                : const AssetImage('assets/logo.png') as ImageProvider,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Text(
            userNickname,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
} 