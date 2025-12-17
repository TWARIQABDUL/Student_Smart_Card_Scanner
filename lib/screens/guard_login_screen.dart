import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'scanner_dashboard.dart';

class GuardLoginScreen extends StatefulWidget {
  const GuardLoginScreen({super.key});

  @override
  State<GuardLoginScreen> createState() => _GuardLoginScreenState();
}

class _GuardLoginScreenState extends State<GuardLoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);

    // 1. Call Login API
    final result = await _authService.login(
        _emailController.text.trim(),
        _passController.text.trim()
    );

    // Check if widget is still on screen
    if (!mounted) return;

    setState(() => _isLoading = false);

    // 2. Handle Result
    if (result is Map && result.containsKey('token')) {

      // 🔒 SECURITY CHECK: Verify Role
      // We look into the 'user' object returned by the backend
      final user = result['user'];
      final String role = user != null ? (user['role'] ?? 'UNKNOWN') : 'UNKNOWN';

      print("Login Attempt Role: $role"); // Debugging

      if (role == 'GUARD' || role == 'ADMIN') {
        // ✅ ALLOW ACCESS
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ScannerDashboard())
        );
      } else {
        // ⛔ BLOCK ACCESS (Student trying to log in)
        _showErrorDialog(
            "Security Alert",
            "Access Denied.\n\nYou are logged in as a STUDENT, but this app is for GUARDS only."
        );
      }

    } else {
      // ❌ Login Failed (Wrong Password/Network)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result is Map ? result['error'] ?? "Login Failed" : result.toString()),
            backgroundColor: Colors.redAccent,
          )
      );
    }
  }

  // --- Helper: Nice Error Popup ---
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            child: Text("OK", style: GoogleFonts.poppins(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              Text(
                "GUARD TERMINAL",
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white
                ),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Guard ID",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                  )
                      : const Text("ACTIVATE TERMINAL", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}