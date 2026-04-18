import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../dashboard/providers/dashboard_providers.dart';

final walletProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(apiClientProvider).getWallet();
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _amountCtrl = TextEditingController();
  bool _isWithdrawing = false;

  Future<void> _requestWithdrawal(double balance) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available Balance: ₹${balance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Withdrawals are processed only on the 1st and 2nd of every month.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(_amountCtrl.text);
              if (val == null || val <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid amount')));
                return;
              }
              Navigator.pop(ctx);
              _processWithdrawalCall(val);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _processWithdrawalCall(double amount) async {
    setState(() => _isWithdrawing = true);
    try {
      final res = await ref.read(apiClientProvider).requestWithdrawal(amount);
      if (res['status'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request submitted!')));
          ref.invalidate(walletProvider);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['body']['error'] ?? 'Withdrawal failed')));
        }
      }
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet')),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Failed to load wallet'));
          }

          final balance = (data['wallet_balance'] as num).toDouble();
          final transactions = data['transactions'] as List? ?? [];

          return CustomScrollView(
            slivers: [
              // Balance Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A90E2),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        '₹${balance.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isWithdrawing || balance < 500 ? null : () => _requestWithdrawal(balance),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4A90E2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _isWithdrawing 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.account_balance_wallet_outlined),
                          label: Text(_isWithdrawing ? 'Processing...' : 'Request Withdrawal'),
                        ),
                      ),
                      if (balance < 500)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Minimum withdrawal is ₹500', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),

              // Transaction History Title
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              if (transactions.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.grey))),
                  ),
                ),

              // Transactions List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final tx = transactions[i];
                    final isCredit = tx['amount'] > 0;
                    final amount = (tx['amount'] as num).toDouble().abs();
                    final date = DateTime.parse(tx['created_at']).toLocal();

                    IconData icon = Icons.receipt_long;
                    Color color = Colors.blue;
                    String title = "Wallet Transaction";

                    if (tx['type'] == 'JOB_CREDIT') {
                      title = 'Earned from Job';
                      icon = Icons.handyman;
                      color = Colors.green;
                    } else if (tx['type'] == 'WITHDRAWAL') {
                      title = 'Withdrawal Request';
                      icon = Icons.account_balance;
                      color = Colors.orange;
                    }

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('${tx['reference'] ?? '-'} • ${DateFormat('MMM dd, hh:mm a').format(date)}', style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                        '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isCredit ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                  childCount: transactions.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
