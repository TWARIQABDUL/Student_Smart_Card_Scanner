package com.example.student_card_scanner;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

// Import BOTH from your SDK
import com.example.card_emulator.StudentCardReader;
import com.example.card_emulator.StudentCardCallback;
import com.example.card_emulator.StudentCardManager; // <--- Add this

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.student_card_scanner/nfc";
    private StudentCardReader cardReader;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            switch (call.method) {
                                // REUSE 1: Check Health using the Manager
                                case "checkNfcStatus":
                                    int status = StudentCardManager.getNfcStatus(this);
                                    result.success(status);
                                    break;

                                case "startScan":
                                    if (cardReader == null) {
                                        cardReader = new StudentCardReader(this);
                                    }
                                    cardReader.startScanning(new StudentCardCallback() {
                                        @Override
                                        public void onScanSuccess(String studentId) {
                                            result.success(studentId);
                                            cardReader.stopScanning();
                                        }
                                        @Override
                                        public void onScanError(String errorMessage) {
                                            result.error("SCAN_ERROR", errorMessage, null);
                                        }
                                    });
                                    break;

                                case "stopScan":
                                    if (cardReader != null) cardReader.stopScanning();
                                    result.success("Stopped");
                                    break;

                                default:
                                    result.notImplemented();
                                    break;
                            }
                        }
                );
    }
}