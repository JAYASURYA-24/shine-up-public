import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8080/api/v1';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8080/api/v1';
    } catch (_) {}
    return 'http://localhost:8080/api/v1'; // Default for Linux/iOS
  }

  Future<bool> devLogin(String phone) async {
    debugPrint('Attempting DevLogin for $phone at $baseUrl...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/dev-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'role': 'PARTNER',
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('DevLogin Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Dev login error: $e');
      return false;
    }
  }

  Future<bool> verifyFirebaseToken(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          'role': 'PARTNER',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        return true;
      } else {
        // ignore: avoid_print
        print('Login failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Network error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
}
