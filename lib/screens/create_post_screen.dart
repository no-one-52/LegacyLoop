import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  List<File> _imageFiles = [];
  List<Uint8List> _webImageBytes = [];
  bool _isLoading = false;
  String? _error;

  Future<void> _pickImages() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _webImageBytes = result.files.where((f) => f.bytes != null).map((f) => f.bytes!).toList();
          _imageFiles = [];
        });
      }
    } else {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1200, maxHeight: 1200);
      if (picked.isNotEmpty) {
        setState(() {
          _imageFiles = picked.map((x) => File(x.path)).toList();
          _webImageBytes = [];
        });
      }
    }
  }

  Future<void> _createPost() async {
    setState(() { _isLoading = true; _error = null; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Get user info
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      List<String> imageUrls = [];
      String? imageUrl;
      if (_imageFiles.isNotEmpty || _webImageBytes.isNotEmpty) {
        final futures = <Future<String>>[];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (kIsWeb && _webImageBytes.isNotEmpty) {
          for (int i = 0; i < _webImageBytes.length; i++) {
            final ref = FirebaseStorage.instance.ref().child('post_images').child('${user.uid}_${timestamp}_$i.jpg');
            futures.add(ref.putData(_webImageBytes[i], SettableMetadata(contentType: 'image/jpeg')).then((_) => ref.getDownloadURL()));
          }
        } else if (_imageFiles.isNotEmpty) {
          for (int i = 0; i < _imageFiles.length; i++) {
            final ref = FirebaseStorage.instance.ref().child('post_images').child('${user.uid}_${timestamp}_$i.jpg');
            futures.add(ref.putFile(_imageFiles[i]).then((_) => ref.getDownloadURL()));
          }
        }
        imageUrls = await Future.wait(futures);
        if (imageUrls.isNotEmpty) {
          imageUrl = imageUrls[0]; // For backward compatibility
        }
      }
      
      // Extract hashtags from text
      final text = _textController.text.trim();
      final hashtags = _extractHashtags(text);
      
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'userNickname': userData['nickname'] ?? user.email,
        'userPhotoUrl': userData['photoUrl'],
        'text': text,
        'hashtags': hashtags, // Store hashtags separately for better search
        'imageUrls': imageUrls,
        'imageUrl': imageUrl, // For backward compatibility
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Failed to create post: $e'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Extract hashtags from text (words starting with #)
  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'#\w+');
    final matches = regex.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> imagePreviews = [];
    if (kIsWeb && _webImageBytes.isNotEmpty) {
      imagePreviews = _webImageBytes.asMap().entries.map((entry) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            Image.memory(entry.value, width: 160, height: 160, fit: BoxFit.cover),
            Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 16),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _webImageBytes.removeAt(entry.key);
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      )).toList();
    } else if (_imageFiles.isNotEmpty) {
      imagePreviews = _imageFiles.asMap().entries.map((entry) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            Image.file(entry.value, width: 160, height: 160, fit: BoxFit.cover),
            Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 16),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _imageFiles.removeAt(entry.key);
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      )).toList();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "What's on your mind?",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (imagePreviews.isNotEmpty)
              SizedBox(
                height: 170,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: imagePreviews,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8F5CF7),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.image),
                  label: const Text('Add Images'),
                  onPressed: _pickImages,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: _isLoading ? null : _createPost,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 