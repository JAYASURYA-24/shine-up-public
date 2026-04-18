import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_config.dart';

class AuthRepository {
  String get baseUrl => ApiConfig.baseUrl;

  Future<bool> sendOTP(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyOTPDemo({
    required String phone,
    required String otp,
    String name = '',
    String email = '',
    String location = '',
  }) async {
    debugPrint('Attempting Demo OTP Verify for $phone at $baseUrl...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp-demo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
          'name': name,
          'email': email,
          'location': location,
          'role': 'PARTNER',
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('VerifyOTP Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('VerifyOTP error: $e');
      return false;
    }
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
