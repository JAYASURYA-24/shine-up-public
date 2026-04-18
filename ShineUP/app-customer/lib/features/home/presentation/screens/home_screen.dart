import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/home_providers.dart';
import 'service_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _vehicleChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVehicle());
  }

  Future<void> _checkVehicle() async {
    final vehicles = await ref.read(apiClientProvider).getVehicles();
    if (vehicles.isEmpty && mounted) {
      _showVehiclePopup();
    } else {
      setState(() => _vehicleChecked = true);
    }
  }

  void _showVehiclePopup() {
    String vehicleType = '4W';
    final numberCtrl = TextEditingController();
    final modelCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_car, color: Color(0xFF4A90E2), size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Your Vehicle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Required to book services', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Vehicle Type Toggle
              const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _vehicleTypeChip('2W', '🏍️ Two Wheeler', vehicleType == '2W', () {
                    setModalState(() => vehicleType = '2W');
                  }),
                  const SizedBox(width: 12),
                  _vehicleTypeChip('4W', '🚗 Four Wheeler', vehicleType == '4W', () {
                    setModalState(() => vehicleType = '4W');
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Vehicle Number
              TextField(
                controller: numberCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Vehicle Number *',
                  hintText: 'TN 01 AB 1234',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Model Name
              TextField(
                controller: modelCtrl,
                decoration: InputDecoration(
                  labelText: 'Model Name',
                  hintText: 'e.g. Swift, Activa',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () async {
                  if (numberCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Vehicle number is required')),
                    );
                    return;
                  }
                  final result = await ref.read(apiClientProvider).addVehicle(
                    vehicleType: vehicleType,
                    vehicleNumber: numberCtrl.text.trim(),
                    modelName: modelCtrl.text.trim(),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (result != null) {
                      ref.invalidate(vehiclesProvider);
                      setState(() => _vehicleChecked = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vehicle added! 🚗')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleTypeChip(String value, String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4A90E2) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF4A90E2) : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF4A90E2),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final profileAsync = ref.watch(profileProvider);
                                      return profileAsync.when(
                                        data: (profile) {
                                          final name = profile?['name'] ?? 'Guest';
                                          return Text(
                                            'Welcome, $name 👋',
                                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                          );
                                        },
                                        loading: () => const Text('Shine-Up ✨', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                        error: (_, __) => const Text('Shine-Up ✨', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final addressesAsync = ref.watch(addressesProvider);
                                      return GestureDetector(
                                        onTap: () => _showAddressPicker(),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.location_on, color: Colors.white, size: 14),
                                            const SizedBox(width: 4),
                                            addressesAsync.when(
                                              data: (addresses) {
                                                final def = addresses.firstWhere((a) => a['is_default'] == true, orElse: () => addresses.isNotEmpty ? addresses.first : null);
                                                return Expanded(
                                                  child: Text(
                                                    def != null ? '${def['label']}: ${def['address_line']}' : 'Select Location',
                                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              },
                                              loading: () => const Text('Loading...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                              error: (_, __) => const Text('Set Location', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                            ),
                                            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final vehiclesAsync = ref.watch(vehiclesProvider);
                                      return vehiclesAsync.when(
                                        data: (vehicles) {
                                          if (vehicles.isEmpty) return const SizedBox.shrink();
                                          final def = vehicles.firstWhere((v) => v['is_default'] == true, orElse: () => vehicles.first);
                                          final is4W = def['vehicle_type'] == '4W';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withAlpha(40),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(is4W ? Icons.directions_car : Icons.motorcycle, color: Colors.white, size: 14),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${def['model_name']} (${def['vehicle_number']})',
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        loading: () => const SizedBox.shrink(),
                                        error: (_, __) => const SizedBox.shrink(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Categories Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Our Services',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                _categoryCard(
                  icon: Icons.local_car_wash,
                  title: 'Vehicle Wash',
                  subtitle: 'One-time cleaning',
                  color: const Color(0xFF4A90E2),
                  onTap: () => _navigateToCategory('VEHICLE_WASH'),
                ),
                _categoryCard(
                  icon: Icons.calendar_month,
                  title: 'Monthly Package',
                  subtitle: 'Regular wash plans',
                  color: const Color(0xFF27AE60),
                  onTap: () => _navigateToCategory('MONTHLY_PACKAGE'),
                ),
                _categoryCard(
                  icon: Icons.description_outlined,
                  title: 'PUC Certificate',
                  subtitle: 'Doorstep issuance',
                  color: const Color(0xFFE67E22),
                  onTap: () => _navigateToCategory('PUC_CERTIFICATE'),
                ),
                _categoryCard(
                  icon: Icons.home_outlined,
                  title: 'Home Cleaning',
                  subtitle: 'Deep clean services',
                  color: const Color(0xFF9B59B6),
                  onTap: () => _navigateToCategory('HOME_CLEANING'),
                ),
                _categoryCard(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Accessories',
                  subtitle: 'Coming soon',
                  color: Colors.grey,
                  onTap: null,
                ),
              ]),
            ),
          ),

          // Popular Services
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Popular Services',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          servicesAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))),
            error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            data: (services) {
              // Collect popular SKUs across all services
              final popularItems = <Map<String, dynamic>>[];
              for (final svc in services) {
                final skus = (svc['skus'] as List?) ?? [];
                for (final sku in skus) {
                  if (sku['is_popular'] == true) {
                    popularItems.add({
                      'service_name': svc['name'],
                      'category': svc['category'],
                      'sku': sku,
                      'service': svc,
                    });
                  }
                }
              }

              if (popularItems.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final item = popularItems[i];
                    final sku = item['sku'];
                    return _popularServiceCard(
                      serviceName: item['service_name'],
                      skuTitle: sku['title'] ?? '',
                      price: (sku['price'] as num?)?.toDouble() ?? 0,
                      duration: sku['duration_mins'] ?? 0,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ServiceDetailScreen(service: item['service']),
                        ));
                      },
                    );
                  },
                  childCount: popularItems.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _categoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withAlpha(40), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _popularServiceCard({
    required String serviceName,
    required String skuTitle,
    required double price,
    required int duration,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star, color: Color(0xFFf39c12), size: 24),
          ),
          title: Text(skuTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('$serviceName • $duration mins', style: const TextStyle(fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('₹${price.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
              const Text('Book →', style: TextStyle(fontSize: 10, color: Color(0xFF4A90E2))),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCategory(String category) {
    final servicesAsync = ref.read(servicesProvider);
    servicesAsync.whenData((services) {
      final filtered = services.where((s) => s['category'] == category).toList();
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No services available in this category')),
        );
        return;
      }
      if (filtered.length == 1) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(service: filtered.first),
        ));
      } else {
        // Show sub-category picker for multiple services (e.g., home cleaning)
        _showSubCategorySheet(filtered);
      }
    });
  }

  void _showSubCategorySheet(List<dynamic> services) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Service', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...services.map((svc) => ListTile(
              leading: const Icon(Icons.cleaning_services, color: Color(0xFF4A90E2)),
              title: Text(svc['name'] ?? ''),
              subtitle: Text(svc['description'] ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ServiceDetailScreen(service: svc),
                ));
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showAddressPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final addressesAsync = ref.watch(addressesProvider);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Location', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () {
                        // Logic to add new address
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add New'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                addressesAsync.when(
                  data: (addresses) => Column(
                    children: addresses.map<Widget>((a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF4A90E2).withAlpha(30), shape: BoxShape.circle),
                        child: const Icon(Icons.home, color: Color(0xFF4A90E2), size: 20),
                      ),
                      title: Text(a['label'] ?? 'Address', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(a['address_line'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: a['is_default'] == true ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      onTap: () {
                        // Logic to set as default
                        Navigator.pop(ctx);
                      },
                    )).toList(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
