import 'package:flutter/services.dart';

class ScannerService {
  static const platform = MethodChannel('com.example.student_card_scanner/nfc');

  Future<String> startScan() async {
    try {
      final String token = await platform.invokeMethod('startScan');
      return token;
    } on PlatformException catch (e) {
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