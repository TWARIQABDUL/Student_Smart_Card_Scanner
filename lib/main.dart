import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const StudentScannerApp());
}

class StudentScannerApp extends StatelessWidget {
  const StudentScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student ID Scanner',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const ScannerHomePage(),
    );
  }
}

class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  static const platform = MethodChannel('com.example.student_card_scanner/nfc');

  // --- CONFIGURATION ---
  final String _apiBase = "https://student-smart-card-backend.onrender.com/api";
  final double _chargeAmount = 5.00;

  String _statusMessage = "Initializing...";
  String? _scannedToken;
  String? _scanMethod;
  bool _isScanning = false;

  // LOCK: Prevents freezing if user clicks multiple times
  bool _isProcessing = false;

  int _nfcHealth = -1; // 0 = Ready, 1 = Disabled, 2 = Missing

  // Transaction Data
  String? _studentName;
  String? _transactionResult;
  double? _newBalance;

  @override
  void initState() {
    super.initState();
    _checkSystemHealth();
  }

  Future<void> _checkSystemHealth() async {
    try {
      final int result = await platform.invokeMethod('checkNfcStatus');
      setState(() {
        _nfcHealth = result;
        if (result == 0) {
          _statusMessage = "System Ready";
        } else if (result == 1) {
          _statusMessage = "NFC is Disabled";
        } else {
          _statusMessage = "No NFC Hardware";
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.message}";
        _nfcHealth = 2;
      });
    }
  }

  // --- PAYMENT LOGIC ---
  Future<void> _processTransaction(String token, String method) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isScanning = false;
      _scannedToken = token;
      _scanMethod = method;
      _statusMessage = "Verifying Student...";
      _transactionResult = null;
    });

    try {
      // 1. GET STUDENT INFO
      final infoResponse = await http.get(Uri.parse("$_apiBase/student/$token"));

      if (infoResponse.statusCode != 200) throw "Student Not Found";

      final studentData = jsonDecode(infoResponse.body);
      final String name = studentData['name'];
      final double balance = studentData['walletBalance'];

      // 2. CONFIRM DIALOG
      bool confirm = await _showConfirmDialog(name, balance);
      if (!confirm) {
        _resetScan();
        return;
      }

      setState(() => _statusMessage = "Processing Payment...");

      // 3. CHARGE
      final chargeResponse = await http.post(
        Uri.parse("$_apiBase/payment/deduct"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"nfcToken": token, "amount": _chargeAmount}),
      );

      if (chargeResponse.statusCode == 200) {
        await HapticFeedback.heavyImpact();

        // 4. SAVE TO DB (Safe Call)
        try {
          await platform.invokeMethod('saveTransaction', {
            "name": name,
            "token": token,
            "amount": _chargeAmount,
            "status": "SUCCESS"
          });
        } catch (_) {}

        setState(() {
          _studentName = name;
          _newBalance = balance - _chargeAmount;
          _transactionResult = "APPROVED";
          _statusMessage = "Transaction Complete";
          _isProcessing = false;
        });

      } else {
        throw "Payment Rejected";
      }

    } catch (e) {
      await HapticFeedback.vibrate();
      setState(() {
        _transactionResult = "DECLINED";
        _statusMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<bool> _showConfirmDialog(String name, double balance) async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Charge"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle, size: 60, color: Colors.indigo),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("Balance: \$${balance.toStringAsFixed(2)}"),
            const Divider(height: 30),
            Text("Charge: \$$_chargeAmount", style: const TextStyle(fontSize: 18, color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("CHARGE"),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _startNfcScan() async {
    if (_isProcessing) return;

    // --- FIX: Prevent scan if hardware is bad ---
    if (_nfcHealth != 0) {
      await _checkSystemHealth();
      if (_nfcHealth != 0) return;
    }

    setState(() {
      _isScanning = true;
      _scannedToken = null;
      _statusMessage = "Hold phone near Student Card...";
    });

    try {
      final String token = await platform.invokeMethod('startScan');
      _processTransaction(token, "NFC");
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = "Scan Cancelled or Failed";
      });
    }
  }

  Future<void> _startQrScan() async {
    if (_isProcessing) return;

    final String? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfessionalQrScanner()),
    );

    if (result != null) _processTransaction(result, "QR");
  }

  void _resetScan() {
    setState(() {
      _isProcessing = false;
      _scannedToken = null;
      _scanMethod = null;
      _transactionResult = null;
      _statusMessage = "System Ready";
    });
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Security Terminal"),
        centerTitle: true,
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusHeader(),
              const Spacer(),
              if (_isProcessing && _transactionResult == null)
                const Center(child: CircularProgressIndicator())
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _scannedToken != null
                      ? _buildResultCard()
                      : _buildScanningVisual(),
                ),
              const Spacer(),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    Color statusColor = (_nfcHealth == 0) ? Colors.green : Colors.orange;
    String statusText = (_nfcHealth == 0) ? "ONLINE" : "NFC OFFLINE";

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          "TERMINAL STATUS: $statusText",
          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildScanningVisual() {
    if (_isScanning) {
      return Column(
        key: const ValueKey('scanning'),
        children: [
          const SizedBox(
            height: 150, width: 150,
            child: CircularProgressIndicator(strokeWidth: 6, color: Colors.indigo),
          ),
          const SizedBox(height: 40),
          Text(
            "Reading NFC Signal...",
            style: TextStyle(fontSize: 22, color: Colors.indigo[800], fontWeight: FontWeight.w300),
          )
        ],
      );
    }
    return Column(
      key: const ValueKey('idle'),
      children: [
        Icon(Icons.security, size: 150, color: Colors.indigo[100]),
        const SizedBox(height: 20),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    bool isSuccess = _transactionResult == "APPROVED";

    return Container(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: isSuccess ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2), blurRadius: 30)],
        border: Border.all(color: isSuccess ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: isSuccess ? Colors.green : Colors.red,
            child: Icon(isSuccess ? Icons.check : Icons.close, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 20),
          Text(
            isSuccess ? "PAYMENT SUCCESSFUL" : "PAYMENT FAILED",
            style: TextStyle(color: isSuccess ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (isSuccess) ...[
            Text(_studentName ?? "", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("New Balance: \$${_newBalance?.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ] else ...[
            Text(_statusMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
          const Divider(height: 40),
          Text(
            "ID: $_scannedToken",
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_scannedToken != null) {
      return ElevatedButton.icon(
        onPressed: _resetScan,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text("SCAN NEXT STUDENT"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      );
    }

    return Column(
      children: [
        // --- FIX: BUTTON DISABLE LOGIC RESTORED ---
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            // Only enabled if NOT scanning AND NFC health is good (0)
            onPressed: (_isScanning || _nfcHealth != 0) ? null : _startNfcScan,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(_isScanning ? "LISTENING..." : "TAP TO SCAN (NFC)"),
          ),
        ),

        const SizedBox(height: 15),

        if (!_isScanning)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startQrScan,
              icon: const Icon(Icons.qr_code),
              label: const Text("SCAN QR CODE"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.indigo,
                side: const BorderSide(color: Colors.indigo, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// =======================================================
//   PROFESSIONAL QR SCANNER (RESTORED)
// =======================================================

class ProfessionalQrScanner extends StatefulWidget {
  const ProfessionalQrScanner({super.key});

  @override
  State<ProfessionalQrScanner> createState() => _ProfessionalQrScannerState();
}

class _ProfessionalQrScannerState extends State<ProfessionalQrScanner> with TickerProviderStateMixin, WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  late AnimationController _lineController;
  late Animation<double> _lineAnimation;
  bool _isLockedOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.start();

    _lineController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _lineAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _lineController, curve: Curves.easeInOut));
    _lineController.repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.stop();
    controller.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        controller.start();
        _lineController.repeat(reverse: true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.stop();
        _lineController.stop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double scanSize = 280;
          final Rect scanWindow = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
            width: scanSize,
            height: scanSize,
          );

          return Stack(
            children: [
              MobileScanner(
                controller: controller,
                errorBuilder: (context, error) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        Text("Camera Error: ${error.errorCode}", style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
                onDetect: (capture) async {
                  if (_isLockedOn) return;

                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final String? rawValue = barcode.rawValue;
                    if (rawValue != null && rawValue.startsWith("STUDENT-ID")) {
                      setState(() => _isLockedOn = true);
                      await HapticFeedback.selectionClick();
                      await Future.delayed(const Duration(seconds: 2)); // Animation delay
                      if (!mounted) return;
                      controller.stop();
                      Navigator.pop(context, rawValue);
                      break;
                    }
                  }
                },
              ),

              CustomPaint(
                painter: ScannerOverlayPainter(
                  scanWindow: scanWindow,
                  borderColor: _isLockedOn ? Colors.amber : const Color(0xFF00FF88),
                  borderRadius: 12,
                  borderLength: 30,
                  borderWidth: 5,
                ),
                child: Container(),
              ),

              if (!_isLockedOn)
                Positioned.fromRect(
                  rect: scanWindow,
                  child: AnimatedBuilder(
                    animation: _lineAnimation,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Positioned(
                            top: scanWindow.height * _lineAnimation.value,
                            left: 0, right: 0,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88),
                                boxShadow: [BoxShadow(color: const Color(0xFF00FF88).withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              if (_isLockedOn)
                Positioned.fromRect(
                  rect: scanWindow,
                  child: const Center(child: SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 5))),
                ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 50.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isLockedOn ? Colors.amber.withOpacity(0.8) : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isLockedOn ? "Verifying Security Token..." : "Align QR code within the frame",
                            style: TextStyle(color: _isLockedOn ? Colors.black : Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (!_isLockedOn)
                          ValueListenableBuilder(
                            valueListenable: controller,
                            builder: (context, state, child) {
                              bool isFlashOn = state.torchState == TorchState.on;
                              return GestureDetector(
                                onTap: () => controller.toggleTorch(),
                                child: Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(
                                    color: isFlashOn ? Colors.white : Colors.black54,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off, color: isFlashOn ? Colors.black : Colors.white, size: 30),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- VISUAL PAINTER ---
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;

  ScannerOverlayPainter({required this.scanWindow, required this.borderColor, required this.borderRadius, required this.borderLength, required this.borderWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);
    Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    Path cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)));
    final Path finalOverlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(finalOverlayPath, overlayPaint);

    final Paint borderPaint = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = borderWidth..strokeCap = StrokeCap.round;
    final double left = scanWindow.left;
    final double top = scanWindow.top;
    final double right = scanWindow.right;
    final double bottom = scanWindow.bottom;

    canvas.drawPath(Path()..moveTo(left, top + borderLength)..lineTo(left, top)..lineTo(left + borderLength, top), borderPaint);
    canvas.drawPath(Path()..moveTo(right - borderLength, top)..lineTo(right, top)..lineTo(right, top + borderLength), borderPaint);
    canvas.drawPath(Path()..moveTo(right, bottom - borderLength)..lineTo(right, bottom)..lineTo(right - borderLength, bottom), borderPaint);
    canvas.drawPath(Path()..moveTo(left + borderLength, bottom)..lineTo(left, bottom)..lineTo(left, bottom - borderLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}