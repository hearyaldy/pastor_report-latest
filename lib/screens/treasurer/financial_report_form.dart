import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/screens/treasurer/fam_form.dart';
import 'package:pastor_report/services/fam_service.dart';
import 'package:pastor_report/utils/web_wrapper.dart';

class FinancialReportForm extends StatefulWidget {
  final FinancialReport report;
  final Church church;
  final bool isNewReport;

  const FinancialReportForm({
    super.key,
    required this.report,
    required this.church,
    required this.isNewReport,
  });

  @override
  State<FinancialReportForm> createState() => _FinancialReportFormState();
}

class _FinancialReportFormState extends State<FinancialReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _titheController = TextEditingController();
  final _offeringsController = TextEditingController();
  final _specialOfferingsController = TextEditingController();
  final _receiptFromController = TextEditingController();
  final _receiptToController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_FinanceTypeEntry> _customEntries = [];

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
    _receiptFromController.text = widget.report.receiptNumberFrom ?? '';
    _receiptToController.text = widget.report.receiptNumberTo ?? '';
    _notesController.text = widget.report.notes ?? '';
    _status = widget.report.status;
    for (final e in widget.report.customFinanceTypes) {
      _customEntries.add(_FinanceTypeEntry(
        label: e['label'] as String? ?? '',
        amount: ((e['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
      ));
    }

    // Animate form in after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _formLoaded = true);
      }
    });
  }

  @override
  void dispose() {
    _titheController.dispose();
    _offeringsController.dispose();
    _specialOfferingsController.dispose();
    _receiptFromController.dispose();
    _receiptToController.dispose();
    _notesController.dispose();
    for (final e in _customEntries) {
      e.dispose();
    }
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
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required fields correctly'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      final receiptFrom = _receiptFromController.text.trim();
      final receiptTo = _receiptToController.text.trim();
      final customFinanceTypes = _customEntries
          .where((e) => e.labelCtrl.text.trim().isNotEmpty)
          .map((e) => {
                'label': e.labelCtrl.text.trim(),
                'amount': double.tryParse(e.amountCtrl.text) ?? 0.0,
              })
          .toList();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate ID if it's empty (for new reports)
      String reportId = widget.report.id;
      if (reportId.isEmpty) {
        reportId =
            '${widget.report.churchId}_${widget.report.month.year}_${widget.report.month.month}';
      }

      // Create updated report object
      final updatedReport = widget.report.copyWith(
        id: reportId,
        tithe: tithe,
        offerings: offerings,
        specialOfferings: specialOfferings,
        receiptNumberFrom: receiptFrom.isNotEmpty ? receiptFrom : null,
        receiptNumberTo: receiptTo.isNotEmpty ? receiptTo : null,
        customFinanceTypes: customFinanceTypes,
        notes: notes.isNotEmpty ? notes : null,
        status: _status,
        updatedAt: DateTime.now(),
        submittedAt:
            _status == 'submitted' ? DateTime.now() : widget.report.submittedAt,
      );

      // Save to Firestore
      try {
        debugPrint('💾 Saving financial report:');
        debugPrint('   Report ID: ${updatedReport.id}');
        debugPrint('   Status: ${updatedReport.status}');
        debugPrint('   Tithe: ${updatedReport.tithe}');
        debugPrint('   Offerings: ${updatedReport.offerings}');
        debugPrint('   Submitted At: ${updatedReport.submittedAt}');

        if (widget.isNewReport) {
          await FinancialReportService().createReport(updatedReport);
          debugPrint('✅ New report created successfully');
        } else {
          await FinancialReportService().updateReport(updatedReport);
          debugPrint('✅ Report updated successfully');
        }
      } catch (e) {
        debugPrint('❌ Financial report submission error: $e');
        print('Financial report submission error: $e');
        rethrow; // Rethrow to be caught by outer catch
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.isNewReport
                  ? 'Report created successfully'
                  : 'Report updated successfully')),
        );
      }

      // Go back to previous screen with success result
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Show detailed error message
      print('Financial Report Error: $e');
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error saving report: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {
                messenger.hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _navigateToFAM() async {
    try {
      final famService = FAMService();
      final existingFAM =
          await famService.getFAMDataByReportId(widget.report.id);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FAMForm(
            report: widget.report,
            famData: existingFAM,
          ),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FAM data updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing FAM: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        title: Text(widget.isNewReport
            ? 'Create Financial Report'
            : 'Edit Financial Report'),
        elevation: 0,
      ),
      body: WebWrapper(
          child: SingleChildScrollView(
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
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).cardColor,
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
                      opacity: _formLoaded ? 1.0 : 0.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutQuint,
                        transform: Matrix4.translationValues(
                            0, _formLoaded ? 0 : 50, 0),
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
                            ),
                            const SizedBox(height: 24),

                            // --- Additional Finance Types ---
                            _buildSectionHeader(
                              'Additional Finance Types',
                              Icons.add_chart,
                            ),
                            const SizedBox(height: 12),
                            ..._customEntries.asMap().entries.map((entry) {
                              final i = entry.key;
                              final item = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _buildInlineField(
                                        controller: item.labelCtrl,
                                        hint: 'Finance type name',
                                        keyboardType: TextInputType.text,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: _buildInlineField(
                                        controller: item.amountCtrl,
                                        hint: 'Amount (RM)',
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        prefixText: 'RM ',
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.redAccent),
                                      onPressed: () => setState(
                                          () => _customEntries.removeAt(i)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            TextButton.icon(
                              onPressed: () => setState(() =>
                                  _customEntries.add(_FinanceTypeEntry())),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add Finance Type'),
                            ),
                            const SizedBox(height: 20),

                            // --- Receipt Number Range ---
                            _buildSectionHeader(
                              'Receipt Number Range',
                              Icons.receipt_long,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInlineField(
                                    controller: _receiptFromController,
                                    hint: 'From (e.g. A001)',
                                    keyboardType: TextInputType.text,
                                    required: false,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child:
                                      Text('—', style: TextStyle(fontSize: 18)),
                                ),
                                Expanded(
                                  child: _buildInlineField(
                                    controller: _receiptToController,
                                    hint: 'To (e.g. A050)',
                                    keyboardType: TextInputType.text,
                                    required: false,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Status dropdown
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .shadowColor
                                        .withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
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
                              // Notes are optional, so no validation required
                              validator: (_) => null,
                            ),
                            const SizedBox(height: 32),
                            // FAM Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _navigateToFAM,
                                icon: const Icon(Icons.account_balance_wallet),
                                label: const Text(
                                    'MANAGE FINANCIAL ACTIVITIES (FAM)'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  side:
                                      BorderSide(color: AppColors.primaryLight),
                                  foregroundColor: AppColors.primaryLight,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
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
                                          strokeWidth: 3,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(widget.isNewReport
                                        ? 'CREATE REPORT'
                                        : 'UPDATE REPORT'),
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
      )),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    FormFieldValidator<String>? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator ??
            (value) {
              if (value == null || value.isEmpty) {
                return 'This field cannot be empty';
              }

              // If this is a numeric field
              if (keyboardType == TextInputType.number) {
                try {
                  final num = double.parse(value);
                  if (num < 0) {
                    return 'Please enter a positive number';
                  }
                } catch (e) {
                  return 'Please enter a valid number';
                }
              }

              return null;
            },
        onFieldSubmitted: (_) {
          if (nextFocus != null) {
            focusNode!.unfocus();
            nextFocus.requestFocus();
          }
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryLight),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    bool required = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefixText,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        validator: required
            ? (v) {
                if (v == null || v.isEmpty) return 'Required';
                return null;
              }
            : null,
      ),
    );
  }
}

class _FinanceTypeEntry {
  final TextEditingController labelCtrl;
  final TextEditingController amountCtrl;

  _FinanceTypeEntry({String label = '', String amount = '0.00'})
      : labelCtrl = TextEditingController(text: label),
        amountCtrl = TextEditingController(text: amount);

  void dispose() {
    labelCtrl.dispose();
    amountCtrl.dispose();
  }
}
