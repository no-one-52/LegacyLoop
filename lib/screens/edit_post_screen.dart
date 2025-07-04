import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class EditPostScreen extends StatefulWidget {
  final DocumentSnapshot post;
  
  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _textController = TextEditingController();
  final List<File> _imageFiles = [];
  final List<Uint8List> _webImageBytes = [];
  final List<String> _existingImages = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  void _loadPostData() {
    final data = widget.post.data() as Map<String, dynamic>;
    _textController.text = data['text'] ?? '';
    
    // Load existing images
    final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];
    final imageUrl = data['imageUrl'];
    
    if (imageUrls.isNotEmpty) {
      _existingImages.addAll(imageUrls);
    } else if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      _existingImages.add(imageUrl);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        if (kIsWeb) {
          // Handle web images
          for (var image in images) {
            image.readAsBytes().then((bytes) {
              setState(() {
                _webImageBytes.add(bytes);
              });
            });
          }
        } else {
          // Handle mobile images
          for (var image in images) {
            _imageFiles.add(File(image.path));
          }
        }
      });
    }
  }

  Future<void> _removeExistingImage(int index) async {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  Future<void> _updatePost() async {
    if (_textController.text.trim().isEmpty && _existingImages.isEmpty && _imageFiles.isEmpty && _webImageBytes.isEmpty) {
      setState(() => _error = 'Post cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<String> finalImageUrls = [];
      
      // Keep existing images
      finalImageUrls.addAll(_existingImages);
      
      // Upload new images
      if (kIsWeb && _webImageBytes.isNotEmpty) {
        for (int i = 0; i < _webImageBytes.length; i++) {
          final fileName = 'post_images/${widget.post.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final ref = FirebaseStorage.instance.ref().child(fileName);
          await ref.putData(_webImageBytes[i]);
          final url = await ref.getDownloadURL();
          finalImageUrls.add(url);
        }
      } else if (_imageFiles.isNotEmpty) {
        for (int i = 0; i < _imageFiles.length; i++) {
          final fileName = 'post_images/${widget.post.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final ref = FirebaseStorage.instance.ref().child(fileName);
          await ref.putFile(_imageFiles[i]);
          final url = await ref.getDownloadURL();
          finalImageUrls.add(url);
        }
      }

      // Update the post
      await widget.post.reference.update({
        'text': _textController.text.trim(),
        'imageUrls': finalImageUrls,
        'imageUrl': finalImageUrls.isNotEmpty ? finalImageUrls.first : null,
        'editedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isLoading = false);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to update post: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> imagePreviews = [];
    
    // Existing images
    imagePreviews.addAll(_existingImages.asMap().entries.map((entry) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Image.network(entry.value, width: 160, height: 160, fit: BoxFit.cover),
          Positioned(
            top: 4,
            right: 4,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 16),
                padding: EdgeInsets.zero,
                onPressed: () => _removeExistingImage(entry.key),
              ),
            ),
          ),
        ],
      ),
    )));
    
    // New images
    if (kIsWeb && _webImageBytes.isNotEmpty) {
      imagePreviews.addAll(_webImageBytes.asMap().entries.map((entry) => Padding(
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
      )));
    } else if (_imageFiles.isNotEmpty) {
      imagePreviews.addAll(_imageFiles.asMap().entries.map((entry) => Padding(
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
      )));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _updatePost,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
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
            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Updating post...'),
            ],
          ],
        ),
      ),
    );
  }
} 