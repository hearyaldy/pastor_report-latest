import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/utils/constants.dart';

class BorangBBottomSheet extends StatefulWidget {
  final DateTime? initialMonth;
  final BorangBData? existingData;

  const BorangBBottomSheet({
    super.key,
    this.initialMonth,
    this.existingData,
  });

  @override
  State<BorangBBottomSheet> createState() => _BorangBBottomSheetState();
}

class _BorangBBottomSheetState extends State<BorangBBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  DateTime _selectedMonth = DateTime.now();
  bool _isSaving = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth ?? DateTime.now();
    _initializeControllers();
    if (widget.existingData != null) {
      _populateFields(widget.existingData!);
    }
  }

  void _initializeControllers() {
    final fields = [
      'membersBeginning',
      'membersReceived',
      'membersTransferredIn',
      'membersTransferredOut',
      'membersDropped',
      'membersDeceased',
      'membersEnd',
      'baptisms',
      'professionOfFaith',
      'sabbathServices',
      'prayerMeetings',
      'bibleStudies',
      'evangelisticMeetings',
      'homeVisitations',
      'hospitalVisitations',
      'prisonVisitations',
      'weddings',
      'funerals',
      'dedications',
      'booksDistributed',
      'magazinesDistributed',
      'tractsDistributed',
      'tithe',
      'offerings',
      'otherActivities',
      'challenges',
      'remarks',
    ];

    for (final field in fields) {
      _controllers[field] = TextEditingController();
    }
  }

  void _populateFields(BorangBData data) {
    _controllers['membersBeginning']!.text = data.membersBeginning.toString();
    _controllers['membersReceived']!.text = data.membersReceived.toString();
    _controllers['membersTransferredIn']!.text =
        data.membersTransferredIn.toString();
    _controllers['membersTransferredOut']!.text =
        data.membersTransferredOut.toString();
    _controllers['membersDropped']!.text = data.membersDropped.toString();
    _controllers['membersDeceased']!.text = data.membersDeceased.toString();
    _controllers['membersEnd']!.text = data.membersEnd.toString();
    _controllers['baptisms']!.text = data.baptisms.toString();
    _controllers['professionOfFaith']!.text = data.professionOfFaith.toString();
    _controllers['sabbathServices']!.text = data.sabbathServices.toString();
    _controllers['prayerMeetings']!.text = data.prayerMeetings.toString();
    _controllers['bibleStudies']!.text = data.bibleStudies.toString();
    _controllers['evangelisticMeetings']!.text =
        data.evangelisticMeetings.toString();
    _controllers['homeVisitations']!.text = data.homeVisitations.toString();
    _controllers['hospitalVisitations']!.text =
        data.hospitalVisitations.toString();
    _controllers['prisonVisitations']!.text = data.prisonVisitations.toString();
    _controllers['weddings']!.text = data.weddings.toString();
    _controllers['funerals']!.text = data.funerals.toString();
    _controllers['dedications']!.text = data.dedications.toString();
    _controllers['booksDistributed']!.text = data.booksDistributed.toString();
    _controllers['magazinesDistributed']!.text =
        data.magazinesDistributed.toString();
    _controllers['tractsDistributed']!.text = data.tractsDistributed.toString();
    _controllers['tithe']!.text = data.tithe.toString();
    _controllers['offerings']!.text = data.offerings.toString();
    _controllers['otherActivities']!.text = data.otherActivities;
    _controllers['challenges']!.text = data.challenges;
    _controllers['remarks']!.text = data.remarks;
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    // Save as draft
    await _saveOrSubmitData(isSubmission: false);
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Submit Report'),
            content: const Text(
                'Are you sure you want to submit this report? Once submitted, it will be visible to administrators and ministerial secretaries.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    // Submit the report
    await _saveOrSubmitData(isSubmission: true);
  }

  Future<void> _saveOrSubmitData({required bool isSubmission}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) return;

    final data = BorangBData(
      id: widget.existingData?.id ?? const Uuid().v4(),
      month: DateTime(_selectedMonth.year, _selectedMonth.month),
      userId: user.uid,
      userName: user.displayName,
      missionId: user.mission,
      districtId: user.district,
      churchId: user.churchId,
      status: isSubmission ? ReportStatus.submitted : ReportStatus.draft,
      submittedAt: isSubmission ? DateTime.now() : null,
      membersBeginning:
          int.tryParse(_controllers['membersBeginning']!.text) ?? 0,
      membersReceived: int.tryParse(_controllers['membersReceived']!.text) ?? 0,
      membersTransferredIn:
          int.tryParse(_controllers['membersTransferredIn']!.text) ?? 0,
      membersTransferredOut:
          int.tryParse(_controllers['membersTransferredOut']!.text) ?? 0,
      membersDropped: int.tryParse(_controllers['membersDropped']!.text) ?? 0,
      membersDeceased: int.tryParse(_controllers['membersDeceased']!.text) ?? 0,
      membersEnd: int.tryParse(_controllers['membersEnd']!.text) ?? 0,
      baptisms: int.tryParse(_controllers['baptisms']!.text) ?? 0,
      professionOfFaith:
          int.tryParse(_controllers['professionOfFaith']!.text) ?? 0,
      sabbathServices: int.tryParse(_controllers['sabbathServices']!.text) ?? 0,
      prayerMeetings: int.tryParse(_controllers['prayerMeetings']!.text) ?? 0,
      bibleStudies: int.tryParse(_controllers['bibleStudies']!.text) ?? 0,
      evangelisticMeetings:
          int.tryParse(_controllers['evangelisticMeetings']!.text) ?? 0,
      homeVisitations: int.tryParse(_controllers['homeVisitations']!.text) ?? 0,
      hospitalVisitations:
          int.tryParse(_controllers['hospitalVisitations']!.text) ?? 0,
      prisonVisitations:
          int.tryParse(_controllers['prisonVisitations']!.text) ?? 0,
      weddings: int.tryParse(_controllers['weddings']!.text) ?? 0,
      funerals: int.tryParse(_controllers['funerals']!.text) ?? 0,
      dedications: int.tryParse(_controllers['dedications']!.text) ?? 0,
      booksDistributed:
          int.tryParse(_controllers['booksDistributed']!.text) ?? 0,
      magazinesDistributed:
          int.tryParse(_controllers['magazinesDistributed']!.text) ?? 0,
      tractsDistributed:
          int.tryParse(_controllers['tractsDistributed']!.text) ?? 0,
      tithe: double.tryParse(_controllers['tithe']!.text) ?? 0.0,
      offerings: double.tryParse(_controllers['offerings']!.text) ?? 0.0,
      otherActivities: _controllers['otherActivities']!.text,
      challenges: _controllers['challenges']!.text,
      remarks: _controllers['remarks']!.text,
      createdAt: widget.existingData?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await BorangBFirestoreService.instance.saveReport(data);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isSubmission
                  ? 'Report submitted successfully'
                  : 'Report saved as draft')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSubmission
                ? 'Failed to submit report'
                : 'Failed to save report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle and title
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      children: [
                        const Icon(Icons.assignment, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Monthly Ministerial Report',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedMonth,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              initialEntryMode:
                                  DatePickerEntryMode.calendarOnly,
                              initialDatePickerMode: DatePickerMode.year,
                              selectableDayPredicate: (date) {
                                // Only allow the first day of each month
                                return date.day == 1;
                              },
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _selectedMonth = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    children: [
                      // Church Membership Statistics
                      _buildSection(
                        'Church Membership',
                        Icons.people,
                        Colors.blue.shade800,
                        [
                          _buildNumberField('membersBeginning',
                              'Members at beginning of month'),
                          _buildNumberField(
                              'membersReceived', 'New members received'),
                          _buildNumberField(
                              'membersTransferredIn', 'Members transferred in'),
                          _buildNumberField('membersTransferredOut',
                              'Members transferred out'),
                          _buildNumberField(
                              'membersDropped', 'Members dropped'),
                          _buildNumberField(
                              'membersDeceased', 'Members deceased'),
                          _buildNumberField(
                              'membersEnd', 'Members at end of month'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Baptisms
                      _buildSection(
                        'Baptisms and Professions of Faith',
                        Icons.water_drop,
                        Colors.teal.shade700,
                        [
                          _buildNumberField('baptisms', 'Number of baptisms'),
                          _buildNumberField(
                              'professionOfFaith', 'Professions of faith'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Church Services
                      _buildSection(
                        'Church Services',
                        Icons.church,
                        Colors.purple.shade700,
                        [
                          _buildNumberField(
                              'sabbathServices', 'Sabbath services conducted'),
                          _buildNumberField(
                              'prayerMeetings', 'Prayer meetings conducted'),
                          _buildNumberField(
                              'bibleStudies', 'Bible studies conducted'),
                          _buildNumberField('evangelisticMeetings',
                              'Evangelistic meetings conducted'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Visitations
                      _buildSection(
                        'Visitations',
                        Icons.home_work,
                        Colors.orange.shade800,
                        [
                          _buildNumberField(
                              'homeVisitations', 'Home visitations'),
                          _buildNumberField(
                              'hospitalVisitations', 'Hospital visitations'),
                          _buildNumberField(
                              'prisonVisitations', 'Prison visitations'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Special Events
                      _buildSection(
                        'Special Events',
                        Icons.celebration,
                        Colors.pink.shade700,
                        [
                          _buildNumberField('weddings', 'Weddings conducted'),
                          _buildNumberField('funerals', 'Funerals conducted'),
                          _buildNumberField(
                              'dedications', 'Baby dedications conducted'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Literature
                      _buildSection(
                        'Literature Distribution',
                        Icons.menu_book,
                        Colors.brown.shade700,
                        [
                          _buildNumberField(
                              'booksDistributed', 'Books distributed'),
                          _buildNumberField(
                              'magazinesDistributed', 'Magazines distributed'),
                          _buildNumberField(
                              'tractsDistributed', 'Tracts distributed'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Tithes and Offerings
                      _buildSection(
                        'Tithes and Offerings',
                        Icons.attach_money,
                        Colors.green.shade800,
                        [
                          _buildCurrencyField('tithe', 'Tithe collected'),
                          _buildCurrencyField(
                              'offerings', 'Offerings collected'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Other Activities, Challenges, and Remarks
                      _buildSection(
                        'Additional Information',
                        Icons.notes,
                        Colors.grey.shade800,
                        [
                          _buildTextField('otherActivities', 'Other activities',
                              maxLines: 3),
                          _buildTextField('challenges', 'Challenges faced',
                              maxLines: 3),
                          _buildTextField('remarks', 'Additional remarks',
                              maxLines: 3),
                        ],
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // Buttons (Fixed at bottom)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Save as Draft Button
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed:
                              (_isSaving || _isSubmitting) ? null : _saveData,
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Saving...' : 'Save Draft'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primaryLight),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Submit Button
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              (_isSaving || _isSubmitting) ? null : _submitData,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send),
                          label:
                              Text(_isSubmitting ? 'Submitting...' : 'Submit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...fields,
      ],
    );
  }

  Widget _buildNumberField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }

  Widget _buildCurrencyField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: label,
          prefixText: 'RM ',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
      ),
    );
  }

  Widget _buildTextField(String key, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        maxLines: maxLines,
      ),
    );
  }
}
