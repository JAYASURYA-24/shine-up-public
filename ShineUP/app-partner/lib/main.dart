import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'core/websocket/ws_client.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/jobs_screen.dart';
import 'features/dashboard/presentation/screens/earnings_screen.dart';
import 'features/slots/presentation/screens/slot_management_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  runApp(const ProviderScope(child: ShineUpPartnerApp()));
}

class ShineUpPartnerApp extends StatelessWidget {
  const ShineUpPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shine-Up Partner',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthRouter(),
    );
  }
}

class AuthRouter extends ConsumerWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    if (authState.status == AuthStatus.initial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (authState.status == AuthStatus.authenticated) {
      return const PartnerHomeShell();
    }
    return const LoginScreen();
  }
}

class PartnerHomeShell extends ConsumerStatefulWidget {
  const PartnerHomeShell({super.key});

  @override
  ConsumerState<PartnerHomeShell> createState() => _PartnerHomeShellState();
}

class _PartnerHomeShellState extends ConsumerState<PartnerHomeShell> {
  int _currentIndex = 0;
  final _api = ApiClient();
  WSClient? _wsClient;
  int _unreadCount = 0;
  Timer? _badgeTimer;
  StreamSubscription? _notifSub;
  StreamSubscription? _newJobSub;

  final _screens = const [
    JobsScreen(),
    SlotManagementScreen(),
    EarningsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _refreshBadge();
    _badgeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshBadge());
  }

  @override
  void dispose() {
    _wsClient?.dispose();
    _badgeTimer?.cancel();
    _notifSub?.cancel();
    _newJobSub?.cancel();
    super.dispose();
  }

  void _initWebSocket() {
    _wsClient = WSClient();
    _wsClient!.connect();

    // Listen for new notifications
    _notifSub = _wsClient!.notifications.listen((_) {
      _refreshBadge();
    });

    // Listen for new job assignments — show snackbar alert
    _newJobSub = _wsClient!.newJobs.listen((job) {
      _refreshBadge();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.work, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('🔔 New job assigned! Check your Jobs tab.')),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => setState(() => _currentIndex = 0),
            ),
          ),
        );
      }
    });
  }

  Future<void> _refreshBadge() async {
    try {
      final count = await _api.getUnreadNotificationCount();
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shine-Up Partner'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                  _refreshBadge();
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
