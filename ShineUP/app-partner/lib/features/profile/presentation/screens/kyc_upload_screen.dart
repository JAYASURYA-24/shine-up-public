import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dashboard/providers/dashboard_providers.dart';

class KYCUploadScreen extends ConsumerStatefulWidget {
  const KYCUploadScreen({super.key});

  @override
  ConsumerState<KYCUploadScreen> createState() => _KYCUploadScreenState();
}

class _KYCUploadScreenState extends ConsumerState<KYCUploadScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _categoryController = TextEditingController();
  final _aadhaarFrontController = TextEditingController();
  final _aadhaarBackController = TextEditingController();
  final _panController = TextEditingController();
  final _dlController = TextEditingController();
  final _homePhotoController = TextEditingController();

  bool _isLoading = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final profile = ref.read(profileProvider).value;
    if (profile != null) {
      _nameController.text = profile['name'] ?? '';
      _cityController.text = profile['city'] ?? '';
      _categoryController.text = profile['category'] ?? '';
      _aadhaarFrontController.text = profile['aadhaar_front'] ?? '';
      _aadhaarBackController.text = profile['aadhaar_back'] ?? '';
      _panController.text = profile['pan_url'] ?? '';
      _dlController.text = profile['driving_license'] ?? '';
      _homePhotoController.text = profile['home_photo_url'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _categoryController.dispose();
    _aadhaarFrontController.dispose();
    _aadhaarBackController.dispose();
    _panController.dispose();
    _dlController.dispose();
    _homePhotoController.dispose();
    super.dispose();
  }

  int get _completedFields {
    int count = 0;
    if (_aadhaarFrontController.text.isNotEmpty) count++;
    if (_aadhaarBackController.text.isNotEmpty) count++;
    if (_panController.text.isNotEmpty) count++;
    if (_dlController.text.isNotEmpty) count++;
    if (_homePhotoController.text.isNotEmpty) count++;
    return count;
  }

  Future<void> _submitKYC() async {
    setState(() => _isLoading = true);

    final result = await ref.read(apiClientProvider).submitKYC({
      'name': _nameController.text,
      'city': _cityController.text,
      'category': _categoryController.text,
      'aadhaar_front': _aadhaarFrontController.text,
      'aadhaar_back': _aadhaarBackController.text,
      'pan_url': _panController.text,
      'driving_license': _dlController.text,
      'home_photo_url': _homePhotoController.text,
    });

    setState(() => _isLoading = false);

    if (result != null) {
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC documents submitted for review! ✅'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit KYC. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC Documents')),
      body: Column(
        children: [
          // Progress indicator
          _buildProgress(),
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 3) {
                  setState(() => _currentStep++);
                } else {
                  _submitKYC();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep--);
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading ? null : details.onStepContinue,
                        child: Text(_currentStep == 3 ? 'Submit KYC' : 'Next'),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                // Step 1: Personal Info
                Step(
                  title: const Text('Personal Info'),
                  subtitle: const Text('Name, city & category'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      _buildTextField(_nameController, 'Full Name', Icons.person),
                      const SizedBox(height: 12),
                      _buildTextField(_cityController, 'City', Icons.location_city),
                      const SizedBox(height: 12),
                      _buildCategoryDropdown(),
                    ],
                  ),
                ),
                // Step 2: Aadhaar
                Step(
                  title: const Text('Aadhaar Card'),
                  subtitle: const Text('Front & back'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      _buildDocField(_aadhaarFrontController, 'Aadhaar Front URL', Icons.credit_card),
                      const SizedBox(height: 12),
                      _buildDocField(_aadhaarBackController, 'Aadhaar Back URL', Icons.credit_card),
                    ],
                  ),
                ),
                // Step 3: PAN & DL
                Step(
                  title: const Text('PAN & Driving License'),
                  subtitle: const Text('Identity documents'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      _buildDocField(_panController, 'PAN Card URL', Icons.badge),
                      const SizedBox(height: 12),
                      _buildDocField(_dlController, 'Driving License URL', Icons.directions_car),
                    ],
                  ),
                ),
                // Step 4: Home Photo
                Step(
                  title: const Text('Home Photo'),
                  subtitle: const Text('For address verification'),
                  isActive: _currentStep >= 3,
                  state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      _buildDocField(_homePhotoController, 'Home Photo URL', Icons.home),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final percentage = (_completedFields / 5 * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF0FFF4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documents: $_completedFields/5 uploaded',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _completedFields / 5,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    color: const Color(0xFF27AE60),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: percentage == 100 ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$percentage%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDocField(TextEditingController controller, String label, IconData icon) {
    final hasValue = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: hasValue ? Colors.green : Colors.grey),
        suffixIcon: hasValue
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: hasValue ? const Color(0xFFF0FFF4) : Colors.grey[50],
        helperText: 'Paste document image URL here',
        helperStyle: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = ['VEHICLE_WASH', 'MONTHLY_PACKAGE', 'PUC_CERTIFICATE', 'HOME_CLEANING', 'ACCESSORIES'];
    return DropdownButtonFormField<String>(
      value: _categoryController.text.isEmpty ? null : _categoryController.text,
      decoration: InputDecoration(
        labelText: 'Service Category',
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')))).toList(),
      onChanged: (val) => setState(() => _categoryController.text = val ?? ''),
    );
  }
}
