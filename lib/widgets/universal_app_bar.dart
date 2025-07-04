import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/search_screen.dart';
import 'package:badges/badges.dart' as badges;
import '../screens/messages_screen.dart';

class UniversalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onMessageTap;
  final ValueChanged<String>? onSearch;
  final String? profilePhotoUrl;
  final int unreadMessagesCount;

  const UniversalAppBar({
    Key? key,
    this.onProfileTap,
    this.onMessageTap,
    this.onSearch,
    this.profilePhotoUrl,
    this.unreadMessagesCount = 0,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: GestureDetector(
        onTap: onProfileTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
                ? NetworkImage(profilePhotoUrl!)
                : const AssetImage('assets/logo.png') as ImageProvider,
          ),
        ),
      ),
      title: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              SizedBox(width: 12),
              Icon(Icons.search, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                'Search friends, posts...',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
      actions: [
        badges.Badge(
          showBadge: unreadMessagesCount > 0,
          badgeContent: Text('$unreadMessagesCount', style: TextStyle(color: Colors.white, fontSize: 10)),
          position: badges.BadgePosition.topEnd(top: 0, end: 3),
          child: IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF1877F2)),
            tooltip: 'Messages',
            onPressed: onMessageTap,
          ),
        ),
      ],
    );
  }
} 