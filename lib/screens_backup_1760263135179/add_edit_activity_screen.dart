// lib/screens/add_edit_activity_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pastor_report/models/activity_model.dart';
import 'package:pastor_report/services/activity_storage_service.dart';
import 'package:pastor_report/utils/constants.dart';

class AddEditActivityScreen extends StatefulWidget {
  final Activity? activity;

  const AddEditActivityScreen({
    super.key,
    this.activity,
  });

  @override
  State<AddEditActivityScreen> createState() => _AddEditActivityScreenState();
}

class _AddEditActivityScreenState extends State<AddEditActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activitiesController = TextEditingController();
  final _mileageController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationController = TextEditingController();
  final ActivityStorageService _storageService = ActivityStorageService.instance;

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditMode => widget.activity != null;

  @override
  void initState() {
    super.initState();

    if (_isEditMode) {
      final activity = widget.activity!;
      _selectedDate = activity.date;
      _activitiesController.text = activity.activities;
      _mileageController.text = activity.mileage.toString();
      _noteController.text = activity.note;
      _locationController.text = activity.location ?? '';
    }
  }

  @override
  void dispose() {
    _activitiesController.dispose();
    _mileageController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryLight,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final activity = Activity(
        id: _isEditMode ? widget.activity!.id : const Uuid().v4(),
        date: _selectedDate,
        activities: _activitiesController.text.trim(),
        mileage: double.parse(_mileageController.text.trim()),
        note: _noteController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        createdAt: _isEditMode ? widget.activity!.createdAt : DateTime.now(),
        updatedAt: _isEditMode ? DateTime.now() : null,
      );

      final bool success;
      if (_isEditMode) {
        success = await _storageService.updateActivity(activity);
      } else {
        success = await _storageService.addActivity(activity);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Activity updated successfully'
                : 'Activity added successfully'),
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Failed to update activity'
                : 'Failed to add activity'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Activity' : 'Add Activity'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Picker
              Card(
                child: InkWell(
                  onTap: _selectDate,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, MMMM dd, yyyy')
                                    .format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Activities Field
              TextFormField(
                controller: _activitiesController,
                decoration: InputDecoration(
                  labelText: 'Activities *',
                  hintText: 'Describe your daily activities',
                  prefixIcon: const Icon(Icons.event_note),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your activities';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Location Field
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location / Destination',
                  hintText: 'Enter location or destination',
                  prefixIcon: const Icon(Icons.location_on),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 16),

              // Mileage Field
              TextFormField(
                controller: _mileageController,
                decoration: InputDecoration(
                  labelText: 'Kilometers (km) *',
                  hintText: 'Enter kilometers traveled',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter kilometers';
                  }
                  final mileage = double.tryParse(value.trim());
                  if (mileage == null) {
                    return 'Please enter a valid number';
                  }
                  if (mileage < 0) {
                    return 'Kilometers cannot be negative';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Notes Field
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add any additional notes',
                  prefixIcon: const Icon(Icons.note),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'UPDATE ACTIVITY' : 'ADD ACTIVITY',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
