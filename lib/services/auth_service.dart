import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // ⚠️ USE YOUR IP ADDRESS
  static const String baseUrl = 'https://student-smart-card-backend.onrender.com/api/v1';
  final _storage = const FlutterSecureStorage();

  Future<dynamic> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _storage.write(key: 'jwt_token', value: body['token']);
        // Return the whole body so we can check the role
        return body;
      } else {
        return body['error'] ?? 'Login failed';
      }
    } catch (e) {
      return 'Connection error';
    }
  }
}