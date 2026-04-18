import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_providers.dart';

class JobExecutionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> job;

  const JobExecutionScreen({super.key, required this.job});

  @override
  ConsumerState<JobExecutionScreen> createState() => _JobExecutionScreenState();
}

class _JobExecutionScreenState extends ConsumerState<JobExecutionScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Photo URLs  (mock text inputs)
  final _selfieController = TextEditingController();
  final _beforePhotoController = TextEditingController();
  final _otpController = TextEditingController();
  final _afterPhotoController = TextEditingController();

  // Track uploaded photos
  bool _selfieUploaded = false;
  bool _beforeUploaded = false;
  bool _afterUploaded = false;

  String get _status => widget.job['status'] ?? '';
  String get _jobId => widget.job['id'] ?? '';

  @override
  void initState() {
    super.initState();
    // Determine current step based on booking status
    if (_status == 'IN_PROGRESS') {
      _currentStep = 3; // Jump to "Service In Progress"
    }
  }

  @override
  void dispose() {
    _selfieController.dispose();
    _beforePhotoController.dispose();
    _otpController.dispose();
    _afterPhotoController.dispose();
    super.dispose();
  }

  Future<void> _uploadPhoto(String type, String url) async {
    setState(() => _isLoading = true);
    final result = await ref.read(apiClientProvider).uploadPhoto(_jobId, type, url);
    setState(() {
      _isLoading = false;
      if (result != null) {
        if (type == 'SELFIE') _selfieUploaded = true;
        if (type == 'BEFORE') _beforeUploaded = true;
        if (type == 'AFTER') _afterUploaded = true;
      }
    });
  }

  Future<void> _startJobWithOTP() async {
    if (_otpController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid 4-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(apiClientProvider).startJob(_jobId, _otpController.text);
    setState(() => _isLoading = false);

    if (success) {
      ref.invalidate(jobsProvider);
      setState(() => _currentStep = 3);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job started! 🚀'), backgroundColor: Color(0xFF27AE60)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid OTP — ask the customer for the correct code')),
        );
      }
    }
  }

  Future<void> _completeJob() async {
    setState(() => _isLoading = true);
    final success = await ref.read(apiClientProvider).completeJob(_jobId);
    setState(() => _isLoading = false);

    if (success) {
      ref.invalidate(jobsProvider);
      if (mounted) {
        _showCompletionDialog();
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, color: Color(0xFF27AE60), size: 64),
            const SizedBox(height: 16),
            const Text('Job Completed! 🎉',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('₹${widget.job['total_amount']}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
            const SizedBox(height: 8),
            const Text('Payment has been recorded.', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Back to Jobs'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sku = widget.job['sku'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(sku['title'] ?? 'Job Execution'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _handleStepContinue,
        onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
        onStepTapped: (step) {
          if (step <= _currentStep) setState(() => _currentStep = step);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_getButtonText()),
                ),
                if (_currentStep > 0 && _currentStep < 4) ...[
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
          // Step 0: Check-in Selfie
          Step(
            title: const Text('Check-in Selfie'),
            subtitle: const Text('Take a selfie at customer location'),
            isActive: _currentStep >= 0,
            state: _selfieUploaded ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                _buildPhotoInput(
                  _selfieController,
                  'Selfie URL',
                  Icons.camera_front,
                  _selfieUploaded,
                ),
                if (_selfieUploaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text('Selfie uploaded', style: TextStyle(color: Colors.green, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Step 1: Before Photos
          Step(
            title: const Text('Before Photos'),
            subtitle: const Text('Photos before starting service'),
            isActive: _currentStep >= 1,
            state: _beforeUploaded ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                _buildPhotoInput(
                  _beforePhotoController,
                  'Before Photo URL',
                  Icons.photo_camera_outlined,
                  _beforeUploaded,
                ),
                if (_beforeUploaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text('Before photo uploaded', style: TextStyle(color: Colors.green, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Step 2: OTP Verification
          Step(
            title: const Text('Customer OTP'),
            subtitle: const Text('Get 4-digit code from customer'),
            isActive: _currentStep >= 2,
            state: _status == 'IN_PROGRESS' ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FFF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF27AE60)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ask the customer for their 4-digit OTP to start the service.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
                  decoration: InputDecoration(
                    hintText: '• • • •',
                    hintStyle: const TextStyle(letterSpacing: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),

          // Step 3: Service In Progress
          Step(
            title: const Text('Service In Progress'),
            subtitle: const Text('Performing the service'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service SOP Steps
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timer, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Service in progress...', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${sku['duration_mins'] ?? 60} mins',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Service Checklist:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ..._buildChecklist(),
              ],
            ),
          ),

          // Step 4: After Photos & Complete
          Step(
            title: const Text('After Photos & Complete'),
            subtitle: const Text('Final photos and mark done'),
            isActive: _currentStep >= 4,
            state: StepState.indexed,
            content: Column(
              children: [
                _buildPhotoInput(
                  _afterPhotoController,
                  'After Photo URL',
                  Icons.photo_camera_back,
                  _afterUploaded,
                ),
                if (_afterUploaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text('After photo uploaded', style: TextStyle(color: Colors.green, fontSize: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF27AE60), Color(0xFF2ECC71)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_rupee, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Amount', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('₹${widget.job['total_amount']}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
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

  String _getButtonText() {
    switch (_currentStep) {
      case 0:
        return _selfieUploaded ? 'Next' : 'Upload & Next';
      case 1:
        return _beforeUploaded ? 'Next' : 'Upload & Next';
      case 2:
        return 'Verify OTP & Start';
      case 3:
        return 'Continue to Finish';
      case 4:
        return _afterUploaded ? 'Complete Job' : 'Upload & Complete';
      default:
        return 'Next';
    }
  }

  void _handleStepContinue() {
    switch (_currentStep) {
      case 0: // Selfie
        if (!_selfieUploaded && _selfieController.text.isNotEmpty) {
          _uploadPhoto('SELFIE', _selfieController.text).then((_) {
            if (_selfieUploaded) setState(() => _currentStep = 1);
          });
        } else if (_selfieUploaded) {
          setState(() => _currentStep = 1);
        }
        break;
      case 1: // Before
        if (!_beforeUploaded && _beforePhotoController.text.isNotEmpty) {
          _uploadPhoto('BEFORE', _beforePhotoController.text).then((_) {
            if (_beforeUploaded) setState(() => _currentStep = 2);
          });
        } else if (_beforeUploaded) {
          setState(() => _currentStep = 2);
        }
        break;
      case 2: // OTP
        _startJobWithOTP();
        break;
      case 3: // In Progress
        setState(() => _currentStep = 4);
        break;
      case 4: // After & Complete
        if (!_afterUploaded && _afterPhotoController.text.isNotEmpty) {
          _uploadPhoto('AFTER', _afterPhotoController.text).then((_) {
            _completeJob();
          });
        } else {
          _completeJob();
        }
        break;
    }
  }

  Widget _buildPhotoInput(TextEditingController controller, String label, IconData icon, bool isUploaded) {
    return TextField(
      controller: controller,
      enabled: !isUploaded,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: isUploaded ? Colors.green : null),
        suffixIcon: isUploaded ? const Icon(Icons.check_circle, color: Colors.green) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isUploaded ? const Color(0xFFF0FFF4) : Colors.grey[50],
        helperText: 'Paste photo URL (mock — camera capture in future)',
        helperStyle: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
    );
  }

  List<Widget> _buildChecklist() {
    final sopSteps = [
      'Inspect the area/vehicle',
      'Set up equipment',
      'Perform the service',
      'Quality check',
      'Clean up workspace',
    ];

    return sopSteps.map((step) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(Icons.circle_outlined, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(step, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ],
        ),
      );
    }).toList();
  }
}
