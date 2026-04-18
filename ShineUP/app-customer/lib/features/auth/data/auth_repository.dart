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

  Future<String?> verifyOTPDemo({
    required String phone,
    required String otp,
    required String name,
    required String email,
    required String location,
    double latitude = 0,
    double longitude = 0,
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
          'latitude': latitude,
          'longitude': longitude,
          'role': 'CUSTOMER',
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('VerifyOTP Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        return null; // No error
      }
      
      try {
        final errorData = jsonDecode(response.body);
        return errorData['error'] ?? 'Server error: ${response.statusCode}';
      } catch (_) {
        return 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('VerifyOTP error: $e');
      return 'Network error: $e';
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
          'role': 'CUSTOMER',
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
          'role': 'CUSTOMER',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        return true;
      } else {
        debugPrint('Login failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
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
