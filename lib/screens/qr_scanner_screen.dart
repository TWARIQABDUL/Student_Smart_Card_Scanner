import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
    formats: [BarcodeFormat.qrCode],
  );

  late AnimationController _animationController;
  bool _isScanned = false;

  // Delay State
  bool _canScan = false;
  String _instructionText = "Aligning camera...";

  @override
  void initState() {
    super.initState();

    // Laser Animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 3-Second Delay Timer
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _canScan = true;
          _instructionText = "Align code within the frame";
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_canScan || _isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() => _isScanned = true);
        HapticFeedback.lightImpact();
        Navigator.pop(context, code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 70% of screen width
    final double scanWindowSize = MediaQuery.of(context).size.width * 0.7;
    // Calculate the precise rectangle for the scanner hole
    final double centerOffset = (MediaQuery.of(context).size.height - scanWindowSize) / 2;
    final Rect scanWindowRect = Rect.fromLTWH(
      (MediaQuery.of(context).size.width - scanWindowSize) / 2,
      centerOffset,
      scanWindowSize,
      scanWindowSize,
    );

    return Scaffold(
      backgroundColor: Colors.black, // Fallback color
      body: Stack(
        children: [
          // --- LAYER 1: CAMERA (Bottom Layer) ---
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),

          // --- LAYER 2: DARK OVERLAY (Custom Painter) ---
          // This replaces ColorFiltered to fix the "Black Screen" bug
          CustomPaint(
            painter: ScannerOverlayPainter(scanWindow: scanWindowRect),
            child: Container(),
          ),

          // --- LAYER 3: RED LASER ANIMATION ---
          // Positioned exactly over the hole
          Positioned(
            top: centerOffset,
            left: (MediaQuery.of(context).size.width - scanWindowSize) / 2,
            child: Container(
              height: scanWindowSize,
              width: scanWindowSize,
              decoration: BoxDecoration(
                border: Border.all(
                    color: _canScan ? Colors.white54 : Colors.red.withOpacity(0.5),
                    width: 2
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _canScan
                    ? AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Positioned(
                          top: _animationController.value * (scanWindowSize - 2),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              boxShadow: [
                                BoxShadow(color: Colors.red, blurRadius: 10, spreadRadius: 1)
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                )
                    : const Center(
                  child: CircularProgressIndicator(color: Colors.white30),
                ),
              ),
            ),
          ),

          // --- LAYER 4: TOP UI ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    "Scan QR Code",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: [const BoxShadow(color: Colors.black, blurRadius: 10)]
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- LAYER 5: BOTTOM UI ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _instructionText,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, state, child) {
                      final isFlashOn = state.torchState == TorchState.on;

                      return IconButton(
                        iconSize: 50,
                        color: isFlashOn ? Colors.yellowAccent : Colors.white54,
                        icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
                        onPressed: () => controller.toggleTorch(),
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- CUSTOM PAINTER CLASS ---
// This draws a dark layer with a transparent hole in the middle.
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  ScannerOverlayPainter({required this.scanWindow, this.borderRadius = 20});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Create a Path for the whole screen
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 2. Create a Path for the hole (rounded rectangle)
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)));

    // 3. Subtract the hole from the background
    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    // 4. Draw the result with 87% opacity black
    final backgroundPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    canvas.drawPath(backgroundWithCutout, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}