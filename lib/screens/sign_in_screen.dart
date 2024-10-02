// lib/screens/sign_in_screen.dart
import 'package:flutter/material.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  // Hardcoded users for demonstration
  final Map<String, String> _users = {
    'admin1': 'SAb_ADM@24',
    'admin2': 'SAB_adM@24',
    'user1': 'Sab_24@',
    'user2': 'SAB_24PR',
    'helmy': 'SAB_24PR',
    
  };

  void _signIn() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (_users.containsKey(username) && _users[username] == password) {
      if (username.startsWith('admin')) {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/departments');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid username or password'),
          backgroundColor: Color(0xFF1A4870),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Header section with image
              Container(
                height: 180,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/header_image.png'), // Ensure this image exists
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 16,
                      bottom: 50,
                      child: Text(
                        'Pastor Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 20,
                      child: Text(
                        _getCurrentDate(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: const TextStyle(color: Color(0xFF1F316F)),
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF1A4870)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF1A4870)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1F316F)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Color(0xFF1F316F)),
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFF1A4870)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF1A4870)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1F316F)),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: const Color(0xFF1A4870),
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B99C2),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Utility function to get the current formatted date
  String _getCurrentDate() {
    final now = DateTime.now();
    return '${_getDayOfWeek(now.weekday)} | ${now.day}-${now.month}-${now.year}';
  }

  // Utility function to get the day of the week
  String _getDayOfWeek(int weekday) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[weekday - 1];
  }
}