import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserSearchDialog extends StatefulWidget {
  const UserSearchDialog({super.key});

  @override
  State<UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<UserSearchDialog> {
  String _search = '';
  String? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search and Select User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search by name or email',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _search = value.trim();
              });
            },
          ),
          const SizedBox(height: 16),
          if (_search.isNotEmpty)
            SizedBox(
              height: 250,
              width: 350,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('nickname', isGreaterThanOrEqualTo: _search)
                    .where('nickname', isLessThan: _search + '\uf8ff')
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data!.docs;
                  if (users.isEmpty) {
                    return const Center(child: Text('No users found.'));
                  }
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index].data() as Map<String, dynamic>;
                      final userId = users[index].id;
                      final nickname = user['nickname'] ?? userId;
                      final email = user['email'] ?? '';
                      final photoUrl = user['photoUrl'] as String?;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(nickname),
                        subtitle: Text(email),
                        selected: _selectedUserId == userId,
                        onTap: () {
                          setState(() {
                            _selectedUserId = userId;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedUserId != null
              ? () => Navigator.pop(context, _selectedUserId)
              : null,
          child: const Text('Select'),
        ),
      ],
    );
  }
} 