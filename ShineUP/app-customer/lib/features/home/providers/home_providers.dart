import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final apiClientProvider = Provider((ref) => ApiClient());

// ─── Services Catalog ─────────────────────────────────
final servicesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(apiClientProvider).getServices();
});

// ─── My Bookings ──────────────────────────────────────
final myBookingsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(apiClientProvider).getMyBookings();
});

// ─── Profile ──────────────────────────────────────────
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.read(apiClientProvider).getProfile();
});

// ─── Wallet ───────────────────────────────────────────
final walletProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.read(apiClientProvider).getWallet();
});

// ─── Notifications ────────────────────────────────────
final notificationsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(apiClientProvider).getNotifications();
});

// ─── Vehicles ─────────────────────────────────────────
final vehiclesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(apiClientProvider).getVehicles();
});

// ─── Addresses ────────────────────────────────────────
final addressesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(apiClientProvider).getAddresses();
});
