import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  String get baseUrl {
    return 'https://shine-up-public-production.up.railway.app/api/v1';
  }

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

  // ─── Services (Public) ──────────────────────────────
  Future<List<dynamic>> getServices() async {
    final res = await http.get(Uri.parse('$baseUrl/services'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  // ─── Profile ────────────────────────────────────────
  Future<Map<String, dynamic>?> getProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/profile'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<Map<String, dynamic>?> updateProfile(String name, String email, String location) async {
    final res = await http.put(
      Uri.parse('$baseUrl/customer/profile'),
      headers: await _authHeaders(),
      body: jsonEncode({'name': name, 'email': email, 'location': location}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ─── Bookings ───────────────────────────────────────
  Future<List<dynamic>> getMyBookings() async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/bookings'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Map<String, dynamic>?> getBookingDetail(String bookingId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/bookings/$bookingId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<List<dynamic>> getSlots(String date, String skuId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/slots?date=$date&sku_id=$skuId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Map<String, dynamic>?> createBooking({
    required String skuId, 
    required String slotStart, 
    String? vehicleId,
    String? addressId,
  }) async {
    final body = {
      'sku_id': skuId, 
      'slot_start': slotStart,
    };
    if (vehicleId != null) body['vehicle_id'] = vehicleId;
    if (addressId != null) body['address_id'] = addressId;

    final res = await http.post(
      Uri.parse('$baseUrl/bookings/'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<bool> cancelBooking(String bookingId, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customer/bookings/$bookingId/cancel'),
      headers: await _authHeaders(),
      body: jsonEncode({'reason': reason}),
    );
    return res.statusCode == 200;
  }

  Future<bool> rescheduleBooking(String bookingId, String newSlot) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customer/bookings/$bookingId/reschedule'),
      headers: await _authHeaders(),
      body: jsonEncode({'new_slot_start': newSlot}),
    );
    return res.statusCode == 200;
  }

  Future<bool> rateBooking(String bookingId, int stars, String review) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customer/bookings/$bookingId/rate'),
      headers: await _authHeaders(),
      body: jsonEncode({'stars': stars, 'review': review}),
    );
    return res.statusCode == 200;
  }

  // ─── Wallet ─────────────────────────────────────────
  Future<Map<String, dynamic>?> getWallet() async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/wallet'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<bool> applyReferral(String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customer/wallet/apply-referral'),
      headers: await _authHeaders(),
      body: jsonEncode({'referral_code': code}),
    );
    return res.statusCode == 200;
  }

  // ─── Notifications ──────────────────────────────────
  Future<List<dynamic>> getNotifications() async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/notifications'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  // ─── Vehicles ──────────────────────────────────────
  Future<List<dynamic>> getVehicles() async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/vehicles'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Map<String, dynamic>?> addVehicle({
    required String vehicleType,
    required String vehicleNumber,
    String? modelName,
    bool isDefault = true,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customer/vehicles'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'vehicle_type': vehicleType,
        'vehicle_number': vehicleNumber,
        'model_name': modelName ?? '',
        'is_default': isDefault,
      }),
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    return null;
  }

  Future<bool> deleteVehicle(String vehicleId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/customer/vehicles/$vehicleId'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  // ─── Addresses ─────────────────────────────────────
  Future<List<dynamic>> getAddresses() async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/addresses'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Map<String, dynamic>?> addAddress({
    required String addressLine,
    String label = 'Home',
    String city = '',
    String pincode = '',
    double latitude = 0,
    double longitude = 0,
    bool isDefault = true,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customer/addresses'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'address_line': addressLine,
        'label': label,
        'city': city,
        'pincode': pincode,
        'latitude': latitude,
        'longitude': longitude,
        'is_default': isDefault,
      }),
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    return null;
  }

  // ─── Serviceability (Public) ───────────────────────
  Future<Map<String, dynamic>?> checkServiceability(double lat, double lng) async {
    final res = await http.get(
      Uri.parse('$baseUrl/check-serviceability?lat=$lat&lng=$lng'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ─── Notifications ──────────────────────────────────
  Future<List<dynamic>> getNotificationsList() async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/notifications'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> markNotificationRead(String notifId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/customer/notifications/$notifId/read'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  Future<bool> markAllNotificationsRead() async {
    final res = await http.put(
      Uri.parse('$baseUrl/customer/notifications/read-all'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 200;
  }

  Future<int> getUnreadNotificationCount() async {
    final res = await http.get(
      Uri.parse('$baseUrl/customer/notifications/unread-count'),
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

  // ─── Payment ───────────────────────────────────────
  Future<Map<String, dynamic>?> createPaymentOrder(String bookingId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payment/create-order'),
      headers: await _authHeaders(),
      body: jsonEncode({'booking_id': bookingId}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  Future<bool> verifyPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    String method = 'UPI',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payment/verify'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'booking_id': bookingId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'method': method,
      }),
    );
    return res.statusCode == 200;
  }
}

