import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'booking_wizard_screen.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  final dynamic service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    final videoUrl = widget.service['video_url'];
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoPlayerController!.initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            autoPlay: false,
            looping: false,
            placeholder: _buildVideoPlaceholder(),
          );
        });
      });
    }
  }

  Widget _buildVideoPlaceholder() {
    final category = widget.service['category'] ?? '';
    return Container(
      color: _categoryColor(category),
      child: Center(
        child: Icon(_categoryIcon(category), size: 48, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final name = service['name'] ?? '';
    final description = service['description'] ?? '';
    final category = service['category'] ?? '';
    final sopSteps = (service['sop_steps'] as List?)?.cast<String>() ?? [];
    final requirements = (service['customer_requirements'] as List?)?.cast<String>() ?? [];
    final inclusions = (service['inclusions'] as List?)?.cast<String>() ?? [];
    final exclusions = (service['exclusions'] as List?)?.cast<String>() ?? [];
    final bestUseCases = (service['best_use_cases'] as List?)?.cast<String>() ?? [];
    final skus = (service['skus'] as List?) ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _categoryColor(category),
            flexibleSpace: FlexibleSpaceBar(
              background: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                  ? Chewie(controller: _chewieController!)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_categoryColor(category), _categoryColor(category).withAlpha(200)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Icon(_categoryIcon(category), size: 48, color: Colors.white),
                            const SizedBox(height: 8),
                            Text(
                              _videoPlayerController != null ? 'Loading Video...' : name,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // SOP Steps
          if (sopSteps.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: '📋 How It Works',
                child: Column(
                  children: sopSteps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: _categoryColor(category),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(step, style: const TextStyle(fontSize: 14, height: 1.4))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Customer Requirements
          if (requirements.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: '⚠️ Customer Requirements',
                child: _bulletList(requirements, Colors.orange.shade700),
              ),
            ),

          // Inclusions
          if (inclusions.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: '✅ What\'s Included',
                child: _bulletList(inclusions, Colors.green.shade700),
              ),
            ),

          // Exclusions
          if (exclusions.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: '❌ Not Included',
                child: _bulletList(exclusions, Colors.red.shade400),
              ),
            ),

          // Best Use Cases
          if (bestUseCases.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: '💡 Best For',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: bestUseCases.map((uc) => Chip(
                    label: Text(uc, style: const TextStyle(fontSize: 12)),
                    backgroundColor: _categoryColor(category).withAlpha(25),
                    side: BorderSide.none,
                  )).toList(),
                ),
              ),
            ),

          // SKUs / Pricing
          SliverToBoxAdapter(
            child: _section(
              title: '💰 Choose a Package',
              child: Column(
                children: skus.map<Widget>((sku) => _skuCard(context, ref, sku, category)).toList(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _bulletList(List<String> items, Color dotColor) {
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            Expanded(child: Text(item, style: const TextStyle(fontSize: 14, height: 1.3))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _skuCard(BuildContext context, WidgetRef ref, dynamic sku, String category) {
    final title = sku['title'] ?? '';
    final price = (sku['price'] as num?)?.toDouble() ?? 0;
    final duration = sku['duration_mins'] ?? 0;
    final isPopular = sku['is_popular'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPopular ? _categoryColor(category) : Colors.grey.shade200, width: isPopular ? 2 : 1),
        boxShadow: isPopular
            ? [BoxShadow(color: _categoryColor(category).withAlpha(30), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            if (isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _categoryColor(category),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Text('⏱ $duration mins'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('₹${price.toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _categoryColor(category))),
            GestureDetector(
              onTap: () => _navigateToBookingWizard(context, sku),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _categoryColor(category),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Book', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBookingWizard(BuildContext context, dynamic sku) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookingWizardScreen(
        service: widget.service,
        sku: sku,
      ),
    ));
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'VEHICLE_WASH': return const Color(0xFF4A90E2);
      case 'MONTHLY_PACKAGE': return const Color(0xFF27AE60);
      case 'PUC_CERTIFICATE': return const Color(0xFFE67E22);
      case 'HOME_CLEANING': return const Color(0xFF9B59B6);
      default: return Colors.grey;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'VEHICLE_WASH': return Icons.local_car_wash;
      case 'MONTHLY_PACKAGE': return Icons.calendar_month;
      case 'PUC_CERTIFICATE': return Icons.description_outlined;
      case 'HOME_CLEANING': return Icons.home_outlined;
      default: return Icons.category;
    }
  }
}
