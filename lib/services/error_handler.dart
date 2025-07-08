import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class ErrorHandler {
  static void initialize() {
    // Handle Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    // Handle platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      print('Platform error: $error');
      return true;
    };
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
} 