import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart'; // 👈 Import Provider
import '../services/scanner_service.dart';
import '../services/theme_manager.dart'; // 👈 Import Theme Manager
import 'qr_scanner_screen.dart';
import 'guard_login_screen.dart'; // For Logout

class ScannerDashboard extends StatefulWidget {
  const ScannerDashboard({super.key});

  @override
  State<ScannerDashboard> createState() => _ScannerDashboardState();
}

class _ScannerDashboardState extends State<ScannerDashboard> with WidgetsBindingObserver {
  final ScannerService _scannerService = ScannerService();
  final _storage = const FlutterSecureStorage();

  // ⚠️ YOUR SERVER URL
  static const String baseUrl = 'https://student-smart-card-backend.onrender.com/api/v1';

  // --- UI STATE ---
  String _mainStatusText = "Checking...";
  String _subStatusText = "Initializing sensors";

  // ✅ STATUS OVERRIDES (Null means "Use Campus Theme")
  Color? _statusBgColor;
  Color? _statusAccentColor;

  bool _isProcessing = false;
  bool _showResult = false;
  IconData _centerIcon = Icons.wifi_tethering;

  int _nfcHardwareStatus = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkHardware();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerService.stopScan();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkHardware();
  }

  // --- HARDWARE CHECK ---
  void _checkHardware() async {
    setState(() {
      _statusBgColor = null; // 👈 Reset to Campus Theme
      _showResult = false;
      _isProcessing = false;
    });

    int status = await _scannerService.checkNfcStatus();

    if (!mounted) return;

    setState(() {
      _nfcHardwareStatus = status;
      if (status == 0) {
        _resetUI("READY TO SCAN", "Tap NFC or Scan QR", Icons.wifi_tethering);
      } else {
        _resetUI("NFC OFF", "Use QR Code Scanner", Icons.qr_code);
      }
    });
  }

  void _resetUI(String main, String sub, IconData icon) {
    setState(() {
      _mainStatusText = main;
      _subStatusText = sub;
      _centerIcon = icon;
      _statusBgColor = null; // 👈 Reset to Campus Theme
      _statusAccentColor = null;
      _isProcessing = false;
      _showResult = false;
    });
  }

  // =========================================================
  // LOGIC
  // =========================================================

  void _startNfcScan() async {
    if (_nfcHardwareStatus != 0) return;

    setState(() {
      _isProcessing = true;
      _mainStatusText = "Reading Card...";
      _subStatusText = "Hold steady";
    });

    try {
      String nfcToken = await _scannerService.startScan();
      _verifyTokenOnBackend(nfcToken);
    } catch (e) {
      _showError("Scan Failed");
    }
  }

  void _startQrScan() async {
    final String? qrCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (qrCode != null) {
      _verifyTokenOnBackend(qrCode);
    }
  }

  void _verifyTokenOnBackend(String token) async {
    setState(() {
      _isProcessing = true;
      _mainStatusText = "Verifying ID...";
      _subStatusText = "Checking database";
    });

    try {
      String? guardToken = await _storage.read(key: 'jwt_token');
      if (guardToken == null) throw Exception("Guard not logged in");

      final response = await http.post(
        Uri.parse('$baseUrl/gate/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $guardToken'
        },
        body: jsonEncode({
          'nfcToken': token,
          'gateId': "MAIN_ENTRANCE"
        }),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);
      print("Response Body: $body");

      // 🚀 LOGIC FIX: Check HTTP Status AND the 'status' field in JSON
      if (response.statusCode == 200) {

        if (body['status'] == 'ALLOWED') {
          // --- CASE 1: ALLOWED ---
          setState(() {
            _isProcessing = false;
            _showResult = true;
            _mainStatusText = "ACCESS GRANTED";
            _subStatusText = body['studentName'] ?? "Student";
            _centerIcon = Icons.check_circle;

            // 🟢 Green Flash
            _statusBgColor = Colors.green[700];
            _statusAccentColor = Colors.white;
          });
        } else {
          // --- CASE 2: DENIED (Backend logic) ---
          setState(() {
            _isProcessing = false;
            _showResult = true;
            _mainStatusText = "ACCESS DENIED";
            _subStatusText = body['message'] ?? "Restricted Access";
            _centerIcon = Icons.cancel;

            // 🔴 Red Flash
            _statusBgColor = Colors.red[800];
            _statusAccentColor = Colors.white;
          });
        }

      } else {
        // --- CASE 3: SERVER ERROR ---
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _mainStatusText = "SYSTEM ERROR";
          _subStatusText = body['error'] ?? "Code: ${response.statusCode}";
          _centerIcon = Icons.error_outline;

          // 🟠 Orange Flash
          _statusBgColor = Colors.orange[800];
          _statusAccentColor = Colors.white;
        });
      }
    } catch (e) {
      _showError("Connection Error");
    }
  }

  void _showError(String message) {
    setState(() {
      _isProcessing = false;
      _showResult = true;
      _mainStatusText = "ERROR";
      _subStatusText = message;
      _centerIcon = Icons.warning_amber_rounded;

      _statusBgColor = Colors.orange[800];
      _statusAccentColor = Colors.white;
    });
  }

  // =========================================================
  // UI BUILDER
  // =========================================================
  @override
  Widget build(BuildContext context) {
    // 🎨 1. LISTEN TO THEME
    final theme = Provider.of<ThemeManager>(context);

    // 🎨 2. DETERMINE ACTIVE COLORS
    // If we have a result (Green/Red), use it.
    // Otherwise, use the SaaS Campus Colors.
    final currentBg = _statusBgColor ?? theme.backgroundColor;
    final currentAccent = _statusAccentColor ?? theme.primaryColor;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        color: currentBg, // 👈 Dynamic Background
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              // 1. TOP BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("GUARD TERMINAL", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
                        Text("Main Entrance", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white54),
                      onPressed: () {
                        // 🚪 LOGOUT
                        Provider.of<ThemeManager>(context, listen: false).resetTheme();
                        Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const GuardLoginScreen()),
                                (route) => false
                        );
                      },
                    )
                  ],
                ),
              ),

              const Spacer(),

              // 2. CENTER SCANNER RING
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 280,
                    width: 280,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: currentAccent.withOpacity(0.3), // 👈 Dynamic
                            width: 2
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: currentAccent.withOpacity(0.2), // 👈 Dynamic
                              blurRadius: 40,
                              spreadRadius: 5
                          )
                        ]
                    ),
                  ),

                  Container(
                    height: 220,
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                      border: Border.all(color: currentAccent, width: 4), // 👈 Dynamic
                    ),
                    child: Center(
                      child: _isProcessing
                          ? CircularProgressIndicator(color: currentAccent, strokeWidth: 5)
                          : Icon(_centerIcon, size: 80, color: currentAccent),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 3. STATUS TEXT
              Text(
                _mainStatusText.toUpperCase(),
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20)
                ),
                child: Text(
                  _subStatusText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                ),
              ),

              const Spacer(),

              // 4. BOTTOM CONTROLS
              if (!_isProcessing && !_showResult)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      if (_nfcHardwareStatus == 0)
                        _buildActionButton(
                            "SCAN NFC CARD",
                            Icons.wifi_tethering,
                            currentAccent, // 👈 Dynamic
                            Colors.black,
                            _startNfcScan
                        ),

                      const SizedBox(height: 15),

                      _buildActionButton(
                          "SCAN QR CODE",
                          Icons.qr_code_scanner,
                          Colors.transparent,
                          Colors.white,
                          _startQrScan,
                          isOutlined: true
                      ),
                    ],
                  ),
                ),

              // 5. RESET BUTTON
              if (_showResult)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: _buildActionButton(
                      "SCAN NEXT",
                      Icons.refresh,
                      Colors.white,
                      Colors.black,
                      _checkHardware
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color bg, Color text, VoidCallback onTap, {bool isOutlined = false}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: text),
        label: Text(label, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: text)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: isOutlined ? 0 : 5,
          side: isOutlined ? const BorderSide(color: Colors.white24, width: 2) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}