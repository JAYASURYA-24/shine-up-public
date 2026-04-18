import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/home_providers.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bookings) {
          if (bookings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No bookings yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final status = booking['status'] ?? '';
              final sku = booking['sku'] ?? {};
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BookingDetailScreen(bookingId: booking['id']),
                    ));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: _statusIcon(status),
                    title: Text(sku['title'] ?? 'Service', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('₹${booking['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (status == 'SCHEDULED' || status == 'ASSIGNED' || status == 'IN_PROGRESS')
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber.withAlpha(50), borderRadius: BorderRadius.circular(4)),
                            child: Text('Verification OTP: ${booking['otp']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown)),
                          ),
                        if (booking['partner'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('Partner: ${booking['partner']['name'] ?? booking['partner']['phone']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                          ),
                        const SizedBox(height: 6),
                        Text(booking['slot_start'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    trailing: _statusBadge(status),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusIcon(String status) {
    IconData icon;
    Color color;
    switch (status) {
      case 'COMPLETED':
        icon = Icons.check_circle;
        color = Colors.green;
      case 'IN_PROGRESS':
        icon = Icons.timer;
        color = Colors.orange;
      case 'CANCELLED':
        icon = Icons.cancel;
        color = Colors.red;
      default:
        icon = Icons.schedule;
        color = Colors.blue;
    }
    return Icon(icon, color: color, size: 32);
  }

  Widget _statusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'COMPLETED':
        bgColor = Colors.green.withAlpha(25);
        textColor = Colors.green;
      case 'IN_PROGRESS':
        bgColor = Colors.orange.withAlpha(25);
        textColor = Colors.orange;
      case 'CANCELLED':
        bgColor = Colors.red.withAlpha(25);
        textColor = Colors.red;
      default:
        bgColor = Colors.blue.withAlpha(25);
        textColor = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
