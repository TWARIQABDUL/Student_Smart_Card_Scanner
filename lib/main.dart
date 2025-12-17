import 'package:flutter/material.dart';
import 'screens/guard_login_screen.dart'; // Import the screen

void main() {
  runApp(const GuardApp());
}

class GuardApp extends StatelessWidget {
  const GuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Guard Scanner',
      theme: ThemeData.dark(),
      home: const GuardLoginScreen(), // Start here
    );
  }
}