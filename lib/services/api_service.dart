import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // ⚠️ YOUR SERVER URL
  static const String baseUrl = 'https://student-smart-card-backend.onrender.com/api/v1';
  final _storage = const FlutterSecureStorage();

  // --- LOGIN ---
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
        return body; // Return full map to check role
      } else {
        return {'error': body['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'error': 'Connection Error'};
    }
  }

  // --- VERIFY ENTRY (GUARD CHECK) ---
  Future<Map<String, dynamic>> verifyEntry(String nfcToken) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return {'status': 'DENIED', 'message': 'Unauthorized'};

      final response = await http.post(
        Uri.parse('$baseUrl/gate/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nfcToken': nfcToken,
          'gateId': 'MAIN-GATE'
        }),
      );

      // Backend returns 200 even for DENIED, so we trust the body
      if (response.statusCode == 200 || response.statusCode == 403) {
        return jsonDecode(response.body);
      } else {
        return {
          'status': 'DENIED',
          'message': 'Server Error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'status': 'DENIED',
        'message': 'Connection Failed'
      };
    }
  }
}