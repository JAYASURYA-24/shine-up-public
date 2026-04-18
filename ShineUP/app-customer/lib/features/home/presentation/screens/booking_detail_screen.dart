import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/home_providers.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isLoading = true;
  dynamic _booking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetail();
  }

  Future<void> _fetchBookingDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiClientProvider).getBookingDetail(widget.bookingId);
      if (data != null) {
        setState(() => _booking = data);
      } else {
        setState(() => _error = 'Failed to load booking details.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for cancellation (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, Keep It')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ref.read(apiClientProvider).cancelBooking(widget.bookingId, reasonController.text);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking Cancelled')));
        ref.invalidate(myBookingsProvider);
        _fetchBookingDetail(); // Reload to show updated status
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to cancel.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: Center(child: Text(_error ?? 'Unknown error')),
      );
    }

    final status = _booking['status'] ?? '';
    final sku = _booking['sku'] ?? {};
    final slotStart = DateTime.parse(_booking['slot_start']).toLocal();
    final canCancel = status == 'SCHEDULED' || status == 'CREATED' || status == 'ASSIGNED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _statusBgColor(status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _statusIconLarge(status),
                const SizedBox(height: 12),
                Text(
                  _statusText(status),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _statusTextColor(status)),
                ),
                if (status == 'CANCELLED' && _booking['cancel_note'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Reason: ${_booking['cancel_note']}', style: TextStyle(color: _statusTextColor(status))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Overview Card
          _sectionCard(title: 'Service Information', children: [
            _detailRow('Service', sku['title'] ?? 'Unknown Package'),
            _detailRow('Amount', '₹${_booking['total_amount']}'),
            _detailRow('Date & Time', DateFormat('MMM dd, yyyy • hh:mm a').format(slotStart)),
            _detailRow('Booking ID', widget.bookingId.split('-').first.toUpperCase()),
          ]),
          const SizedBox(height: 16),

          // Partner Details (if assigned)
          if (_booking['partner'] != null)
            _sectionCard(title: 'Service Provider', children: [
              _detailRow('Name', _booking['partner']['name'] ?? 'Assigned Partner'),
              _detailRow('Phone', _booking['partner']['phone'] ?? '...'),
              if (status == 'ASSIGNED' || status == 'IN_PROGRESS' || status == 'SCHEDULED' || status == 'CREATED')
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Verification OTP:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_booking['otp']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                ),
            ]),
          
          if (_booking['partner'] != null) const SizedBox(height: 16),

          // Location & Vehicle
          // Note: Backend might not return full vehicle/address payload yet if preloads are missing, but assuming IDs or partials.
          // We will mock display since we added the fields.

          if (canCancel) ...[
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: _cancelBooking,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'COMPLETED': return Colors.green.shade50;
      case 'IN_PROGRESS': return Colors.orange.shade50;
      case 'CANCELLED': return Colors.red.shade50;
      default: return Colors.blue.shade50; // SCHEDULED / ASSIGNED
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'COMPLETED': return Colors.green.shade700;
      case 'IN_PROGRESS': return Colors.orange.shade700;
      case 'CANCELLED': return Colors.red.shade700;
      default: return Colors.blue.shade700;
    }
  }

  Widget _statusIconLarge(String status) {
    IconData icon;
    switch (status) {
      case 'COMPLETED': icon = Icons.check_circle_outline; break;
      case 'IN_PROGRESS': icon = Icons.timer_outlined; break;
      case 'CANCELLED': icon = Icons.cancel_outlined; break;
      default: icon = Icons.schedule_outlined; break;
    }
    return Icon(icon, size: 64, color: _statusTextColor(status));
  }

  String _statusText(String status) {
    switch (status) {
      case 'CREATED': return 'Looking for Partner';
      case 'SCHEDULED': return 'Scheduled';
      case 'ASSIGNED': return 'Partner Assigned';
      case 'IN_PROGRESS': return 'Service In Progress';
      case 'COMPLETED': return 'Completed';
      case 'CANCELLED': return 'Cancelled';
      default: return status;
    }
  }
}
