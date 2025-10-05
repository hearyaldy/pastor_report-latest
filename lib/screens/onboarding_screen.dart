// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserManagementService _userService = UserManagementService();

  String? _selectedMission;
  String? _selectedRegion;
  String? _selectedDistrict;
  String? _selectedRole;
  bool _isLoading = false;

  List<Mission> _missions = [];
  List<Region> _regions = [];
  List<District> _districts = [];

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMissions() async {
    setState(() => _isLoading = true);
    try {
      _missions = await MissionService.instance.getAllMissions();
      setState(() {});
    } catch (e) {
      print('Error loading missions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRegions(String missionId) async {
    setState(() {
      _regions = [];
      _districts = [];
      _selectedRegion = null;
      _selectedDistrict = null;
    });

    try {
      _regions = await RegionService.instance.getRegionsByMission(missionId);
      setState(() {});
    } catch (e) {
      print('Error loading regions: $e');
    }
  }

  Future<void> _loadDistricts(String regionId) async {
    setState(() {
      _districts = [];
      _selectedDistrict = null;
    });

    try {
      _districts =
          await DistrictService.instance.getDistrictsByRegion(regionId);
      setState(() {});
    } catch (e) {
      print('Error loading districts: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() => _isLoading = true);

    try {
      await _userService.updateUserProfile(
        uid: authProvider.user!.uid,
        mission: _selectedMission,
        district: _selectedDistrict,
        region: _selectedRegion,
        role: _selectedRole,
      );

      if (!mounted) return;

      // Refresh user data
      await authProvider.refreshUser();

      if (!mounted) return;

      // Navigate to dashboard
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete onboarding: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Welcome Icon
                Icon(
                  Icons.waving_hand,
                  size: 80,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 24),

                // Welcome Text
                Text(
                  'Welcome to Pastor Report!',
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Consumer<AuthProvider>(builder: (context, authProvider, child) {
                  final user = authProvider.user;
                  String welcomeText =
                      'Let\'s set up your profile to get started';

                  if (user != null) {
                    if (user.userRole == UserRole.churchTreasurer) {
                      welcomeText =
                          'Welcome, Church Treasurer! Please complete your profile to start submitting financial reports for your church.';
                    } else if (user.roleTitle?.contains('Pastor') == true ||
                        (user.role?.contains('Pastor') == true)) {
                      welcomeText =
                          'Welcome, Pastor! Please complete your profile to start managing your ministry and churches.';
                    }
                  }

                  return Text(
                    welcomeText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  );
                }),

                const SizedBox(height: 12),
                Text(
                  'All users need to complete onboarding again for our new database system.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Mission Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedMission,
                  decoration: const InputDecoration(
                    labelText: 'Mission / Organization',
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
                    if (newValue != null) {
                      _loadRegions(newValue);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a mission';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Region Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRegion,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    hintText: 'Select your region',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: _regions.map((Region region) {
                    return DropdownMenuItem<String>(
                      value: region.id,
                      child: Text(region.name),
                    );
                  }).toList(),
                  onChanged: _regions.isEmpty
                      ? null
                      : (String? newValue) {
                          setState(() {
                            _selectedRegion = newValue;
                          });
                          if (newValue != null) {
                            _loadDistricts(newValue);
                          }
                        },
                  validator: (value) {
                    if (_regions.isNotEmpty &&
                        (value == null || value.isEmpty)) {
                      return 'Please select a region';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // District Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedDistrict,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    hintText: 'Select your district',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: _districts.map((District district) {
                    return DropdownMenuItem<String>(
                      value: district.id,
                      child: Text(district.name),
                    );
                  }).toList(),
                  onChanged: _districts.isEmpty
                      ? null
                      : (String? newValue) {
                          setState(() {
                            _selectedDistrict = newValue;
                          });
                        },
                  validator: (value) {
                    if (_districts.isNotEmpty &&
                        (value == null || value.isEmpty)) {
                      return 'Please select your district';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const SizedBox(height: 20),

                // Role Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRole,
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
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a role';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // Complete Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Complete Setup',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),

                // Info Text - Dynamic based on role
                Consumer<AuthProvider>(builder: (context, authProvider, child) {
                  final user = authProvider.user;
                  String infoText =
                      'This information helps us show you relevant departments and reports for your mission.';
                  IconData infoIcon = Icons.info_outline;

                  if (user != null &&
                      user.userRole == UserRole.churchTreasurer) {
                    infoText =
                        'As a Church Treasurer, you will be able to:\n'
                        '• Submit monthly tithe and offering reports\n'
                        '• View financial statistics for your church\n'
                        '• Edit and export your church\'s reports\n'
                        '• Track submission history';
                    infoIcon = Icons.account_balance_wallet;
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          infoIcon,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            infoText,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
