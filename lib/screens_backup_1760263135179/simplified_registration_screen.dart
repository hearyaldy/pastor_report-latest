// lib/screens/simplified_registration_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/utils/validators.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/theme.dart';
import 'package:pastor_report/widgets/custom_text_field.dart';

class SimplifiedRegistrationScreen extends StatefulWidget {
  const SimplifiedRegistrationScreen({super.key});

  @override
  State<SimplifiedRegistrationScreen> createState() =>
      _SimplifiedRegistrationScreenState();
}

class _SimplifiedRegistrationScreenState
    extends State<SimplifiedRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  String? _selectedMission;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  List<Mission> _missions = [];

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadMissions() async {
    try {
      setState(() => _isLoading = true);
      final missions = await MissionService.instance.getAllMissions();
      setState(() {
        _missions = missions;
        // Don't auto-select - force user to choose explicitly
        _selectedMission = null;
      });
    } catch (e) {
      print('Error loading missions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load missions: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _selectedMission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all required fields correctly')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get the selected mission details for debugging
      final selectedMissionObj = _missions.firstWhere(
        (m) => m.id == _selectedMission,
        orElse: () => _missions.first,
      );

      print('🔍 Registration Debug:');
      print('Selected Mission ID: $_selectedMission');
      print('Selected Mission Name: ${selectedMissionObj.name}');
      print('Available missions: ${_missions.map((m) => '${m.name} (${m.id})').join(', ')}');

      // Register with minimal info - only name, email, password, and mission
      await authProvider.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        mission: _selectedMission,
        // Don't set region, district, or churchId yet - will be set in onboarding
      );

      if (!mounted) return;

      // Show a message about the next steps
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Account created successfully! Complete your profile now.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to onboarding screen to complete profile
      Navigator.pushReplacementNamed(
        context,
        AppConstants.routeOnboarding,
      );
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;

      String errorMessage = 'Registration failed';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'This email is already in use by another account';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Password should be at least 6 characters';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'The email address is not valid';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: _isLoading && _missions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withOpacity(0.8),
                    AppTheme.primary.withOpacity(0.6),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.3, 0.6],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    constraints: BoxConstraints(
                      minHeight: screenHeight - MediaQuery.of(context).padding.top,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                          
                          // Back button and title
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 24, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Welcome card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.person_add,
                                  size: 40,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Welcome to Pastor Report',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Create your account to get started. You\'ll complete your profile in the next step.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Name Field
                                CustomTextField(
                                  controller: _nameController,
                                  labelText: 'Full Name',
                                  prefixIcon: Icons.person_outline,
                                  validator: Validators.validateName,
                                ),
                                const SizedBox(height: 20),

                                // Email Field
                                CustomTextField(
                                  controller: _emailController,
                                  labelText: 'Email Address',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: Validators.validateEmail,
                                ),
                                const SizedBox(height: 20),

                                // Password Field
                                CustomTextField(
                                  controller: _passwordController,
                                  labelText: 'Password',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  obscureText: _obscurePassword,
                                  validator: Validators.validatePassword,
                                ),
                                const SizedBox(height: 20),

                                // Confirm Password Field
                                CustomTextField(
                                  controller: _confirmPasswordController,
                                  labelText: 'Confirm Password',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  obscureText: _obscureConfirmPassword,
                                  validator: (value) => Validators.validateConfirmPassword(
                                    value,
                                    _passwordController.text,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Mission Dropdown
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.business_outlined, color: Colors.grey),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButtonFormField<String>(
                                            value: _selectedMission,
                                            decoration: const InputDecoration(
                                              labelText: 'Select Mission',
                                              border: InputBorder.none,
                                            ),
                                            isExpanded: true,
                                            items: _missions.map((mission) {
                                              return DropdownMenuItem<String>(
                                                value: mission.id,
                                                child: Text(mission.name),
                                              );
                                            }).toList(),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please select a mission';
                                              }
                                              return null;
                                            },
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedMission = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Register Button
                                SizedBox(
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _register,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Create Account',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Login Link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Already have an account?'),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushReplacementNamed(
                                          context,
                                          AppConstants.routeLogin,
                                        );
                                      },
                                      child: const Text('Log In'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
