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

  // ⚠️ YOUR RENDER URL
  static const String baseUrl = 'https://student-smart-card-backend.onrender.com/api/v1';

  // --- UI STATE ---
  String _status = "CHECKING HARDWARE...";
  Color _statusColor = Colors.grey;
  Color _bgColor = const Color(0xFF12141F);

  bool _isProcessing = false;      // True = Show Loading Spinner
  bool _showResult = false;        // True = Show Big Check/X (Success/Fail)
  IconData _resultIcon = Icons.check_circle; // The icon to show for result

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

  void _checkHardware() async {
    int status = await _scannerService.checkNfcStatus();
    setState(() {
      _nfcHardwareStatus = status;
      if (status == 0) {
        _status = "READY TO SCAN";
        _statusColor = Colors.white;
      } else {
        _status = "NFC UNAVAILABLE\nUse QR Scan";
        _statusColor = Colors.orangeAccent;
      }
    });
  }

  // =========================================================
  // 1. TRIGGER: NFC
  // =========================================================
  void _startNfcScan() async {
    if (_nfcHardwareStatus != 0) return;

    setState(() {
      _isProcessing = true;
      _showResult = false; // Hide previous result
      _status = "HOLD CARD NEAR PHONE...";
      _statusColor = Colors.cyanAccent;
      _bgColor = const Color(0xFF12141F);
    });

    try {
      String nfcToken = await _scannerService.startScan();
      _verifyTokenOnBackend(nfcToken);
    } catch (e) {
      _showError("NFC Scan Failed");
    }
  }

  // =========================================================
  // 2. TRIGGER: QR CODE
  // =========================================================
  void _startQrScan() async {
    final String? qrCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (qrCode != null) {
      // Immediate feedback before backend call
      setState(() {
        _isProcessing = true;
        _showResult = false;
        _bgColor = const Color(0xFF12141F);
      });
      _verifyTokenOnBackend(qrCode);
    }
  }

  // =========================================================
  // 3. COMMON BACKEND LOGIC (The Brain)
  // =========================================================
  void _verifyTokenOnBackend(String token) async {
    setState(() {
      _isProcessing = true;
      _status = "VERIFYING ID..."; // Updated text
      _statusColor = Colors.cyanAccent;
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
      ).timeout(const Duration(seconds: 10)); // Added Timeout Safety

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // ✅ ACCESS GRANTED
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _resultIcon = Icons.check_circle_outline; // Big Check
          _status = "ACCESS GRANTED\n${body['studentName']}";
          _statusColor = Colors.white;
          _bgColor = Colors.green[700]!;
        });
      } else {
        // ❌ ACCESS DENIED
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _resultIcon = Icons.cancel_outlined; // Big X
          _status = "DENIED\n${body['error'] ?? 'Unknown Error'}";
          _statusColor = Colors.white;
          _bgColor = Colors.red[800]!;
        });
      }
    } catch (e) {
      _showError("Connection Error: $e");
    }
  }

  void _showError(String message) {
    setState(() {
      _isProcessing = false;
      _showResult = true;
      _resultIcon = Icons.error_outline;
      _status = message;
      _statusColor = Colors.orange;
      _bgColor = const Color(0xFF12141F);
    });
  }

  // =========================================================
  // UI BUILDER
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text("Main Gate", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.exit_to_app), onPressed: () => Navigator.pop(context))
        ],
      ),
      // 1. Force Body to take Full Width/Height for centering
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // 2. Horizontal Center
            children: [

              // --- 1. THE STATUS INDICATOR ---
              // Case A: Loading (Spinner)
              if (_isProcessing)
                const SizedBox(
                  height: 100,
                  width: 100,
                  child: CircularProgressIndicator(
                    color: Colors.cyanAccent,
                    strokeWidth: 8,
                  ),
                )
              // Case B: Result (Check/X)
              else if (_showResult)
                Icon(_resultIcon, size: 120, color: _statusColor)
              // Case C: Idle (NFC/QR Icon)
              else
                Icon(
                    _nfcHardwareStatus == 0 ? Icons.nfc : Icons.qr_code,
                    size: 100,
                    color: _statusColor
                ),

              const SizedBox(height: 30),

              // --- 2. STATUS TEXT ---
              Text(
                _status,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: _statusColor, fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 60),

              // --- 3. BUTTONS (Only show when NOT processing) ---
              if (!_isProcessing) ...[
                // OPTION A: NFC
                if (_nfcHardwareStatus == 0)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _startNfcScan,
                      icon: const Icon(Icons.wifi_tethering),
                      label: Text("SCAN NFC", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                    ),
                  ),

                if (_nfcHardwareStatus == 0) const SizedBox(height: 20),

                // OPTION B: QR
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _startQrScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text("SCAN QR CODE", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _nfcHardwareStatus == 0 ? Colors.white10 : Colors.white,
                        foregroundColor: _nfcHardwareStatus == 0 ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}