// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _fontSize = 16.0;
  String _fontStyle = 'Roboto';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Font Size', style: TextStyle(fontSize: 18)),
            Slider(
              value: _fontSize,
              min: 10,
              max: 30,
              divisions: 20,
              label: _fontSize.round().toString(),
              onChanged: (value) {
                setState(() {
                  _fontSize = value;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text('Font Style', style: TextStyle(fontSize: 18)),
            DropdownButton<String>(
              value: _fontStyle,
              items: <String>['Roboto', 'Arial', 'Courier', 'Times New Roman']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: TextStyle(fontSize: _fontSize)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _fontStyle = newValue!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}