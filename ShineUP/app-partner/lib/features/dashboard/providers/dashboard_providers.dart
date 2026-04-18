import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final apiClientProvider = Provider((ref) => ApiClient());

// ─── Profile ──────────────────────────────────────────
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.read(apiClientProvider).getProfile();
});

// ─── Jobs ─────────────────────────────────────────────
final jobsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(apiClientProvider).getJobs();
});

// ─── Earnings ─────────────────────────────────────────
final earningsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.read(apiClientProvider).getEarnings();
});
