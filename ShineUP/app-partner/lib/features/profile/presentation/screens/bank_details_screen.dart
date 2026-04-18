import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dashboard/providers/dashboard_providers.dart';

class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _holderController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankController = TextEditingController();

  bool _isLoading = false;
  bool _isVerifying = false;
  Map<String, dynamic>? _bankData;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    setState(() => _isLoading = true);
    final data = await ref.read(apiClientProvider).getBankDetails();
    setState(() {
      _isLoading = false;
      _bankData = data;
      if (data != null && data['account_holder'] != null) {
        _holderController.text = data['account_holder'] ?? '';
        _accountController.text = data['account_number'] ?? '';
        _ifscController.text = data['ifsc_code'] ?? '';
        _bankController.text = data['bank_name'] ?? '';
      }
    });
  }

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  bool get _isVerified => _bankData?['is_verified'] == true;

  Future<void> _submitBank() async {
    if (_holderController.text.isEmpty || _accountController.text.isEmpty ||
        _ifscController.text.isEmpty || _bankController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await ref.read(apiClientProvider).submitBankDetails({
      'account_holder': _holderController.text,
      'account_number': _accountController.text,
      'ifsc_code': _ifscController.text,
      'bank_name': _bankController.text,
    });
    setState(() => _isLoading = false);

    if (result != null) {
      setState(() => _bankData = result['bank_account']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details saved ✅'), backgroundColor: Color(0xFF27AE60)),
        );
      }
    }
  }

  Future<void> _verifyBank() async {
    setState(() => _isVerifying = true);
    final result = await ref.read(apiClientProvider).verifyBank();
    setState(() => _isVerifying = false);

    if (result != null) {
      setState(() => _bankData = result['bank_account']);
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('₹1 test successful — Bank verified! 🎉'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank verification failed. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Account')),
      body: _isLoading && _bankData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isVerified ? const Color(0xFFF0FFF4) : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isVerified ? Colors.green.withAlpha(100) : Colors.orange.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isVerified ? Icons.verified : Icons.info_outline,
                          color: _isVerified ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isVerified
                                ? 'Bank account verified! You can receive payments.'
                                : 'Add your bank details to receive service earnings.',
                            style: TextStyle(
                              color: _isVerified ? Colors.green[800] : Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form
                  _buildField(_holderController, 'Account Holder Name', Icons.person, TextInputType.name),
                  const SizedBox(height: 16),
                  _buildField(_accountController, 'Account Number', Icons.numbers, TextInputType.number),
                  const SizedBox(height: 16),
                  _buildField(_ifscController, 'IFSC Code', Icons.code, TextInputType.text),
                  const SizedBox(height: 16),
                  _buildField(_bankController, 'Bank Name', Icons.account_balance, TextInputType.text),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitBank,
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: const Text('Save Bank Details'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Verify Button
                  if (_bankData != null && _bankData!['account_holder'] != null && !_isVerified)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isVerifying ? null : _verifyBank,
                        icon: _isVerifying
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.currency_rupee),
                        label: const Text('Verify with ₹1 Test'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFF27AE60)),
                          foregroundColor: const Color(0xFF27AE60),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
