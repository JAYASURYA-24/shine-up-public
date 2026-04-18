import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_providers.dart';
import 'job_execution_screen.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Jobs'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'New', icon: Icon(Icons.notification_important, size: 18)),
              Tab(text: 'Active', icon: Icon(Icons.play_circle, size: 18)),
              Tab(text: 'History', icon: Icon(Icons.history, size: 18)),
            ],
          ),
        ),
        body: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (jobs) {
            final newJobs = jobs.where((j) => j['status'] == 'ASSIGNED').toList();
            final activeJobs = jobs.where((j) => j['status'] == 'CONFIRMED' || j['status'] == 'IN_PROGRESS').toList();
            final historyJobs = jobs.where((j) =>
                j['status'] == 'COMPLETED' || j['status'] == 'CANCELLED' || j['status'] == 'NO_RESPONSE').toList();

            return TabBarView(
              children: [
                _JobList(jobs: newJobs, emptyIcon: Icons.notification_add, emptyText: 'No new jobs', type: 'new'),
                _JobList(jobs: activeJobs, emptyIcon: Icons.work_off_outlined, emptyText: 'No active jobs', type: 'active'),
                _JobList(jobs: historyJobs, emptyIcon: Icons.history, emptyText: 'No completed jobs yet', type: 'history'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _JobList extends ConsumerWidget {
  final List<dynamic> jobs;
  final IconData emptyIcon;
  final String emptyText;
  final String type;

  const _JobList({required this.jobs, required this.emptyIcon, required this.emptyText, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(emptyText, style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(jobsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) => _JobCard(job: jobs[index], type: type),
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  final Map<String, dynamic> job;
  final String type;

  const _JobCard({required this.job, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = job['status'] ?? '';
    final sku = job['sku'] ?? {};
    final customer = job['customer'] ?? {};
    final customerUser = customer['user'] ?? {};
    final vehicle = job['vehicle'];
    final address = job['address'];
    final customerName = customer['name'] ?? customerUser['phone'] ?? 'Customer';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: (status == 'ASSIGNED' || status == 'CONFIRMED' || status == 'IN_PROGRESS')
            ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => JobExecutionScreen(job: job)),
              ).then((_) => ref.invalidate(jobsProvider))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Service name + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sku['title'] ?? 'Service',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 10),

              // Price
              Text('₹${job['total_amount']}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
              const SizedBox(height: 8),

              // Details
              _infoRow(Icons.person_outline, customerName),
              _infoRow(Icons.access_time, _formatTime(job['slot_start'])),
              if (vehicle != null)
                _infoRow(Icons.directions_car, '${vehicle['vehicle_type']} — ${vehicle['vehicle_number']}'),
              if (address != null)
                _infoRow(Icons.location_on_outlined, address['address_line'] ?? ''),
              const SizedBox(height: 12),

              // Action Buttons
              if (status == 'ASSIGNED') _buildNewJobActions(context, ref),
              if (status == 'CONFIRMED') _buildConfirmedActions(context),
              if (status == 'IN_PROGRESS') _buildInProgressActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700]), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dt = DateTime.parse(timeStr);
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = h >= 12 ? 'PM' : 'AM';
      final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '${dt.day}/${dt.month}/${dt.year} $h12:$m $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  Widget _buildNewJobActions(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final success = await ref.read(apiClientProvider).acceptJob(job['id']);
              if (success) {
                ref.invalidate(jobsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Job accepted! ✅'), backgroundColor: Color(0xFF27AE60)),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Accept Job', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmedActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF27AE60)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => JobExecutionScreen(job: job)),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Execution'),
          ),
        ),
      ],
    );
  }

  Widget _buildInProgressActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => JobExecutionScreen(job: job)),
            ),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            label: const Text('Continue Execution', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
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
      case 'ASSIGNED':
        bgColor = Colors.blue.withAlpha(25);
        textColor = Colors.blue;
      case 'CONFIRMED':
        bgColor = Colors.teal.withAlpha(25);
        textColor = Colors.teal;
      case 'CANCELLED':
        bgColor = Colors.red.withAlpha(25);
        textColor = Colors.red;
      default:
        bgColor = Colors.grey.withAlpha(25);
        textColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
