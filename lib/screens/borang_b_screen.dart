// lib/screens/borang_b_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_storage_service.dart';
import 'package:pastor_report/services/borang_b_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/utils/constants.dart';

class BorangBScreen extends StatefulWidget {
  const BorangBScreen({super.key});

  @override
  State<BorangBScreen> createState() => _BorangBScreenState();
}

class _BorangBScreenState extends State<BorangBScreen> {
  final BorangBStorageService _storageService = BorangBStorageService.instance;
  final BorangBService _exportService = BorangBService.instance;

  DateTime _selectedMonth = DateTime.now();
  BorangBData? _currentData;
  bool _isLoading = true;
  bool _isExporting = false;

  // Controllers for all fields
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadData();
  }

  void _initializeControllers() {
    // Initialize all controllers
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    final data = await _storageService.getReportByMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    if (data != null && data.userId == userId) {
      _currentData = data;
      _populateFields(data);
    } else {
      _currentData = null;
      _clearFields();
    }

    setState(() => _isLoading = false);
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

  void _clearFields() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
  }

  Future<void> _saveData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final data = BorangBData(
      id: _currentData?.id ?? const Uuid().v4(),
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
      createdAt: _currentData?.createdAt ?? DateTime.now(),
    );

    final success = await _storageService.saveReport(data);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_currentData == null ? 'Report saved successfully' : 'Report updated successfully'),
        ),
      );
      _loadData(); // Reload to get the saved data
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving report'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportReport() async {
    if (_currentData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the report first')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not found');
      }

      final file = await _exportService.generateBorangB(
        borangBData: _currentData!,
        user: user,
        month: _selectedMonth,
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Borang B - ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Borang B exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadData();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borang B - Monthly Report'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveData,
            tooltip: 'Save Report',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _isExporting ? null : _exportReport,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMonthSelector(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          'Church Membership Statistics',
                          Icons.people,
                          Colors.blue,
                          _buildMembershipFields(),
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Baptisms & Professions',
                          Icons.water_drop,
                          Colors.cyan,
                          _buildBaptismsFields(),
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Church Services',
                          Icons.church,
                          Colors.purple,
                          _buildServicesFields(),
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Visitations',
                          Icons.home,
                          Colors.green,
                          _buildVisitationsFields(),
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Special Events',
                          Icons.event,
                          Colors.orange,
                          _buildEventsFields(),
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Literature Distribution',
                          Icons.book,
                          Colors.brown,
                          _buildLiteratureFields(),
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Tithes & Offerings (RM)',
                          Icons.attach_money,
                          Colors.teal,
                          _buildFinancialFields(),
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Additional Information',
                          Icons.notes,
                          Colors.indigo,
                          _buildTextFields(),
                        ),
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> fields) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...fields,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMembershipFields() {
    return [
      _buildNumberField('membersBeginning', 'Members at Beginning'),
      _buildNumberField('membersReceived', 'Members Received'),
      _buildNumberField('membersTransferredIn', 'Transferred In'),
      _buildNumberField('membersTransferredOut', 'Transferred Out'),
      _buildNumberField('membersDropped', 'Dropped/Removed'),
      _buildNumberField('membersDeceased', 'Deceased'),
      _buildNumberField('membersEnd', 'Members at End'),
    ];
  }

  List<Widget> _buildBaptismsFields() {
    return [
      _buildNumberField('baptisms', 'Baptisms'),
      _buildNumberField('professionOfFaith', 'Professions of Faith'),
    ];
  }

  List<Widget> _buildServicesFields() {
    return [
      _buildNumberField('sabbathServices', 'Sabbath Services'),
      _buildNumberField('prayerMeetings', 'Prayer Meetings'),
      _buildNumberField('bibleStudies', 'Bible Studies'),
      _buildNumberField('evangelisticMeetings', 'Evangelistic Meetings'),
    ];
  }

  List<Widget> _buildVisitationsFields() {
    return [
      _buildNumberField('homeVisitations', 'Home Visitations'),
      _buildNumberField('hospitalVisitations', 'Hospital Visitations'),
      _buildNumberField('prisonVisitations', 'Prison Visitations'),
    ];
  }

  List<Widget> _buildEventsFields() {
    return [
      _buildNumberField('weddings', 'Weddings'),
      _buildNumberField('funerals', 'Funerals'),
      _buildNumberField('dedications', 'Baby Dedications'),
    ];
  }

  List<Widget> _buildLiteratureFields() {
    return [
      _buildNumberField('booksDistributed', 'Books Distributed'),
      _buildNumberField('magazinesDistributed', 'Magazines Distributed'),
      _buildNumberField('tractsDistributed', 'Tracts Distributed'),
    ];
  }

  List<Widget> _buildFinancialFields() {
    return [
      _buildCurrencyField('tithe', 'Tithe'),
      _buildCurrencyField('offerings', 'Offerings'),
    ];
  }

  List<Widget> _buildTextFields() {
    return [
      _buildTextField('otherActivities', 'Other Activities', maxLines: 3),
      _buildTextField('challenges', 'Challenges Faced', maxLines: 3),
      _buildTextField('remarks', 'Remarks', maxLines: 3),
    ];
  }

  Widget _buildNumberField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[key],
        autofocus: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }

  Widget _buildCurrencyField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[key],
        autofocus: false,
        decoration: InputDecoration(
          labelText: label,
          prefixText: 'RM ',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
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
      child: TextField(
        controller: _controllers[key],
        autofocus: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _saveData,
        icon: const Icon(Icons.save),
        label: Text(_currentData == null ? 'Save Report' : 'Update Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
