// lib/screens/borang_b_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';
import 'package:pastor_report/services/borang_b_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/web_wrapper.dart';

class BorangBScreen extends StatefulWidget {
  const BorangBScreen({super.key});

  @override
  State<BorangBScreen> createState() => _BorangBScreenState();
}

class _BorangBScreenState extends State<BorangBScreen> {
  final BorangBFirestoreService _firestoreService =
      BorangBFirestoreService.instance;
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    final data = await _firestoreService.getReportByUserAndMonth(
      userId,
      _selectedMonth.year,
      _selectedMonth.month,
    );

    if (data != null) {
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

  Future<void> _saveData({bool asSubmission = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Block submission if profile is incomplete (district required for non-mission roles)
    if (asSubmission) {
      final isMissionLevel = user.userRole == UserRole.ministerialSecretary ||
          user.userRole == UserRole.officer ||
          user.userRole == UserRole.director ||
          user.userRole == UserRole.missionAdmin ||
          user.userRole == UserRole.editor ||
          user.userRole == UserRole.admin ||
          user.userRole == UserRole.superAdmin;

      if (!isMissionLevel && (user.district == null || user.district!.isEmpty)) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 48),
            title: const Text('Profile Incomplete'),
            content: const Text(
              'Your profile is missing a district assignment.\n\n'
              'Please complete your profile setup first. If your district is not available, '
              'use the onboarding screen to request it from an admin.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // If submitting, show confirmation dialog
    if (asSubmission && _currentData?.status != ReportStatus.submitted) {
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
                  backgroundColor: Theme.of(context).colorScheme.primary),
              child: const Text('Submit'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final data = BorangBData(
      id: _currentData?.id ?? const Uuid().v4(),
      month: DateTime(_selectedMonth.year, _selectedMonth.month),
      userId: user.uid,
      userName: user.displayName,
      missionId: user.mission,
      districtId: user.district,
      churchId: user.churchId,
      status: asSubmission
          ? ReportStatus.submitted
          : (_currentData?.status ?? ReportStatus.draft),
      submittedAt: asSubmission ? DateTime.now() : _currentData?.submittedAt,
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
      createdAt: _currentData?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await _firestoreService.saveReport(data);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.onPrimary),
              const SizedBox(width: 12),
              Text(asSubmission
                  ? 'Report submitted successfully'
                  : _currentData == null
                      ? 'Report saved as draft'
                      : 'Report updated successfully'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData(); // Reload to get the saved data
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.onError),
              const SizedBox(width: 12),
              Text(asSubmission
                  ? 'Error submitting report'
                  : 'Error saving report'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _viewReport() {
    if (_currentData == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    // Get mission name from user data
    final missionName = user?.mission != null
        ? (AppConstants.missions.firstWhere(
            (m) => m['id'] == user?.mission,
            orElse: () => {'name': user?.mission ?? 'Unknown'},
          )['name'])
        : null;

    Navigator.pushNamed(
      context,
      '/borang-b-preview',
      arguments: {
        'data': _currentData,
        'month': _selectedMonth,
        'districtName': user?.district,
        'missionName': missionName,
      },
    );
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

      await _exportService.generateAndShareBorangB(
        borangBData: _currentData!,
        user: user,
        month: _selectedMonth,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: WebWrapper(
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Borang B - Monthly Report'),
                  if (_currentData != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          _currentData!.status == ReportStatus.submitted
                              ? Icons.check_circle
                              : Icons.edit,
                          size: 12,
                          color: colorScheme.onPrimary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentData!.status == ReportStatus.submitted
                              ? 'Submitted'
                              : 'Draft',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.preview),
                  onPressed: _currentData == null ? null : _viewReport,
                  tooltip: 'View Report',
                ),
                if (_currentData?.status != ReportStatus.submitted)
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _saveData(asSubmission: true),
                    tooltip: 'Submit Report',
                  ),
                IconButton(
                  icon: const Icon(Icons.file_download),
                  onPressed: _isExporting ? null : _exportReport,
                  tooltip: 'Export to Excel',
                ),
              ],
            ),
            SliverToBoxAdapter(child: _buildMonthSelector()),
          ],
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection('Church Membership Statistics', Icons.people, colorScheme.primary, _buildMembershipFields()),
                      const SizedBox(height: 16),
                      _buildSection('Baptisms & Professions', Icons.water_drop, colorScheme.primary, _buildBaptismsFields()),
                      const SizedBox(height: 16),
                      _buildSection('Church Services', Icons.church, colorScheme.primary, _buildServicesFields()),
                      const SizedBox(height: 16),
                      _buildSection('Visitations', Icons.home, colorScheme.primary, _buildVisitationsFields()),
                      const SizedBox(height: 16),
                      _buildSection('Special Events', Icons.event, colorScheme.primary, _buildEventsFields()),
                      const SizedBox(height: 16),
                      _buildSection('Literature Distribution', Icons.book, colorScheme.primary, _buildLiteratureFields()),
                      const SizedBox(height: 16),
                      _buildSection('Tithes & Offerings (RM)', Icons.attach_money, colorScheme.primary, _buildFinancialFields()),
                      const SizedBox(height: 16),
                      _buildSection('Additional Information', Icons.notes, colorScheme.primary, _buildTextFields()),
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> fields) {
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
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
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
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
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
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        ),
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildSaveButton() {
    final isDraft = _currentData?.status != ReportStatus.submitted;

    // If already submitted, show update button only
    if (!isDraft) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _saveData,
          icon: const Icon(Icons.save),
          label: const Text('Update Submitted Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // If draft or new, show both Save Draft and Submit buttons
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _saveData,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Draft'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _saveData(asSubmission: true),
              icon: const Icon(Icons.send),
              label: const Text('Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
