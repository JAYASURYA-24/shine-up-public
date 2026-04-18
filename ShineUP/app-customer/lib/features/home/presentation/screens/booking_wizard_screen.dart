import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/home_providers.dart';
import 'payment_summary_screen.dart';

class BookingWizardScreen extends ConsumerStatefulWidget {
  final dynamic service;
  final dynamic sku;

  const BookingWizardScreen({super.key, required this.service, required this.sku});

  @override
  ConsumerState<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends ConsumerState<BookingWizardScreen> {
  int _currentStep = 0;

  dynamic _selectedVehicle;
  dynamic _selectedAddress;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  List<dynamic> _availableSlots = [];
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoadingSlots = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final slots = await ref.read(apiClientProvider).getSlots(dateStr, widget.sku['id']);
    if (mounted) {
      setState(() {
        _availableSlots = slots;
        _selectedSlot = null;
        _isLoadingSlots = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book ${widget.sku['title']}'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _selectedVehicle == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vehicle')));
            return;
          }
          if (_currentStep == 1 && _selectedAddress == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an address')));
            return;
          }
          if (_currentStep == 2 && _selectedSlot == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a time slot')));
            return;
          }

          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            // Proceed to Payment
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PaymentSummaryScreen(
                service: widget.service,
                sku: widget.sku,
                vehicle: _selectedVehicle,
                address: _selectedAddress,
                slotStart: _selectedSlot!,
              ),
            ));
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(isLastStep ? 'Proceed to Payment' : 'Continue'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Select Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildVehicleSelection(),
          ),
          Step(
            title: const Text('Service Location', style: TextStyle(fontWeight: FontWeight.bold)),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildAddressSelection(),
          ),
          Step(
            title: const Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold)),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.editing : StepState.indexed,
            content: _buildSlotSelection(),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelection() {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    
    return vehiclesAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading vehicles: $e'),
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return const Text('No vehicles added yet.'); // In a real app, provide add button
        }
        return Column(
          children: vehicles.map<Widget>((v) {
            final isSelected = _selectedVehicle != null && _selectedVehicle['id'] == v['id'];
            return RadioListTile(
              value: v['id'],
              groupValue: _selectedVehicle?['id'],
              onChanged: (val) {
                setState(() => _selectedVehicle = v);
              },
              title: Text(v['vehicle_number']),
              subtitle: Text('${v['vehicle_type']} • ${v['model_name']}'),
              secondary: Icon(v['vehicle_type'] == '4W' ? Icons.directions_car : Icons.two_wheeler, color: isSelected ? const Color(0xFF4A90E2) : Colors.grey),
              activeColor: const Color(0xFF4A90E2),
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAddressSelection() {
    final addressesAsync = ref.watch(addressesProvider);
    
    return addressesAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading addresses: $e'),
      data: (addresses) {
        return Column(
          children: [
            if (addresses.isEmpty)
               const Text('No addresses added yet.'), // In a real app, provide add button
            ...addresses.map<Widget>((a) {
              final isSelected = _selectedAddress != null && _selectedAddress['id'] == a['id'];
              return RadioListTile(
                value: a['id'],
                groupValue: _selectedAddress?['id'],
                onChanged: (val) {
                  setState(() => _selectedAddress = a);
                },
                title: Text(a['label'] ?? 'Address'),
                subtitle: Text(a['address_line']),
                secondary: Icon(Icons.location_on, color: isSelected ? const Color(0xFF4A90E2) : Colors.grey),
                activeColor: const Color(0xFF4A90E2),
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSlotSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selector Hook
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index + 1));
              final isSelected = date.day == _selectedDate.day;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                  _fetchSlots();
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat('E').format(date), style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12)),
                      Text('${date.day}', style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        const Text('Available Times', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_isLoadingSlots)
          const Center(child: CircularProgressIndicator())
        else if (_availableSlots.isEmpty)
          const Text('No slots available for this date. Try another day.', style: TextStyle(color: Colors.red))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableSlots.map((slotStr) {
              final slotTime = DateTime.parse(slotStr).toLocal();
              final isSelected = _selectedSlot == slotStr;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedSlot = slotStr);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4A90E2).withAlpha(25) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade300, width: isSelected ? 2 : 1),
                  ),
                  child: Text(
                    DateFormat('hh:mm a').format(slotTime),
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF4A90E2) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
