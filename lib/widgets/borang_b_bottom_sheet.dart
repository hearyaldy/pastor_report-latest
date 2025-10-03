import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_storage_service.dart';
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
      'membersBeginning', 'membersReceived', 'membersTransferredIn',
      'membersTransferredOut', 'membersDropped', 'membersDeceased', 'membersEnd',
      'baptisms', 'professionOfFaith',
      'sabbathServices', 'prayerMeetings', 'bibleStudies', 'evangelisticMeetings',
      'homeVisitations', 'hospitalVisitations', 'prisonVisitations',
      'weddings', 'funerals', 'dedications',
      'booksDistributed', 'magazinesDistributed', 'tractsDistributed',
      'tithe', 'offerings',
      'otherActivities', 'challenges', 'remarks',
    ];

    for (final field in fields) {
      _controllers[field] = TextEditingController();
    }
  }

  void _populateFields(BorangBData data) {
    _controllers['membersBeginning']!.text = data.membersBeginning.toString();
    _controllers['membersReceived']!.text = data.membersReceived.toString();
    _controllers['membersTransferredIn']!.text = data.membersTransferredIn.toString();
    _controllers['membersTransferredOut']!.text = data.membersTransferredOut.toString();
    _controllers['membersDropped']!.text = data.membersDropped.toString();
    _controllers['membersDeceased']!.text = data.membersDeceased.toString();
    _controllers['membersEnd']!.text = data.membersEnd.toString();
    _controllers['baptisms']!.text = data.baptisms.toString();
    _controllers['professionOfFaith']!.text = data.professionOfFaith.toString();
    _controllers['sabbathServices']!.text = data.sabbathServices.toString();
    _controllers['prayerMeetings']!.text = data.prayerMeetings.toString();
    _controllers['bibleStudies']!.text = data.bibleStudies.toString();
    _controllers['evangelisticMeetings']!.text = data.evangelisticMeetings.toString();
    _controllers['homeVisitations']!.text = data.homeVisitations.toString();
    _controllers['hospitalVisitations']!.text = data.hospitalVisitations.toString();
    _controllers['prisonVisitations']!.text = data.prisonVisitations.toString();
    _controllers['weddings']!.text = data.weddings.toString();
    _controllers['funerals']!.text = data.funerals.toString();
    _controllers['dedications']!.text = data.dedications.toString();
    _controllers['booksDistributed']!.text = data.booksDistributed.toString();
    _controllers['magazinesDistributed']!.text = data.magazinesDistributed.toString();
    _controllers['tractsDistributed']!.text = data.tractsDistributed.toString();
    _controllers['tithe']!.text = data.tithe.toStringAsFixed(2);
    _controllers['offerings']!.text = data.offerings.toStringAsFixed(2);
    _controllers['otherActivities']!.text = data.otherActivities;
    _controllers['challenges']!.text = data.challenges;
    _controllers['remarks']!.text = data.remarks;
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    final data = BorangBData(
      id: widget.existingData?.id ?? const Uuid().v4(),
      month: DateTime(_selectedMonth.year, _selectedMonth.month),
      userId: userId,
      membersBeginning: int.tryParse(_controllers['membersBeginning']!.text) ?? 0,
      membersReceived: int.tryParse(_controllers['membersReceived']!.text) ?? 0,
      membersTransferredIn: int.tryParse(_controllers['membersTransferredIn']!.text) ?? 0,
      membersTransferredOut: int.tryParse(_controllers['membersTransferredOut']!.text) ?? 0,
      membersDropped: int.tryParse(_controllers['membersDropped']!.text) ?? 0,
      membersDeceased: int.tryParse(_controllers['membersDeceased']!.text) ?? 0,
      membersEnd: int.tryParse(_controllers['membersEnd']!.text) ?? 0,
      baptisms: int.tryParse(_controllers['baptisms']!.text) ?? 0,
      professionOfFaith: int.tryParse(_controllers['professionOfFaith']!.text) ?? 0,
      sabbathServices: int.tryParse(_controllers['sabbathServices']!.text) ?? 0,
      prayerMeetings: int.tryParse(_controllers['prayerMeetings']!.text) ?? 0,
      bibleStudies: int.tryParse(_controllers['bibleStudies']!.text) ?? 0,
      evangelisticMeetings: int.tryParse(_controllers['evangelisticMeetings']!.text) ?? 0,
      homeVisitations: int.tryParse(_controllers['homeVisitations']!.text) ?? 0,
      hospitalVisitations: int.tryParse(_controllers['hospitalVisitations']!.text) ?? 0,
      prisonVisitations: int.tryParse(_controllers['prisonVisitations']!.text) ?? 0,
      weddings: int.tryParse(_controllers['weddings']!.text) ?? 0,
      funerals: int.tryParse(_controllers['funerals']!.text) ?? 0,
      dedications: int.tryParse(_controllers['dedications']!.text) ?? 0,
      booksDistributed: int.tryParse(_controllers['booksDistributed']!.text) ?? 0,
      magazinesDistributed: int.tryParse(_controllers['magazinesDistributed']!.text) ?? 0,
      tractsDistributed: int.tryParse(_controllers['tractsDistributed']!.text) ?? 0,
      tithe: double.tryParse(_controllers['tithe']!.text) ?? 0.0,
      offerings: double.tryParse(_controllers['offerings']!.text) ?? 0.0,
      otherActivities: _controllers['otherActivities']!.text,
      challenges: _controllers['challenges']!.text,
      remarks: _controllers['remarks']!.text,
      createdAt: widget.existingData?.createdAt ?? DateTime.now(),
    );

    final success = await BorangBStorageService.instance.saveReport(data);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving report'),
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
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Report',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(
                                _selectedMonth.year,
                                _selectedMonth.month - 1,
                              );
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(
                                _selectedMonth.year,
                                _selectedMonth.month + 1,
                              );
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSection('Church Membership', Icons.people, Colors.blue, [
                        _buildNumberField('membersBeginning', 'Members at Beginning'),
                        _buildNumberField('membersReceived', 'Members Received'),
                        _buildNumberField('membersTransferredIn', 'Transferred In'),
                        _buildNumberField('membersTransferredOut', 'Transferred Out'),
                        _buildNumberField('membersDropped', 'Dropped/Removed'),
                        _buildNumberField('membersDeceased', 'Deceased'),
                        _buildNumberField('membersEnd', 'Members at End'),
                      ]),
                      const SizedBox(height: 16),

                      _buildSection('Baptisms & Professions', Icons.water_drop, Colors.cyan, [
                        _buildNumberField('baptisms', 'Baptisms'),
                        _buildNumberField('professionOfFaith', 'Professions of Faith'),
                      ]),
                      const SizedBox(height: 16),

                      _buildSection('Church Services', Icons.church, Colors.purple, [
                        _buildNumberField('sabbathServices', 'Sabbath Services'),
                        _buildNumberField('prayerMeetings', 'Prayer Meetings'),
                        _buildNumberField('bibleStudies', 'Bible Studies'),
                        _buildNumberField('evangelisticMeetings', 'Evangelistic Meetings'),
                      ]),
                      const SizedBox(height: 16),

                      _buildSection('Visitations', Icons.home, Colors.green, [
                        _buildNumberField('homeVisitations', 'Home Visitations'),
                        _buildNumberField('hospitalVisitations', 'Hospital Visitations'),
                        _buildNumberField('prisonVisitations', 'Prison Visitations'),
                      ]),
                      const SizedBox(height: 16),

                      _buildSection('Special Events', Icons.event, Colors.orange, [
                        _buildNumberField('weddings', 'Weddings'),
                        _buildNumberField('funerals', 'Funerals'),
                        _buildNumberField('dedications', 'Baby Dedications'),
                      ]),
                      const SizedBox(height: 16),

                      _buildSection('Literature', Icons.book, Colors.brown, [
                        _buildNumberField('booksDistributed', 'Books Distributed'),
                        _buildNumberField('magazinesDistributed', 'Magazines Distributed'),
                        _buildNumberField('tractsDistributed', 'Tracts Distributed'),
                      ]),
                      const SizedBox(height: 16),

                      _buildSection('Tithes & Offerings (RM)', Icons.attach_money, Colors.teal, [
                        _buildCurrencyField('tithe', 'Tithe'),
                        _buildCurrencyField('offerings', 'Offerings'),
                      ]),
                      const SizedBox(height: 16),

                      _buildSection('Additional Information', Icons.notes, Colors.indigo, [
                        _buildTextField('otherActivities', 'Other Activities', maxLines: 3),
                        _buildTextField('challenges', 'Challenges Faced', maxLines: 3),
                        _buildTextField('remarks', 'Remarks', maxLines: 3),
                      ]),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // Save Button (Fixed at bottom)
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
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveData,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Report'),
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
        );
      },
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> fields) {
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
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }
}
