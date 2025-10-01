import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CheckUserApp());
}

class CheckUserApp extends StatelessWidget {
  const CheckUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CheckUserScreen(),
    );
  }
}

class CheckUserScreen extends StatefulWidget {
  @override
  _CheckUserScreenState createState() => _CheckUserScreenState();
}

class _CheckUserScreenState extends State<CheckUserScreen> {
  String result = "Checking...";

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    try {
      // Query for the specific user by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'heary@hopetv.asia')
          .get();

      if (userQuery.docs.isEmpty) {
        setState(() {
          result = "User not found in database.";
        });
        return;
      }

      final userData = userQuery.docs.first.data();

      // Print user data
      setState(() {
        result = "User found:\n"
            "Email: ${userData['email']}\n"
            "Display Name: ${userData['displayName']}\n"
            "Mission: ${userData['mission'] ?? 'Not set'}\n"
            "District: ${userData['district'] ?? 'Not set'}\n"
            "Role: ${userData['role'] ?? 'Not set'}\n"
            "Is Admin: ${userData['isAdmin'] ?? false}\n";
      });

      // Check departments associated with user's mission
      if (userData['mission'] != null) {
        final departmentsQuery = await FirebaseFirestore.instance
            .collection('departments')
            .where('mission', isEqualTo: userData['mission'])
            .get();

        if (departmentsQuery.docs.isEmpty) {
          setState(() {
            result +=
                "\nNo departments found for mission: ${userData['mission']}";
          });
        } else {
          setState(() {
            result += "\nDepartments for ${userData['mission']}:\n";
            for (var doc in departmentsQuery.docs) {
              result += "- ${doc.data()['name']} (ID: ${doc.id})\n";
            }
          });
        }
      } else {
        setState(() {
          result += "\nUser has no mission assigned - cannot show departments.";
        });
      }
    } catch (e) {
      setState(() {
        result = "Error checking user: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Check'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Text(
              result,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
