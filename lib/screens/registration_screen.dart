import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/utils/theme.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/church_model.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _selectedMission;
  String? _selectedRegion;
  String? _selectedDistrict;
  String? _selectedChurch;
  String? _selectedRole;

  List<Mission> _missions = [];
  List<Region> _regions = [];
  List<District> _districts = [];
  List<Church> _churches = [];

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadMissions() async {
    setState(() => _isLoading = true);
    try {
      _missions = await MissionService.instance.getAllMissions();
      print('Loaded ${_missions.length} missions');
      for (var mission in _missions) {
        print('Mission: ${mission.name} (ID: ${mission.id})');
      }
      setState(() {});
    } catch (e) {
      print('Error loading missions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading missions: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRegions(String missionId) async {
    print('Loading regions for mission: $missionId');

    // Find the selected mission to get its name
    final selectedMission = _missions.firstWhere((m) => m.id == missionId);
    print('Mission name: ${selectedMission.name}');

    setState(() {
      _regions = [];
      _districts = [];
      _selectedRegion = null;
      _selectedDistrict = null;
    });

    try {
      // Try using the RegionService directly with mission ID first
      List<Region> regionsById =
          await RegionService.instance.getRegionsByMission(missionId);

      // If we get regions, use them directly
      if (regionsById.isNotEmpty) {
        print('Found ${regionsById.length} regions using mission ID');
        _regions = regionsById;
      } else {
        // Fallback: fetch ALL regions and filter by mission name
        final allRegions = await RegionService.instance.getAllRegions();
        print('DEBUG: Total regions in database: ${allRegions.length}');
        print(
            'DEBUG: Looking for missionId=$missionId OR missionName=${selectedMission.name}');

        // Filter regions by mission name or mission ID
        _regions = allRegions
            .where((r) =>
                r.missionId == missionId ||
                r.missionId == selectedMission.name ||
                r.missionId.toLowerCase() == selectedMission.name.toLowerCase())
            .toList();
        print(
            'Found ${_regions.length} regions matching mission name "${selectedMission.name}" or ID');
      }

      setState(() {});
    } catch (e) {
      print('Error loading regions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading regions: $e')),
        );
      }
    }
  }

  Future<void> _loadDistricts(String regionId) async {
    print('Loading districts for region: $regionId');
    setState(() {
      _districts = [];
      _selectedDistrict = null;
      _churches = [];
      _selectedChurch = null;
    });

    try {
      _districts =
          await DistrictService.instance.getDistrictsByRegion(regionId);
      print('Loaded ${_districts.length} districts');
      setState(() {});
    } catch (e) {
      print('Error loading districts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading districts: $e')),
        );
      }
    }
  }

  Future<void> _loadChurches(String districtId) async {
    print('Loading churches for district: $districtId');
    setState(() {
      _churches = [];
      _selectedChurch = null;
    });

    try {
      _churches = await ChurchService().getChurchesByDistrict(districtId);
      print('Loaded ${_churches.length} churches');
      setState(() {});
    } catch (e) {
      print('Error loading churches: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading churches: $e')),
        );
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
        mission: _selectedMission,
        // Other fields will be filled during onboarding
      );

      if (!mounted) return;

      if (success) {
        // Navigate to home screen since user already provided all required info during registration
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.routeHome,
          (route) => false, // Remove all previous routes
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Registration failed'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Text
                Text(
                  'Join Us Today',
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your account to get started',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mission Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedMission,
                  decoration: const InputDecoration(
                    labelText: 'Mission',
                    hintText: 'Select your mission',
                    prefixIcon: Icon(Icons.church_outlined),
                  ),
                  items: _missions.map((Mission mission) {
                    return DropdownMenuItem<String>(
                      value: mission.id,
                      child: Text(mission.name),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedMission = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a mission';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Information about onboarding
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'After registration, you will complete your profile by adding your region, district, and role information.',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Role Field
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    hintText: 'Select your role',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: AppConstants.roles.map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue;
                      // Clear church selection when role changes
                      if (newValue != 'Church Treasurer') {
                        _selectedChurch = null;
                        _churches = [];
                      } else if (newValue == 'Church Treasurer' &&
                          _selectedDistrict != null) {
                        // Load churches if district is already selected
                        _loadChurches(_selectedDistrict!);
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a role';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Church Dropdown (only for Church Treasurer)
                if (_selectedRole == 'Church Treasurer')
                  DropdownButtonFormField<String>(
                    value: _selectedChurch,
                    decoration: const InputDecoration(
                      labelText: 'Church',
                      hintText: 'Select your church',
                      prefixIcon: Icon(Icons.church_outlined),
                    ),
                    items: _churches.map((Church church) {
                      return DropdownMenuItem<String>(
                        value: church.id,
                        child: Text(church.churchName),
                      );
                    }).toList(),
                    onChanged: _churches.isEmpty
                        ? null
                        : (String? newValue) {
                            setState(() {
                              _selectedChurch = newValue;
                            });
                          },
                    validator: (value) {
                      if (_selectedRole == 'Church Treasurer' &&
                          (value == null || value.isEmpty)) {
                        return 'Please select your church';
                      }
                      return null;
                    },
                  ),
                if (_selectedRole == 'Church Treasurer')
                  const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Register Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 24),

                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
