import 'package:firebase_core/firebase_core.dart';

class AppCheckService {
  static Future<void> initialize() async {
    try {
      // Initialize App Check if needed
      // This will reduce the App Check warnings in logs
      await Firebase.initializeApp();
    } catch (e) {
      // App Check is optional, so we can ignore errors
      print('App Check initialization skipped: $e');
    }
  }
} 