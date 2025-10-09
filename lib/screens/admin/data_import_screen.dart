// lib/screens/admin/data_import_screen.dart
import 'package:flutter/material.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/data_import_util.dart';

class DataImportScreen extends StatefulWidget {
  const DataImportScreen({Key? key}) : super(key: key);

  @override
  State<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends State<DataImportScreen> {
  bool _isLoading = false;
  String _status = '';
  List<String> _details = [];
  int _total = 0;
  int _created = 0;
  int _updated = 0;
  int _errors = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Import Utility'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('North Sabah Mission Churches Import',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                        'This will import church data from the updated NSM_Churches_Updated.json file to Firebase.',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    if (!_isLoading)
                      ElevatedButton.icon(
                        onPressed: _importNSMChurches,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Start Import Process'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
            if (_status.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Import Results',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Divider(),
                      Text(_status,
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Total: $_total',
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text('Created: $_created',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.green,
                                  )),
                      Text('Updated: $_updated',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.blue,
                                  )),
                      Text('Errors: $_errors',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: _errors > 0 ? Colors.red : Colors.green,
                              )),
                      if (_details.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Details:',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: ListView.builder(
                            itemCount: _details.length,
                            itemBuilder: (context, index) {
                              final detail = _details[index];
                              Color color = Colors.black;
                              if (detail.startsWith('Created')) {
                                color = Colors.green;
                              } else if (detail.startsWith('Updated')) {
                                color = Colors.blue;
                              } else if (detail.startsWith('Error')) {
                                color = Colors.red;
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  detail,
                                  style: TextStyle(color: color),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _importNSMChurches() async {
    setState(() {
      _isLoading = true;
      _status = 'Importing data...';
      _details = [];
    });

    try {
      final result = await DataImportUtil.importNSMChurches(context);

      setState(() {
        _isLoading = false;
        _status = result['errors'] > 0
            ? 'Import completed with errors'
            : 'Import completed successfully';
        _total = result['total'];
        _created = result['created'];
        _updated = result['updated'];
        _errors = result['errors'];
        _details = List<String>.from(result['details']);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
        _errors = 1;
      });
    }
  }
}
