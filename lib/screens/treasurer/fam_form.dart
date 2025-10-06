import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pastor_report/models/fam_model.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/services/fam_service.dart';
import 'package:pastor_report/utils/app_colors.dart';
import 'package:uuid/uuid.dart';

class FAMForm extends StatefulWidget {
  final FinancialReport report;
  final FinancialActivityManagement? famData;

  const FAMForm({
    super.key,
    required this.report,
    this.famData,
  });

  @override
  State<FAMForm> createState() => _FAMFormState();
}

class _FAMFormState extends State<FAMForm> {
  final _formKey = GlobalKey<FormState>();
  final _famService = FAMService();
  final _uuid = const Uuid();

  // Income Controllers
  final _buildingFundController = TextEditingController();
  final _welfareFundController = TextEditingController();
  final _missionFundController = TextEditingController();
  final _educationFundController = TextEditingController();
  final _youthFundController = TextEditingController();
  final _childrenFundController = TextEditingController();
  final _womenMinistryFundController = TextEditingController();
  final _menMinistryFundController = TextEditingController();
  final _seniorMinistryFundController = TextEditingController();
  final _musicMinistryFundController = TextEditingController();
  final _otherIncomeController = TextEditingController();

  // Expense Controllers
  final _maintenanceFundController = TextEditingController();
  final _utilitiesFundController = TextEditingController();
  final _insuranceFundController = TextEditingController();
  final _salariesController = TextEditingController();
  final _rentController = TextEditingController();
  final _suppliesController = TextEditingController();
  final _transportationController = TextEditingController();
  final _communicationController = TextEditingController();
  final _printingController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _otherExpensesController = TextEditingController();

  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFAMData();
  }

  Future<void> _loadFAMData() async {
    if (widget.famData != null) {
      _populateControllers(widget.famData!);
    } else {
      // Try to load existing FAM data for this report
      try {
        final existingFAM =
            await _famService.getFAMDataByReportId(widget.report.id);
        if (existingFAM != null) {
          _populateControllers(existingFAM);
        }
      } catch (e) {
        // No existing data, continue with empty form
      }
    }
    setState(() => _isLoading = false);
  }

  void _populateControllers(FinancialActivityManagement fam) {
    _buildingFundController.text = fam.buildingFund?.toString() ?? '';
    _welfareFundController.text = fam.welfareFund?.toString() ?? '';
    _missionFundController.text = fam.missionFund?.toString() ?? '';
    _educationFundController.text = fam.educationFund?.toString() ?? '';
    _youthFundController.text = fam.youthFund?.toString() ?? '';
    _childrenFundController.text = fam.childrenFund?.toString() ?? '';
    _womenMinistryFundController.text = fam.womenMinistryFund?.toString() ?? '';
    _menMinistryFundController.text = fam.menMinistryFund?.toString() ?? '';
    _seniorMinistryFundController.text =
        fam.seniorMinistryFund?.toString() ?? '';
    _musicMinistryFundController.text = fam.musicMinistryFund?.toString() ?? '';
    _otherIncomeController.text = fam.otherIncome?.toString() ?? '';

    _maintenanceFundController.text = fam.maintenanceFund?.toString() ?? '';
    _utilitiesFundController.text = fam.utilitiesFund?.toString() ?? '';
    _insuranceFundController.text = fam.insuranceFund?.toString() ?? '';
    _salariesController.text = fam.salaries?.toString() ?? '';
    _rentController.text = fam.rent?.toString() ?? '';
    _suppliesController.text = fam.supplies?.toString() ?? '';
    _transportationController.text = fam.transportation?.toString() ?? '';
    _communicationController.text = fam.communication?.toString() ?? '';
    _printingController.text = fam.printing?.toString() ?? '';
    _equipmentController.text = fam.equipment?.toString() ?? '';
    _otherExpensesController.text = fam.otherExpenses?.toString() ?? '';

    _notesController.text = fam.notes ?? '';
  }

  @override
  void dispose() {
    // Dispose all controllers
    _buildingFundController.dispose();
    _welfareFundController.dispose();
    _missionFundController.dispose();
    _educationFundController.dispose();
    _youthFundController.dispose();
    _childrenFundController.dispose();
    _womenMinistryFundController.dispose();
    _menMinistryFundController.dispose();
    _seniorMinistryFundController.dispose();
    _musicMinistryFundController.dispose();
    _otherIncomeController.dispose();

    _maintenanceFundController.dispose();
    _utilitiesFundController.dispose();
    _insuranceFundController.dispose();
    _salariesController.dispose();
    _rentController.dispose();
    _suppliesController.dispose();
    _transportationController.dispose();
    _communicationController.dispose();
    _printingController.dispose();
    _equipmentController.dispose();
    _otherExpensesController.dispose();

    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveFAMData() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    HapticFeedback.selectionClick();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm FAM Data'),
            content: const Text(
                'Are you sure you want to save this Financial Activity Management data?'),
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

    if (!confirmed) return;

    setState(() => _isSubmitting = true);

    try {
      final famData = FinancialActivityManagement(
        id: widget.famData?.id ?? _uuid.v4(),
        reportId: widget.report.id,
        buildingFund: double.tryParse(_buildingFundController.text),
        welfareFund: double.tryParse(_welfareFundController.text),
        missionFund: double.tryParse(_missionFundController.text),
        educationFund: double.tryParse(_educationFundController.text),
        youthFund: double.tryParse(_youthFundController.text),
        childrenFund: double.tryParse(_childrenFundController.text),
        womenMinistryFund: double.tryParse(_womenMinistryFundController.text),
        menMinistryFund: double.tryParse(_menMinistryFundController.text),
        seniorMinistryFund: double.tryParse(_seniorMinistryFundController.text),
        musicMinistryFund: double.tryParse(_musicMinistryFundController.text),
        maintenanceFund: double.tryParse(_maintenanceFundController.text),
        utilitiesFund: double.tryParse(_utilitiesFundController.text),
        insuranceFund: double.tryParse(_insuranceFundController.text),
        otherIncome: double.tryParse(_otherIncomeController.text),
        salaries: double.tryParse(_salariesController.text),
        rent: double.tryParse(_rentController.text),
        supplies: double.tryParse(_suppliesController.text),
        transportation: double.tryParse(_transportationController.text),
        communication: double.tryParse(_communicationController.text),
        printing: double.tryParse(_printingController.text),
        equipment: double.tryParse(_equipmentController.text),
        otherExpenses: double.tryParse(_otherExpensesController.text),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdAt: widget.famData?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.famData == null) {
        await _famService.createFAMData(famData);
      } else {
        await _famService.updateFAMData(famData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FAM data saved successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving FAM data: $e'),
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

  Widget _buildCurrencyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryLight),
          prefixText: 'RM ',
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        title: const Text('Financial Activity Management'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isSubmitting ? null : _saveFAMData,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Income Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Income Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCurrencyField(
                      controller: _buildingFundController,
                      label: 'Building Fund',
                      icon: Icons.business,
                    ),
                    _buildCurrencyField(
                      controller: _welfareFundController,
                      label: 'Welfare Fund',
                      icon: Icons.favorite,
                    ),
                    _buildCurrencyField(
                      controller: _missionFundController,
                      label: 'Mission Fund',
                      icon: Icons.explore,
                    ),
                    _buildCurrencyField(
                      controller: _educationFundController,
                      label: 'Education Fund',
                      icon: Icons.school,
                    ),
                    _buildCurrencyField(
                      controller: _youthFundController,
                      label: 'Youth Ministry Fund',
                      icon: Icons.people,
                    ),
                    _buildCurrencyField(
                      controller: _childrenFundController,
                      label: 'Children Ministry Fund',
                      icon: Icons.child_care,
                    ),
                    _buildCurrencyField(
                      controller: _womenMinistryFundController,
                      label: 'Women Ministry Fund',
                      icon: Icons.woman,
                    ),
                    _buildCurrencyField(
                      controller: _menMinistryFundController,
                      label: 'Men Ministry Fund',
                      icon: Icons.man,
                    ),
                    _buildCurrencyField(
                      controller: _seniorMinistryFundController,
                      label: 'Senior Ministry Fund',
                      icon: Icons.elderly,
                    ),
                    _buildCurrencyField(
                      controller: _musicMinistryFundController,
                      label: 'Music Ministry Fund',
                      icon: Icons.music_note,
                    ),
                    _buildCurrencyField(
                      controller: _otherIncomeController,
                      label: 'Other Income',
                      icon: Icons.add_circle,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Expenses Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_down, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Expense Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCurrencyField(
                      controller: _maintenanceFundController,
                      label: 'Maintenance',
                      icon: Icons.build,
                    ),
                    _buildCurrencyField(
                      controller: _utilitiesFundController,
                      label: 'Utilities',
                      icon: Icons.electrical_services,
                    ),
                    _buildCurrencyField(
                      controller: _insuranceFundController,
                      label: 'Insurance',
                      icon: Icons.security,
                    ),
                    _buildCurrencyField(
                      controller: _salariesController,
                      label: 'Salaries',
                      icon: Icons.work,
                    ),
                    _buildCurrencyField(
                      controller: _rentController,
                      label: 'Rent',
                      icon: Icons.home,
                    ),
                    _buildCurrencyField(
                      controller: _suppliesController,
                      label: 'Supplies',
                      icon: Icons.inventory,
                    ),
                    _buildCurrencyField(
                      controller: _transportationController,
                      label: 'Transportation',
                      icon: Icons.directions_car,
                    ),
                    _buildCurrencyField(
                      controller: _communicationController,
                      label: 'Communication',
                      icon: Icons.phone,
                    ),
                    _buildCurrencyField(
                      controller: _printingController,
                      label: 'Printing',
                      icon: Icons.print,
                    ),
                    _buildCurrencyField(
                      controller: _equipmentController,
                      label: 'Equipment',
                      icon: Icons.construction,
                    ),
                    _buildCurrencyField(
                      controller: _otherExpensesController,
                      label: 'Other Expenses',
                      icon: Icons.more_horiz,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Notes Section
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
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    prefixIcon: Icon(Icons.note_alt),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 3,
                ),
              ),

              const SizedBox(height: 32),

              // Summary Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Total Income', _calculateTotalIncome()),
                    _buildSummaryRow(
                        'Total Expenses', _calculateTotalExpenses()),
                    Divider(color: Colors.blue[200]),
                    _buildSummaryRow('Net Amount', _calculateNetAmount(),
                        isTotal: true),
                  ],
                ),
              ),

              const SizedBox(height: 100), // Space for bottom navigation
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: Colors.blue[700],
            ),
          ),
          Text(
            'RM ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: amount >= 0 ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalIncome() {
    return [
      _buildingFundController.text,
      _welfareFundController.text,
      _missionFundController.text,
      _educationFundController.text,
      _youthFundController.text,
      _childrenFundController.text,
      _womenMinistryFundController.text,
      _menMinistryFundController.text,
      _seniorMinistryFundController.text,
      _musicMinistryFundController.text,
      _otherIncomeController.text,
    ].fold(0.0, (sum, value) => sum + (double.tryParse(value) ?? 0.0));
  }

  double _calculateTotalExpenses() {
    return [
      _maintenanceFundController.text,
      _utilitiesFundController.text,
      _insuranceFundController.text,
      _salariesController.text,
      _rentController.text,
      _suppliesController.text,
      _transportationController.text,
      _communicationController.text,
      _printingController.text,
      _equipmentController.text,
      _otherExpensesController.text,
    ].fold(0.0, (sum, value) => sum + (double.tryParse(value) ?? 0.0));
  }

  double _calculateNetAmount() {
    return _calculateTotalIncome() - _calculateTotalExpenses();
  }
}
