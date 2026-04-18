import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'core/websocket/ws_client.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/home/presentation/screens/services_screen.dart';
import 'features/home/presentation/screens/bookings_screen.dart';
import 'features/home/presentation/screens/profile_screen.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  runApp(const ProviderScope(child: ShineUpCustomerApp()));
}

class ShineUpCustomerApp extends StatelessWidget {
  const ShineUpCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shine-Up',
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
      return const CustomerHomeShell();
    }
    return const LoginScreen();
  }
}

class CustomerHomeShell extends ConsumerStatefulWidget {
  const CustomerHomeShell({super.key});

  @override
  ConsumerState<CustomerHomeShell> createState() => _CustomerHomeShellState();
}

class _CustomerHomeShellState extends ConsumerState<CustomerHomeShell> {
  int _currentIndex = 0;
  final _api = ApiClient();
  WSClient? _wsClient;
  int _unreadCount = 0;
  Timer? _badgeTimer;
  StreamSubscription? _notifSub;

  final _screens = const [
    HomeScreen(),
    ServicesScreen(),
    BookingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _refreshBadge();
    // Periodically refresh badge count
    _badgeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshBadge());
  }

  @override
  void dispose() {
    _wsClient?.dispose();
    _badgeTimer?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  void _initWebSocket() {
    _wsClient = WSClient();
    _wsClient!.connect();

    // Listen for new notifications to update badge
    _notifSub = _wsClient!.notifications.listen((_) {
      _refreshBadge();
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
        title: const Text('Shine-Up'),
        actions: [
          // Notification bell with badge
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.cleaning_services_outlined), selectedIcon: Icon(Icons.cleaning_services), label: 'Services'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
