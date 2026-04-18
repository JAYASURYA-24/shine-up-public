import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  String get baseUrl => 'https://shine-up-public-production.up.railway.app/api/v1';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Profile ────────────────────────────────────────
  Future<Map<String, dynamic>?> getProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/profile'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<Map<String, dynamic>?> updateProfile(String name, String docUrl) async {
    final res = await http.put(
      Uri.parse('$baseUrl/partner/profile'),
      headers: await _authHeaders(),
      body: jsonEncode({'name': name, 'doc_url': docUrl}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ─── KYC ────────────────────────────────────────────
  Future<Map<String, dynamic>?> submitKYC(Map<String, dynamic> kycData) async {
    final res = await http.put(
      Uri.parse('$baseUrl/partner/profile/kyc'),
      headers: await _authHeaders(),
      body: jsonEncode(kycData),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    debugPrint('KYC submit error: ${res.statusCode} - ${res.body}');
    return null;
  }

  // ─── Online Toggle ──────────────────────────────────
  Future<bool> toggleOnline(bool online) async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/toggle-online'),
      headers: await _authHeaders(),
      body: jsonEncode({'online': online}),
    );
    return res.statusCode == 200;
  }

  // ─── Jobs ───────────────────────────────────────────
  Future<List<dynamic>> getJobs() async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/jobs'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> acceptJob(String jobId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/jobs/$jobId/accept'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  Future<bool> startJob(String jobId, String otp) async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/jobs/$jobId/start'),
      headers: await _authHeaders(),
      body: jsonEncode({'otp': otp}),
    );
    return res.statusCode == 200;
  }

  Future<bool> completeJob(String jobId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/jobs/$jobId/complete'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  // ─── Service Photos ─────────────────────────────────
  Future<Map<String, dynamic>?> uploadPhoto(String bookingId, String photoType, String photoUrl) async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/jobs/$bookingId/photos'),
      headers: await _authHeaders(),
      body: jsonEncode({'photo_type': photoType, 'photo_url': photoUrl}),
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    return null;
  }

  Future<List<dynamic>> getPhotos(String bookingId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/jobs/$bookingId/photos'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  // ─── Slots ──────────────────────────────────────────
  Future<List<dynamic>> getSlots(String date) async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/slots?date=$date'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Map<String, dynamic>?> toggleSlot(String slotId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/partner/slots/$slotId/toggle'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ─── Leaves ─────────────────────────────────────────
  Future<Map<String, dynamic>?> requestLeave(String date, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/leaves'),
      headers: await _authHeaders(),
      body: jsonEncode({'date': date, 'reason': reason}),
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    debugPrint('Leave request error: ${res.statusCode} - ${res.body}');
    return null;
  }

  Future<List<dynamic>> getLeaves() async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/leaves'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> cancelLeave(String leaveId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/partner/leaves/$leaveId'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  // ─── Bank Account ──────────────────────────────────
  Future<Map<String, dynamic>?> getBankDetails() async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/bank'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<Map<String, dynamic>?> submitBankDetails(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/bank'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<Map<String, dynamic>?> verifyBank() async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/bank/verify'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ─── Earnings ───────────────────────────────────────
  Future<Map<String, dynamic>?> getEarnings() async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/earnings'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ─── Notifications ──────────────────────────────────
  Future<List<dynamic>> getNotificationsList() async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/notifications'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> markNotificationRead(String notifId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/partner/notifications/$notifId/read'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  Future<bool> markAllNotificationsRead() async {
    final res = await http.put(
      Uri.parse('$baseUrl/partner/notifications/read-all'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  Future<int> getUnreadNotificationCount() async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/notifications/unread-count'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['count'] ?? 0;
    }
    return 0;
  }

  // ─── Chat ──────────────────────────────────────────
  Future<Map<String, dynamic>?> sendChatMessage(String bookingId, String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/$bookingId/send'),
      headers: await _authHeaders(),
      body: jsonEncode({'message': message}),
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    return null;
  }

  Future<List<dynamic>> getChatMessages(String bookingId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/$bookingId/messages'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> markChatRead(String bookingId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/chat/$bookingId/read'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  // ─── Wallet & Withdrawals ───────────────────────────
  Future<Map<String, dynamic>?> getWallet() async {
    final res = await http.get(
      Uri.parse('$baseUrl/partner/wallet'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<Map<String, dynamic>> requestWithdrawal(double amount) async {
    final res = await http.post(
      Uri.parse('$baseUrl/partner/wallet/withdraw'),
      headers: await _authHeaders(),
      body: jsonEncode({'amount': amount}),
    );
    return {'status': res.statusCode, 'body': jsonDecode(res.body)};
  }
}

