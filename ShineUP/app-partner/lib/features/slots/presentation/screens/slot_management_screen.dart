import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dashboard/providers/dashboard_providers.dart';

class SlotManagementScreen extends ConsumerStatefulWidget {
  const SlotManagementScreen({super.key});

  @override
  ConsumerState<SlotManagementScreen> createState() => _SlotManagementScreenState();
}

class _SlotManagementScreenState extends ConsumerState<SlotManagementScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _slots = [];
  List<dynamic> _leaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _dateStr(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiClientProvider);
    final slots = await api.getSlots(_dateStr(_selectedDate));
    final leaves = await api.getLeaves();
    setState(() {
      _slots = slots;
      _leaves = leaves;
      _isLoading = false;
    });
  }

  Future<void> _toggleSlot(String slotId) async {
    final result = await ref.read(apiClientProvider).toggleSlot(slotId);
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _requestLeave() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date: ${_dateStr(_selectedDate)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ref.read(apiClientProvider).requestLeave(
        _dateStr(_selectedDate),
        reasonController.text,
      );
      if (result != null) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave requested ✅'), backgroundColor: Color(0xFF27AE60)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave request failed. Maybe already requested.')),
          );
        }
      }
    }
  }

  bool get _hasLeaveForSelectedDate {
    final dateStr = _dateStr(_selectedDate);
    return _leaves.any((l) => l['date'] == dateStr && l['status'] != 'REJECTED');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_busy),
            tooltip: 'Leave History',
            onPressed: () => _showLeaveHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Picker Strip
          _buildDateStrip(),

          // Leave Banner
          if (_hasLeaveForSelectedDate)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(100)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Leave requested for this date', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

          // Slots Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                    ? const Center(child: Text('No slots available'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: _slots.length,
                        itemBuilder: (context, index) {
                          final slot = _slots[index];
                          return _buildSlotCard(slot);
                        },
                      ),
          ),

          // Bottom Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _hasLeaveForSelectedDate ? null : _requestLeave,
                icon: const Icon(Icons.event_busy),
                label: const Text('Request Leave for This Day'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: _hasLeaveForSelectedDate ? Colors.grey : Colors.red),
                  foregroundColor: _hasLeaveForSelectedDate ? Colors.grey : Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 14, // Next 14 days
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = _dateStr(date) == _dateStr(_selectedDate);
          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final dayName = dayNames[date.weekday - 1];

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadData();
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF27AE60) : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF27AE60).withAlpha(80), blurRadius: 8, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayName, style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white70 : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  )),
                  const SizedBox(height: 4),
                  Text('${date.day}', style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  )),
                  const SizedBox(height: 2),
                  Text(_monthName(date.month), style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.white70 : Colors.grey[500],
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    final hour = slot['hour'] ?? 0;
    final isAvailable = slot['is_available'] ?? false;
    final hasBooking = slot['booking_id'] != null && slot['booking_id'] != '';
    final slotId = slot['id'] ?? '';

    Color bgColor;
    Color textColor;
    IconData icon;

    if (hasBooking) {
      bgColor = const Color(0xFFE3F2FD);
      textColor = Colors.blue;
      icon = Icons.event;
    } else if (isAvailable) {
      bgColor = const Color(0xFFF0FFF4);
      textColor = const Color(0xFF27AE60);
      icon = Icons.check_circle_outline;
    } else {
      bgColor = const Color(0xFFFFF3F0);
      textColor = Colors.red;
      icon = Icons.block;
    }

    final timeStr = hour < 12 ? '${hour}AM' : hour == 12 ? '12PM' : '${hour - 12}PM';

    return GestureDetector(
      onTap: hasBooking ? null : () => _toggleSlot(slotId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: textColor.withAlpha(60)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(height: 4),
            Text(timeStr, style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 13,
            )),
            Text(
              hasBooking ? 'Booked' : isAvailable ? 'Open' : 'Closed',
              style: TextStyle(fontSize: 10, color: textColor.withAlpha(180)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveHistory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leave History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_leaves.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No leave requests yet', style: TextStyle(color: Colors.grey))),
              )
            else
              ..._leaves.map((leave) {
                final status = leave['status'] ?? 'PENDING';
                Color statusColor;
                switch (status) {
                  case 'APPROVED':
                    statusColor = Colors.green;
                  case 'REJECTED':
                    statusColor = Colors.red;
                  default:
                    statusColor = Colors.orange;
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.event_busy, color: statusColor),
                    title: Text(leave['date'] ?? ''),
                    subtitle: leave['reason'] != null && leave['reason'] != ''
                        ? Text(leave['reason'])
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        if (status == 'PENDING') ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                            onPressed: () async {
                              await ref.read(apiClientProvider).cancelLeave(leave['id']);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadData();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
