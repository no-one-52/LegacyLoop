import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../services/user_status_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _collegeController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  File? _profileImage;
  Uint8List? _webImageBytes;

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _webImageBytes = result.files.single.bytes;
          _profileImage = null;
        });
      }
    } else {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _profileImage = File(picked.path);
          _webImageBytes = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _schoolController.dispose();
    _collegeController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarProvider;
    if (_webImageBytes != null) {
      avatarProvider = MemoryImage(_webImageBytes!);
    } else if (_profileImage != null) {
      avatarProvider = FileImage(_profileImage!);
    } else {
      avatarProvider = null;
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF8F5CF7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 12),
                Text(
                  'LegacyLoop',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: avatarProvider,
                            child: (_webImageBytes == null && _profileImage == null)
                                ? const Icon(Icons.camera_alt, size: 32, color: Colors.grey)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nicknameController,
                          decoration: const InputDecoration(
                            labelText: 'Nickname',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _bioController,
                          decoration: const InputDecoration(
                            labelText: 'Bio (Optional)',
                            prefixIcon: Icon(Icons.info_outline),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _schoolController,
                          decoration: const InputDecoration(
                            labelText: 'School (Optional)',
                            prefixIcon: Icon(Icons.school),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _collegeController,
                          decoration: const InputDecoration(
                            labelText: 'College (Optional)',
                            prefixIcon: Icon(Icons.school),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _universityController,
                          decoration: const InputDecoration(
                            labelText: 'University (Optional)',
                            prefixIcon: Icon(Icons.account_balance),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_rounded),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_rounded),
                          ),
                          obscureText: true,
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
                              backgroundColor: const Color(0xFF8F5CF7),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() {
                                      _isLoading = true;
                                      _error = null;
                                    });
                                    try {
                                      // 1. Create user in Firebase Auth
                                      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                        email: _emailController.text.trim(),
                                        password: _passwordController.text.trim(),
                                      );
                                      final user = userCredential.user;
                                      if (user == null) throw Exception('User creation failed');

                                      // 2. Upload profile image if selected
                                      String? photoUrl;
                                      if (_profileImage != null || _webImageBytes != null) {
                                        final ref = FirebaseStorage.instance
                                            .ref()
                                            .child('profile_photos')
                                            .child('${user.uid}.jpg');
                                        if (kIsWeb && _webImageBytes != null) {
                                          await ref.putData(_webImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
                                        } else if (_profileImage != null) {
                                          await ref.putFile(_profileImage!);
                                        }
                                        photoUrl = await ref.getDownloadURL();
                                      }

                                      // 3. Save user info to Firestore
                                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                        'email': _emailController.text.trim(),
                                        'nickname': _nicknameController.text.trim(),
                                        'bio': _bioController.text.trim(),
                                        'school': _schoolController.text.trim(),
                                        'college': _collegeController.text.trim(),
                                        'university': _universityController.text.trim(),
                                        'photoUrl': photoUrl,
                                        'createdAt': FieldValue.serverTimestamp(),
                                      });

                                      // 4. Initialize user status service
                                      await UserStatusService().initialize();

                                      if (!mounted) return;
                                      Navigator.pushReplacementNamed(context, '/home');
                                    } on FirebaseAuthException catch (e) {
                                      setState(() {
                                        _error = e.message;
                                      });
                                    } catch (e) {
                                      setState(() {
                                        _error = 'An error occurred. Please try again. $e';
                                      });
                                    } finally {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  },
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                  )
                                : const Text('Sign Up'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text(
                            'Already have an account? Login',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 