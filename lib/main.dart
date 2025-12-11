import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  String _statusMessage = "Initializing...";
  String? _scannedToken;
  String? _scanMethod;
  bool _isScanning = false;
  int _nfcHealth = -1;

  @override
  void initState() {
    super.initState();
    _checkSystemHealth();
  }

  // --- LOGIC SECTION ---

  Future<void> _checkSystemHealth() async {
    try {
      final int result = await platform.invokeMethod('checkNfcStatus');
      setState(() {
        _nfcHealth = result;
        _statusMessage = (result == 0)
            ? "System Ready"
            : (result == 1 ? "NFC is Disabled" : "No NFC Hardware Detected");
      });
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.message}";
        _nfcHealth = 2;
      });
    }
  }

  Future<void> _handleScanResult(String token, String method) async {
    await HapticFeedback.heavyImpact();
    setState(() {
      _isScanning = false;
      _scannedToken = token;
      _scanMethod = method;
      _statusMessage = "Access Granted";
    });
  }

  Future<void> _startNfcScan() async {
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
      _handleScanResult(token, "NFC");
    } on PlatformException catch (e) {
      await HapticFeedback.vibrate();
      setState(() {
        _isScanning = false;
        _statusMessage = "NFC Scan Failed: ${e.message}";
      });
    }
  }

  Future<void> _startQrScan() async {
    final String? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfessionalQrScanner()),
    );

    if (result != null) {
      _handleScanResult(result, "QR");
    }
  }

  void _resetScan() {
    setState(() {
      _scannedToken = null;
      _scanMethod = null;
      _statusMessage = "System Ready";
    });
  }

  // --- UI BUILDER SECTION ---

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
    return Container(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 30)],
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 40, backgroundColor: Colors.green,
            child: Icon(Icons.check, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 20),
          Text(
            "VALID STUDENT ID",
            style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(height: 40),
          Text(
            _scannedToken ?? "",
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "Verified via $_scanMethod",
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
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
//   PROFESSIONAL QR SCANNER (Filtered + Reliable)
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

    // Setup Laser Line Animation
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _lineAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _lineController,
      curve: Curves.easeInOut,
    ));
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
          // 1. Calculate the exact "Visual" rectangle
          final double scanSize = 280;
          final Rect scanWindow = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
            width: scanSize,
            height: scanSize,
          );

          return Stack(
            children: [
              // 2. Camera Layer (Full Screen for Reliability)
              MobileScanner(
                controller: controller,
                // NO 'scanWindow' passed here to ensure scanning works on all phones
                errorBuilder: (context, error, /* no child */) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        Text(
                          "Camera Error: ${error.errorCode}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
                onDetect: (capture) async {
                  if (_isLockedOn) return; // Prevent multiple scans

                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final String? rawValue = barcode.rawValue;

                    // --- SECURITY CHECK ---
                    // Only accept codes that look like our Student Token
                    if (rawValue != null && rawValue.startsWith("STUDENT-ID")) {

                      setState(() {
                        _isLockedOn = true; // Lock the UI
                      });

                      // Haptic Feedback
                      await HapticFeedback.selectionClick();

                      // Wait 3 Seconds (Simulate Verification)
                      await Future.delayed(const Duration(seconds: 3));

                      if (!mounted) return;

                      // Finish
                      controller.stop();
                      Navigator.pop(context, rawValue);
                      break;
                    }
                    // Else: Do nothing. Ignore the random QR code.
                  }
                },
              ),

              // 3. Dark Overlay & Borders (Visual Only - Guides the User)
              CustomPaint(
                painter: ScannerOverlayPainter(
                  scanWindow: scanWindow,
                  // Color changes to Amber when processing
                  borderColor: _isLockedOn ? Colors.amber : const Color(0xFF00FF88),
                  borderRadius: 12,
                  borderLength: 30,
                  borderWidth: 5,
                ),
                child: Container(),
              ),

              // 4. Animated Laser Line (Only when NOT locked)
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
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00FF88).withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              // 5. Spinner (Only WHEN locked)
              if (_isLockedOn)
                Positioned.fromRect(
                  rect: scanWindow,
                  child: const Center(
                    child: SizedBox(
                      width: 60, height: 60,
                      child: CircularProgressIndicator(
                        color: Colors.amber,
                        strokeWidth: 5,
                      ),
                    ),
                  ),
                ),

              // 6. Top Bar (Close Button)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ),

              // 7. Bottom Controls
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
                            style: TextStyle(
                                color: _isLockedOn ? Colors.black : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Flash Button (Hide when locked)
                        if (!_isLockedOn)
                          ValueListenableBuilder(
                            valueListenable: controller,
                            builder: (context, state, child) {
                              bool isFlashOn = state.torchState == TorchState.on;
                              return GestureDetector(
                                onTap: () => controller.toggleTorch(),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: isFlashOn ? Colors.white : Colors.black54,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    isFlashOn ? Icons.flash_on : Icons.flash_off,
                                    color: isFlashOn ? Colors.black : Colors.white,
                                    size: 30,
                                  ),
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

  ScannerOverlayPainter({
    required this.scanWindow,
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Semi-Transparent Background Overlay
    final Paint overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);

    // Create a path for the whole screen
    Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create a path for the cutout (based on scanWindow)
    Path cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          scanWindow,
          Radius.circular(borderRadius),
        ),
      );

    // Subtract cutout from background
    final Path finalOverlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(finalOverlayPath, overlayPaint);

    // 2. Draw Corner Borders (Based on scanWindow coordinates)
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final double left = scanWindow.left;
    final double top = scanWindow.top;
    final double right = scanWindow.right;
    final double bottom = scanWindow.bottom;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + borderLength)
        ..lineTo(left, top)
        ..lineTo(left + borderLength, top),
      borderPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(right - borderLength, top)
        ..lineTo(right, top)
        ..lineTo(right, top + borderLength),
      borderPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(right, bottom - borderLength)
        ..lineTo(right, bottom)
        ..lineTo(right - borderLength, bottom),
      borderPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(left + borderLength, bottom)
        ..lineTo(left, bottom)
        ..lineTo(left, bottom - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}