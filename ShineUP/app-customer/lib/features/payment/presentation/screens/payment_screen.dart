import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../home/providers/home_providers.dart';
import '../../../home/presentation/screens/home_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final double amount;
  final String serviceName;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.serviceName,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isLoading = false;

  Future<void> _processMockPayment() async {
    setState(() => _isLoading = true);

    try {
      final client = ref.read(apiClientProvider);

      // 1. Create order
      final orderRes = await client.createPaymentOrder(widget.bookingId);
      if (orderRes == null) throw Exception("Failed to create mock payment order");

      // 2. Mock Razorpay logic showing success delay
      await Future.delayed(const Duration(seconds: 2));

      final mockPayId = "pay_mock_${Random().nextInt(999999)}";

      // 3. Verify Payment
      final success = await client.verifyPayment(
        bookingId: widget.bookingId,
        razorpayOrderId: orderRes['order_id'],
        razorpayPaymentId: mockPayId,
        method: 'UPI',
      );

      if (success && mounted) {
        _showSuccessAndNavigate("Payment Successful! ₹${widget.amount.toInt()} paid via UPI.");
      } else {
        throw Exception("Payment Verification Failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processCashOnDelivery() {
    _showSuccessAndNavigate("Booking Confirmed! You can pay ₹${widget.amount.toInt()} after the service.");
  }

  void _showSuccessAndNavigate(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Booking Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    const Text('Total Amount', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '₹${widget.amount.toInt()}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.serviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              const Text('Select Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Mock Razorpay / UPI Button
              _paymentOptionCard(
                icon: Icons.account_balance_wallet,
                title: 'Pay Now (Mock Razorpay)',
                subtitle: 'UPI, Cards, Netbanking',
                color: Colors.blue,
                onTap: _isLoading ? null : _processMockPayment,
              ),
              const SizedBox(height: 16),

              // COD Button
              _paymentOptionCard(
                icon: Icons.money,
                title: 'Pay After Service',
                subtitle: 'Cash or Scan QR later',
                color: Colors.green,
                onTap: _isLoading ? null : _processCashOnDelivery,
              ),

              const Spacer(),
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing Payment...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
