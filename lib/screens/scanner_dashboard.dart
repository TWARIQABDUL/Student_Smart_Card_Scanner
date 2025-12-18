import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/scanner_service.dart';
import 'qr_scanner_screen.dart';

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

  Color _bgColor = const Color(0xFF1E202C);
  Color _accentColor = Colors.cyanAccent;

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

  // --- THE REAL HARDWARE CHECK ---
  void _checkHardware() async {
    // 1. Reset UI to neutral state while checking
    setState(() {
      _bgColor = const Color(0xFF1E202C);
      _showResult = false; // Hide the Green/Red screen
      _isProcessing = false;
    });

    // 2. Ask Native Code
    int status = await _scannerService.checkNfcStatus();

    // 3. Update UI based on reality
    setState(() {
      _nfcHardwareStatus = status;
      if (status == 0) {
        _resetUI("READY TO SCAN", "Tap NFC or Scan QR", Colors.cyanAccent, Icons.wifi_tethering);
      } else {
        _resetUI("NFC OFF", "Use QR Code Scanner", Colors.orangeAccent, Icons.qr_code);
      }
    });
  }

  void _resetUI(String main, String sub, Color color, IconData icon) {
    setState(() {
      _mainStatusText = main;
      _subStatusText = sub;
      _accentColor = color;
      _centerIcon = icon;
      _bgColor = const Color(0xFF1E202C);
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
      _accentColor = Colors.cyanAccent;
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
      _accentColor = Colors.blueAccent;
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

      if (response.statusCode == 200) {
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _mainStatusText = "ACCESS GRANTED";
          _subStatusText = body['studentName'] ?? "Student";
          _centerIcon = Icons.check_circle;
          _accentColor = Colors.white;
          _bgColor = Colors.green[700]!;
        });
      } else {
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _mainStatusText = "ACCESS DENIED";
          _subStatusText = body['error'] ?? "Unknown Error";
          _centerIcon = Icons.cancel;
          _accentColor = Colors.white;
          _bgColor = Colors.red[800]!;
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
      _accentColor = Colors.white;
      _bgColor = Colors.orange[800]!;
    });
  }

  // =========================================================
  // UI BUILDER
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        color: _bgColor,
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
                      icon: const Icon(Icons.power_settings_new, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
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
                            color: _accentColor.withValues(alpha: 0.3),
                            width: 2
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: _accentColor.withValues(alpha: 0.2),
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
                      border: Border.all(color: _accentColor, width: 4),
                    ),
                    child: Center(
                      child: _isProcessing
                          ? CircularProgressIndicator(color: _accentColor, strokeWidth: 5)
                          : Icon(_centerIcon, size: 80, color: _accentColor),
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

              // 4. BOTTOM CONTROLS (Only visible if not verifying)
              if (!_isProcessing && !_showResult)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      if (_nfcHardwareStatus == 0)
                        _buildActionButton(
                            "SCAN NFC CARD",
                            Icons.wifi_tethering,
                            Colors.cyanAccent,
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

              // 5. RESET BUTTON (Fix applied here!)
              if (_showResult)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: _buildActionButton(
                      "SCAN NEXT",
                      Icons.refresh,
                      Colors.white,
                      Colors.black,
                      _checkHardware // <--- THE FIX: Re-run hardware check, don't just reset text
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