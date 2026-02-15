import 'package:flutter/services.dart';

class ScannerService {
  static const platform = MethodChannel('com.example.student_card_scanner/nfc');

  Future<String> startScan() async {
    try {
      print("Starting scan...");
      final String token = await platform.invokeMethod('startScan');
      print("Scan result: $token");
      return token;
    } on PlatformException catch (e) {
      print("Scan failed: ${e.message}");
      throw e.message ?? "Scan failed";
    }
  }

  Future<void> stopScan() async {
    try {
      await platform.invokeMethod('stopScan');
    } catch (_) {}
  }
  Future<int> checkNfcStatus() async {
    try {
      final int status = await platform.invokeMethod('checkNfcStatus');
      return status; // 0: Ready, 1: Disabled, 2: Missing
    } on PlatformException catch (_) {
      return 2; // Assume missing if error
    }
  }
}