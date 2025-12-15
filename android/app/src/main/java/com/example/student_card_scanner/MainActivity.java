package com.example.student_card_scanner;

import android.os.Bundle; // Required for onCreate
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

// --- 1. APP CENTER IMPORTS ---
import com.microsoft.appcenter.AppCenter;
import com.microsoft.appcenter.analytics.Analytics;
import com.microsoft.appcenter.crashes.Crashes;

// Import NFC features from SDK
import com.example.card_emulator.StudentCardReader;
import com.example.card_emulator.StudentCardCallback;
import com.example.card_emulator.StudentCardManager;

// Import the new Scanner History Manager from SDK
import com.example.card_emulator.ScannerManager;

import java.util.List;
import java.util.Map;
import java.util.HashMap;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.student_card_scanner/nfc";
    private StudentCardReader cardReader;

    // --- 2. INITIALIZE APP CENTER ---
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Starts Analytics and Crash Reporting
        AppCenter.start(getApplication(), "162c6c44-8c80-4de3-b096-111c37170a48",
                Analytics.class, Crashes.class);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            switch (call.method) {

                                // --- 1. NFC HARDWARE CHECK ---
                                case "checkNfcStatus":
                                    int status = StudentCardManager.getNfcStatus(this);
                                    result.success(status);
                                    break;

                                // --- 2. START SCANNING ---
                                case "startScan":
                                    if (cardReader == null) {
                                        cardReader = new StudentCardReader(this);
                                    }
                                    cardReader.startScanning(new StudentCardCallback() {
                                        @Override
                                        public void onScanSuccess(String studentId) {
                                            runOnUiThread(() -> {
                                                // LOG: Successful Physical Scan
                                                Analytics.trackEvent("NFC Scan Success");

                                                result.success(studentId);
                                                cardReader.stopScanning();
                                            });
                                        }
                                        @Override
                                        public void onScanError(String errorMessage) {
                                            runOnUiThread(() -> {
                                                // LOG: Failed Scan Attempt
                                                Map<String, String> properties = new HashMap<>();
                                                properties.put("Error", errorMessage);
                                                Analytics.trackEvent("NFC Scan Error", properties);

                                                result.error("SCAN_ERROR", errorMessage, null);
                                            });
                                        }
                                    });
                                    break;

                                // --- 3. STOP SCANNING ---
                                case "stopScan":
                                    if (cardReader != null) cardReader.stopScanning();
                                    result.success("Stopped");
                                    break;

                                // --- 4. SAVE TRANSACTION ---
                                case "saveTransaction":
                                    String name = call.argument("name");
                                    String token = call.argument("token");
                                    Double amount = call.argument("amount");
                                    String statusLog = call.argument("status");

                                    if (name != null && token != null && amount != null) {
                                        ScannerManager.saveTransaction(this, name, token, amount, statusLog);

                                        // LOG: Critical Payment Event
                                        Map<String, String> properties = new HashMap<>();
                                        properties.put("Amount", String.valueOf(amount));
                                        properties.put("Status", statusLog);
                                        Analytics.trackEvent("Transaction Processed", properties);

                                        result.success(true);
                                    } else {
                                        result.error("ERROR", "Missing transaction details", null);
                                    }
                                    break;

                                // --- 5. GET HISTORY ---
                                case "getHistory":
                                    ScannerManager.getHistory(this, new ScannerManager.HistoryCallback() {
                                        @Override
                                        public void onHistoryLoaded(List<Map<String, Object>> history) {
                                            result.success(history);
                                        }
                                    });
                                    break;

                                default:
                                    result.notImplemented();
                                    break;
                            }
                        }
                );
    }
}