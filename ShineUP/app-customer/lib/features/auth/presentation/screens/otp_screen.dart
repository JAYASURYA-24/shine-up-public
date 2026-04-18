import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class OTPScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String name;
  final String email;
  final String location;
  final double latitude;
  final double longitude;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.name,
    required this.email,
    required this.location,
    this.latitude = 0,
    this.longitude = 0,
  });

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  final _otpController = TextEditingController();

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid 6-digit OTP')),
      );
      return;
    }

    await ref.read(authStateProvider.notifier).verifyOTP(
      widget.phoneNumber,
      otp,
      name: widget.name,
      email: widget.email,
      location: widget.location,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in auth state to handle errors directly in the UI
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.status == AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Error occurred')),
        );
      } else if (next.status == AuthStatus.authenticated) {
        // Pop all overlay screens to reveal the home content (AuthRouter handles the actual widget switch)
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });

    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Text(
              'OTP sent to +91 ${widget.phoneNumber}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '000000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: authState.status == AuthStatus.loading ? null : _verifyOTP,
              child: authState.status == AuthStatus.loading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Verify & Login'),
            ),
          ],
        ),
      ),
    );
  }
}
