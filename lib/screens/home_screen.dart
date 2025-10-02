// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:pastor_report/widgets/header.dart';
import '../../widgets/custom_drawer.dart'; // Ensure this points to the correct path of CustomDrawer

class HomeScreen extends StatelessWidget {
  final bool isAdmin; // Define the isAdmin parameter

  // Define the constructor with the required isAdmin parameter
  const HomeScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Admin Home' : 'User Home'),
      ),
      drawer: CustomDrawer(isAdmin: isAdmin), // Use the custom drawer widget
      body: Column(
        children: [
          const Header(
            title: 'PastorPro',
          ),
          Expanded(
            child: Center(
              child: Text(
                'Welcome ${isAdmin ? "Admin" : "User"} to Pastor Report App!',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
