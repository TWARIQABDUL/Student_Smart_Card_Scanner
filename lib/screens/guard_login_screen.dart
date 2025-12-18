import 'dart:ui';
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
  bool _obscurePassword = true; // State for password visibility

  void _login() async {
    // 1. VALIDATION: Check for empty fields first
    if (_emailController.text.trim().isEmpty || _passController.text.trim().isEmpty) {
      _showErrorDialog("Input Error", "Please enter both Guard ID and Password.");
      return;
    }

    setState(() => _isLoading = true);

    // 2. Call API
    final result = await _authService.login(
        _emailController.text.trim(),
        _passController.text.trim()
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    // 3. Handle Result
    if (result is Map && result.containsKey('token')) {
      final user = result['user'];
      final String role = user != null ? (user['role'] ?? 'UNKNOWN') : 'UNKNOWN';

      if (role == 'GUARD' || role == 'ADMIN') {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ScannerDashboard())
        );
      } else {
        _showErrorDialog(
            "Security Alert",
            "Access Denied.\n\nYou are logged in as a STUDENT, but this app is for GUARDS only."
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result is Map ? result['error'] ?? "Login Failed" : result.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
      );
    }
  }

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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF12141F), Color(0xFF000000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Ambient Glow
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.15),
                      blurRadius: 100,
                      spreadRadius: 20,
                    )
                  ],
                ),
              ),
            ),

            // Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                          ]
                      ),
                      child: const Icon(Icons.security, size: 60, color: Colors.cyanAccent),
                    ),
                    const SizedBox(height: 24),

                    Text("GUARD TERMINAL", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                    Text("Secure Access Control", style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54)),

                    const SizedBox(height: 40),

                    // Inputs Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("LOGIN", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 20),

                              // Email Input
                              _buildTextField(
                                  controller: _emailController,
                                  label: "Guard ID",
                                  icon: Icons.person_outline
                              ),

                              const SizedBox(height: 16),

                              // Password Input (With Toggle)
                              _buildTextField(
                                  controller: _passController,
                                  label: "Password",
                                  icon: Icons.lock_outline,
                                  isPassword: true
                              ),

                              const SizedBox(height: 30),

                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyanAccent,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      shadowColor: Colors.cyanAccent.withOpacity(0.5)
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)
                                  )
                                      : Text("ACTIVATE TERMINAL", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    Text("v1.0.0 • Main Entrance", style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UPDATED TEXT FIELD BUILDER ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F111A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? _obscurePassword : false, // Logic for hiding text
            style: GoogleFonts.poppins(color: Colors.white),
            cursorColor: Colors.cyanAccent,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white54),
              // Add Suffix Icon ONLY for passwords
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white30,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              hintText: "Enter $label",
              hintStyle: GoogleFonts.poppins(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }
}