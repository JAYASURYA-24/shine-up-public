import 'package:flutter/material.dart';
import 'package:app_partner/core/api/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiClient();
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    final data = await _api.getNotificationsList();
    setState(() {
      _notifications = data;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await _api.markAllNotificationsRead();
    _loadNotifications();
  }

  IconData _getNotificationIcon(String title) {
    if (title.contains('Assigned')) return Icons.assignment;
    if (title.contains('Confirmed')) return Icons.check_circle;
    if (title.contains('Cancelled')) return Icons.cancel;
    if (title.contains('Done') || title.contains('Completed')) return Icons.celebration;
    if (title.contains('KYC')) return Icons.verified_user;
    return Icons.notifications;
  }

  Color _getNotificationColor(String title) {
    if (title.contains('Assigned')) return Colors.blue;
    if (title.contains('Done') || title.contains('Completed')) return Colors.teal;
    if (title.contains('Cancelled')) return Colors.red;
    if (title.contains('KYC')) return Colors.green;
    return Colors.orange;
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Read All'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Job updates will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _a) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final title = notif['title'] ?? '';
                      final body = notif['body'] ?? '';
                      final isRead = notif['is_read'] == true;
                      final timeStr = _formatTime(notif['created_at']);

                      return Dismissible(
                        key: Key(notif['id'] ?? index.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.green,
                          child: const Icon(Icons.done, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          _api.markNotificationRead(notif['id']);
                          setState(() => _notifications.removeAt(index));
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: _getNotificationColor(title).withValues(alpha: 0.15),
                            child: Icon(
                              _getNotificationIcon(title),
                              color: _getNotificationColor(title),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(body, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(timeStr, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                          trailing: !isRead
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
