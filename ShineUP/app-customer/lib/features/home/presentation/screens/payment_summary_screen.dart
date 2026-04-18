import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/home_providers.dart';
import '../../../payment/presentation/screens/payment_screen.dart';

class PaymentSummaryScreen extends ConsumerStatefulWidget {
  final dynamic service;
  final dynamic sku;
  final dynamic vehicle;
  final dynamic address;
  final String slotStart;

  const PaymentSummaryScreen({
    super.key,
    required this.service,
    required this.sku,
    required this.vehicle,
    required this.address,
    required this.slotStart,
  });

  @override
  ConsumerState<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends ConsumerState<PaymentSummaryScreen> {
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    final result = await ref.read(apiClientProvider).createBooking(
      skuId: widget.sku['id'],
      slotStart: widget.slotStart,
      vehicleId: widget.vehicle?['id'],
      addressId: widget.address?['id'],
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (result != null && result['booking'] != null) {
        ref.invalidate(myBookingsProvider);
        
        final price = (widget.sku['price'] as num).toDouble();
        final tax = price * 0.18;
        final total = price + tax;

        // Navigate to dedicated Payment Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              bookingId: result['booking']['id'],
              amount: total,
              serviceName: widget.service['name'] ?? 'Service',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking Failed. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = (widget.sku['price'] as num).toDouble();
    final tax = price * 0.18; // Mock 18% GST
    final total = price + tax;
    final slotTime = DateTime.parse(widget.slotStart).toLocal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Summary'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing Payment...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Booking Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _summaryCard(
                  child: Column(
                    children: [
                      _infoRow('Service', widget.service['name'] ?? ''),
                      _infoRow('Package', widget.sku['title'] ?? ''),
                      _infoRow('Time', DateFormat('MMM dd, yyyy • hh:mm a').format(slotTime)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Vehicle & Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _summaryCard(
                  child: Column(
                    children: [
                      if (widget.vehicle != null) _infoRow('Vehicle', '${widget.vehicle['vehicle_number']} (${widget.vehicle['vehicle_type']})'),
                      if (widget.address != null) _infoRow('Address', widget.address['label'] ?? 'Home'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Payment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _summaryCard(
                  child: Column(
                    children: [
                      _infoRow('Subtotal', '₹${price.toStringAsFixed(2)}'),
                      _infoRow('GST (18%)', '₹${tax.toStringAsFixed(2)}'),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total to Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirm & Proceed to Pay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }

  Widget _summaryCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
