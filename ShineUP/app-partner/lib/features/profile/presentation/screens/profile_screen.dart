import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import 'kyc_upload_screen.dart';
import 'bank_details_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Profile not found'));

          final kycStatus = profile['kyc_status'] ?? 'PENDING';
          final isOnline = profile['is_online'] ?? false;
          final name = profile['name'] ?? 'Partner';
          final rating = (profile['rating'] ?? 5.0).toDouble();
          final acceptanceRate = (profile['acceptance_rate'] ?? 100.0).toDouble();
          final bankVerified = profile['bank_verified'] ?? false;
          final city = profile['city'] ?? '';
          final category = profile['category'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ─── Avatar + Name ─────────────────────
                _buildProfileHeader(name, city, category, isOnline),
                const SizedBox(height: 24),

                // ─── Online Toggle ─────────────────────
                _OnlineToggleCard(isOnline: isOnline, kycStatus: kycStatus),
                const SizedBox(height: 12),

                // ─── KYC Status Card ───────────────────
                _buildNavigationCard(
                  context: context,
                  icon: kycStatus == 'APPROVED' ? Icons.verified : kycStatus == 'REJECTED' ? Icons.cancel : Icons.pending,
                  iconColor: kycStatus == 'APPROVED' ? Colors.green : kycStatus == 'REJECTED' ? Colors.red : Colors.orange,
                  title: 'KYC Documents',
                  subtitle: 'Status: $kycStatus',
                  trailing: _kycBadge(kycStatus),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KYCUploadScreen())),
                ),
                const SizedBox(height: 12),

                // ─── Bank Details Card ─────────────────
                _buildNavigationCard(
                  context: context,
                  icon: bankVerified ? Icons.account_balance : Icons.account_balance_outlined,
                  iconColor: bankVerified ? Colors.green : Colors.grey,
                  title: 'Bank Account',
                  subtitle: bankVerified ? 'Verified ✓' : 'Not verified — Add bank details',
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankDetailsScreen())),
                ),
                const SizedBox(height: 12),

                // ─── Performance Stats ─────────────────
                Row(
                  children: [
                    Expanded(child: _statCard('Rating', '⭐ ${rating.toStringAsFixed(1)}', Icons.star, Colors.amber)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Acceptance', '${acceptanceRate.toStringAsFixed(0)}%', Icons.check_circle, Colors.green)),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String name, String city, String category, bool isOnline) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF27AE60),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (city.isNotEmpty || category.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [if (category.isNotEmpty) category, if (city.isNotEmpty) city].join(' · '),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _kycBadge(String status) {
    Color color;
    switch (status) {
      case 'APPROVED':
        color = Colors.green;
      case 'REJECTED':
        color = Colors.red;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── Online Toggle Card ──────────────────────────────────

class _OnlineToggleCard extends ConsumerWidget {
  final bool isOnline;
  final String kycStatus;

  const _OnlineToggleCard({required this.isOnline, required this.kycStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isOnline
              ? const LinearGradient(colors: [Color(0xFF27AE60), Color(0xFF2ECC71)])
              : null,
        ),
        child: SwitchListTile(
          title: Text(
            isOnline ? 'You are Online' : 'You are Offline',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isOnline ? Colors.white : null,
            ),
          ),
          subtitle: Text(
            isOnline ? 'Accepting new jobs' : 'Toggle to start accepting jobs',
            style: TextStyle(
              fontSize: 12,
              color: isOnline ? Colors.white70 : Colors.grey[600],
            ),
          ),
          value: isOnline,
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.white38,
          onChanged: (val) async {
            final success = await ref.read(apiClientProvider).toggleOnline(val);
            if (success) {
              ref.invalidate(profileProvider);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('KYC must be approved before going online')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
