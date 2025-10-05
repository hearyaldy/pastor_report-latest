import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/utils/app_colors.dart';
import 'package:pastor_report/utils/keyboard_utils.dart';
import 'package:intl/intl.dart';

class FinancialReportEditScreen extends StatefulWidget {
  final FinancialReport report;
  final Church church;
  final Function onUpdate;

  const FinancialReportEditScreen({
    Key? key,
    required this.report,
    required this.church,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<FinancialReportEditScreen> createState() =>
      _FinancialReportEditScreenState();
}

class _FinancialReportEditScreenState extends State<FinancialReportEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titheController = TextEditingController();
  final _offeringsController = TextEditingController();
  final _specialOfferingsController = TextEditingController();
  final _notesController = TextEditingController();

  // Focus nodes for form fields
  final _titheFocus = FocusNode();
  final _offeringsFocus = FocusNode();
  final _specialOfferingsFocus = FocusNode();
  final _notesFocus = FocusNode();

  String _status = '';
  bool _isSubmitting = false;
  bool _formLoaded = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data
    _titheController.text = widget.report.tithe.toString();
    _offeringsController.text = widget.report.offerings.toString();
    _specialOfferingsController.text =
        widget.report.specialOfferings.toString();
    _notesController.text = widget.report.notes ?? '';
    _status = widget.report.status;

    // Animate form in after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _formLoaded = true);
      }
    });
  }

  @override
  void dispose() {
    // Dispose controllers
    _titheController.dispose();
    _offeringsController.dispose();
    _specialOfferingsController.dispose();
    _notesController.dispose();

    // Dispose focus nodes
    _titheFocus.dispose();
    _offeringsFocus.dispose();
    _specialOfferingsFocus.dispose();
    _notesFocus.dispose();

    super.dispose();
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) {
      // Provide haptic feedback when validation fails
      HapticFeedback.lightImpact();
      return;
    }

    // Provide haptic feedback when starting the save process
    HapticFeedback.selectionClick();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Changes'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Are you sure you want to update this financial report?'),
                const SizedBox(height: 10),
                Text(
                  'Tithe: RM ${_titheController.text}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Offerings: RM ${_offeringsController.text}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Special Offerings: RM ${_specialOfferingsController.text}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Status: ${_status.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                ),
                child: const Text('SAVE'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Parse numeric values
      final tithe = double.parse(_titheController.text);
      final offerings = double.parse(_offeringsController.text);
      final specialOfferings = double.parse(_specialOfferingsController.text);
      final notes = _notesController.text.trim();

      // Create updated report object
      final updatedReport = widget.report.copyWith(
        tithe: tithe,
        offerings: offerings,
        specialOfferings: specialOfferings,
        notes: notes.isNotEmpty ? notes : null,
        status: _status,
      );

      // Save to Firestore
      await FinancialReportService().updateReport(updatedReport);

      // Notify parent of update
      widget.onUpdate(updatedReport);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated successfully')),
        );
      }

      // Go back to previous screen
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        title: const Text('Edit Financial Report'),
        elevation: 0,
      ),
      // Use Padding with resizeToAvoidBottomInset to handle keyboard
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primaryLight.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.church.churchName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Report for ${DateFormat('MMMM yyyy').format(widget.report.month)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Form with animations
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Animation wrapper
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: 1.0, // Start with full opacity
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutQuint,
                        transform: Matrix4.translationValues(0, 0, 0),
                        child: Column(
                          children: [
                            _buildTextFormField(
                              controller: _titheController,
                              labelText: 'Tithe (RM)',
                              icon: Icons.account_balance,
                              keyboardType: TextInputType.number,
                              focusNode: _titheFocus,
                              nextFocus: _offeringsFocus,
                            ),
                            const SizedBox(height: 20),
                            _buildTextFormField(
                              controller: _offeringsController,
                              labelText: 'Offerings (RM)',
                              icon: Icons.volunteer_activism,
                              keyboardType: TextInputType.number,
                              focusNode: _offeringsFocus,
                              nextFocus: _specialOfferingsFocus,
                            ),
                            const SizedBox(height: 20),
                            _buildTextFormField(
                              controller: _specialOfferingsController,
                              labelText: 'Special Offerings (RM)',
                              icon: Icons.card_giftcard,
                              keyboardType: TextInputType.number,
                              focusNode: _specialOfferingsFocus,
                              nextFocus: _notesFocus,
                            ),
                            const SizedBox(height: 20),
                            // Status dropdown
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _status,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  prefixIcon: Icon(Icons.info_outline),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'draft', child: Text('Draft')),
                                  DropdownMenuItem(
                                      value: 'submitted',
                                      child: Text('Submitted')),
                                  DropdownMenuItem(
                                      value: 'approved',
                                      child: Text('Approved')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _status = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTextFormField(
                              controller: _notesController,
                              labelText: 'Notes (Optional)',
                              icon: Icons.note_alt,
                              maxLines: 3,
                              focusNode: _notesFocus,
                              validator: null,
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _saveReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Text('SAVE CHANGES'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          // Improve accessibility with better label
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        // Auto-adjust view when this field has focus
        onTap: () {
          // Wait for keyboard to appear
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              // Ensure field is visible when keyboard appears
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        },
        // Handle next field navigation with keyboard
        textInputAction:
            nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (_) {
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          } else {
            KeyboardUtils.hideKeyboard(context);
          }
        },
        // Enable text selection
        enableInteractiveSelection: true,
        validator: validator ??
            (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a value';
              }
              if (keyboardType == TextInputType.number) {
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
              }
              return null;
            },
      ),
    );
  }
}
