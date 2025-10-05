import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  final FinancialReportService _reportService = FinancialReportService();
  final ChurchService _churchService = ChurchService();
  final DistrictService _districtService = DistrictService();
  final RegionService _regionService = RegionService();

  List<FinancialReport> _reports = [];
  List<Church> _churches = [];
  List<District> _districts = [];
  List<Region> _regions = [];

  String? _selectedRegionId;
  String? _selectedDistrictId;
  String? _selectedChurchId;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load organizational data
      _regions = await _regionService.getAllRegions();
      _districts = await _districtService.getAllDistricts();
      _churches = await _churchService.getAllChurches();

      // Load financial reports based on filters
      if (_selectedChurchId != null) {
        final report = await _reportService.getReportByChurchAndMonth(
          _selectedChurchId!,
          _selectedMonth,
        );
        _reports = report != null ? [report] : [];
      } else if (_selectedDistrictId != null) {
        final allReports = await _reportService.getReportsByDistrict(_selectedDistrictId!);
        _reports = allReports.where((r) {
          return r.month.year == _selectedMonth.year &&
              r.month.month == _selectedMonth.month;
        }).toList();
      } else {
        // Load all reports and filter by month
        final allReports = <FinancialReport>[];
        for (var church in _churches) {
          final churchReports = await _reportService.getReportsByChurch(church.id);
          allReports.addAll(churchReports);
        }
        _reports = allReports.where((r) {
          return r.month.year == _selectedMonth.year &&
              r.month.month == _selectedMonth.month;
        }).toList();
      }

      _reports.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getChurchName(String? churchId) {
    if (churchId == null) return 'N/A';
    final church = _churches.firstWhere(
      (c) => c.id == churchId,
      orElse: () => Church(
        id: '',
        userId: '',
        churchName: 'Unknown',
        elderName: '',
        elderEmail: '',
        elderPhone: '',
        status: ChurchStatus.church,
        createdAt: DateTime.now(),
      ),
    );
    return church.churchName;
  }

  String _getDistrictName(String? districtId) {
    if (districtId == null) return 'N/A';
    final district = _districts.firstWhere(
      (d) => d.id == districtId,
      orElse: () => District(
        id: '',
        name: 'Unknown',
        code: '',
        regionId: '',
        missionId: '',
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    return district.name;
  }

  void _showReportDetails(FinancialReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Financial Report Details'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Church', _getChurchName(report.churchId)),
                _buildDetailRow('District', _getDistrictName(report.districtId)),
                _buildDetailRow('Month', DateFormat('MMMM yyyy').format(report.month)),
                const Divider(),
                _buildDetailRow('Tithe', 'RM ${report.tithe.toStringAsFixed(2)}'),
                _buildDetailRow('Offerings', 'RM ${report.offerings.toStringAsFixed(2)}'),
                _buildDetailRow('Special Offerings', 'RM ${report.specialOfferings.toStringAsFixed(2)}'),
                const Divider(),
                _buildDetailRow(
                  'Total',
                  'RM ${report.totalFinancial.toStringAsFixed(2)}',
                  isBold: true,
                ),
                const Divider(),
                _buildDetailRow('Status', report.status.toUpperCase()),
                _buildDetailRow(
                  'Submitted',
                  DateFormat('dd MMM yyyy HH:mm').format(report.submittedAt),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final totalTithe = _reports.fold<double>(0, (sum, r) => sum + r.tithe);
    final totalOfferings = _reports.fold<double>(0, (sum, r) => sum + r.offerings);
    final totalSpecial = _reports.fold<double>(0, (sum, r) => sum + r.specialOfferings);
    final grandTotal = totalTithe + totalOfferings + totalSpecial;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                const SizedBox(width: 16),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRegionId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Region',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Regions'),
                          ),
                          ..._regions.map((region) {
                            return DropdownMenuItem(
                              value: region.id,
                              child: Text('${region.name} (${region.code})'),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRegionId = value;
                            _selectedDistrictId = null;
                            _selectedChurchId = null;
                          });
                          _loadData();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDistrictId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by District',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Districts'),
                          ),
                          ..._districts
                              .where((d) =>
                                  _selectedRegionId == null ||
                                  d.regionId == _selectedRegionId)
                              .map((district) {
                            return DropdownMenuItem(
                              value: district.id,
                              child: Text('${district.name} (${district.code})'),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrictId = value;
                            _selectedChurchId = null;
                          });
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedChurchId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Church',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Churches'),
                    ),
                    ..._churches
                        .where((c) =>
                            (_selectedDistrictId == null ||
                                c.districtId == _selectedDistrictId) &&
                            (_selectedRegionId == null ||
                                c.regionId == _selectedRegionId))
                        .map((church) {
                      return DropdownMenuItem(
                        value: church.id,
                        child: Text(church.churchName),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedChurchId = value;
                    });
                    _loadData();
                  },
                ),
              ],
            ),
          ),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Tithe',
                    'RM ${totalTithe.toStringAsFixed(2)}',
                    Icons.account_balance,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Offerings',
                    'RM ${totalOfferings.toStringAsFixed(2)}',
                    Icons.volunteer_activism,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryCard(
                    'Special Offerings',
                    'RM ${totalSpecial.toStringAsFixed(2)}',
                    Icons.card_giftcard,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryCard(
                    'Grand Total',
                    'RM ${grandTotal.toStringAsFixed(2)}',
                    Icons.monetization_on,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Reports list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? const Center(child: Text('No reports found for this period'))
                    : ListView.builder(
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: report.status == 'submitted'
                                    ? Colors.green
                                    : Colors.orange,
                                child: Icon(
                                  report.status == 'submitted'
                                      ? Icons.check
                                      : Icons.pending,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                _getChurchName(report.churchId),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('District: ${_getDistrictName(report.districtId)}'),
                                  Text('Total: RM ${report.totalFinancial.toStringAsFixed(2)}'),
                                  Text(
                                    'Submitted: ${DateFormat('dd MMM yyyy').format(report.submittedAt)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: report.status == 'submitted'
                                          ? Colors.green[100]
                                          : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      report.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: report.status == 'submitted'
                                            ? Colors.green[900]
                                            : Colors.orange[900],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.visibility),
                                    onPressed: () => _showReportDetails(report),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
