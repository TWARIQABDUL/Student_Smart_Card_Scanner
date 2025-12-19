import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class ThemeManager with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  // --- DEFAULT THEME (Blue / Tech Univ) ---
  Color _primaryColor = const Color(0xFF3D5CFF);
  Color _secondaryColor = const Color(0xFF2B45B5);
  Color _backgroundColor = const Color(0xFF0F111A);
  Color _cardTextColor = Colors.white;

  // Getters
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  Color get backgroundColor => _backgroundColor;
  Color get cardTextColor => _cardTextColor;

  // Keys
  static const String KEY_PRIMARY = 'theme_primary';
  static const String KEY_SECONDARY = 'theme_secondary';
  static const String KEY_BG = 'theme_bg';
  static const String KEY_TEXT = 'theme_text';

  // 🔄 1. LOAD SAVED THEME (Call in main.dart)
  Future<void> loadTheme() async {
    String? p = await _storage.read(key: KEY_PRIMARY);
    String? s = await _storage.read(key: KEY_SECONDARY);
    String? b = await _storage.read(key: KEY_BG);
    String? t = await _storage.read(key: KEY_TEXT);

    if (p != null && s != null && b != null && t != null) {
      _primaryColor = Color(int.parse(p));
      _secondaryColor = Color(int.parse(s));
      _backgroundColor = Color(int.parse(b));
      _cardTextColor = Color(int.parse(t));
      notifyListeners();
    }
  }

  // 🎨 2. UPDATE THEME FROM USER (Call after Login)
  Future<void> updateTheme(User user) async {
    if (user.campus != null) {
      // Update State
      _primaryColor = _hexToColor(user.campus!.primaryColor);
      _secondaryColor = _hexToColor(user.campus!.secondaryColor);
      _backgroundColor = _hexToColor(user.campus!.backgroundColor);
      _cardTextColor = _hexToColor(user.campus!.cardTextColor);
      notifyListeners();

      // Save to Storage
      await _storage.write(key: KEY_PRIMARY, value: _primaryColor.value.toString());
      await _storage.write(key: KEY_SECONDARY, value: _secondaryColor.value.toString());
      await _storage.write(key: KEY_BG, value: _backgroundColor.value.toString());
      await _storage.write(key: KEY_TEXT, value: _cardTextColor.value.toString());
    }
  }

  // 🧹 3. RESET (On Logout)
  Future<void> resetTheme() async {
    _primaryColor = const Color(0xFF3D5CFF);
    _secondaryColor = const Color(0xFF2B45B5);
    _backgroundColor = const Color(0xFF0F111A);
    _cardTextColor = Colors.white;
    notifyListeners();
    await _storage.deleteAll();
  }

  // Helper
  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}