// lib/screens/comprehensive_onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/services/auth_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/theme.dart';

class ComprehensiveOnboardingScreen extends StatefulWidget {
  const ComprehensiveOnboardingScreen({super.key});

  @override
  State<ComprehensiveOnboardingScreen> createState() =>
      _ComprehensiveOnboardingScreenState();
}

class _ComprehensiveOnboardingScreenState
    extends State<ComprehensiveOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regionNameController = TextEditingController();
  final _districtNameController = TextEditingController();
  final _churchNameController = TextEditingController();
  final _churchAddressController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RegionService _regionService = RegionService.instance;
  final DistrictService _districtService = DistrictService.instance;
  final ChurchService _churchService = ChurchService.instance;
  final AuthService _authService = AuthService();

  List<Region> _regions = [];
  List<District> _districts = [];
  List<Church> _churches = [];

  String? _selectedRegionId;
  String? _selectedDistrictId;
  String? _selectedChurchId;
  final List<String> _selectedChurchIds = []; // Allow multiple church selection
  UserRole _selectedRole = UserRole.user;

  bool _isLoadingRegions = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingChurches = false;
  bool _isSubmitting = false;

  String _missionName = '';
  bool _isLoadingMission = false;

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadMissionName();
    _loadRegions();
  }

  Future<void> _loadMissionName() async {
    setState(() => _isLoadingMission = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      print('🔍 Onboarding Debug:');
      print('User Mission ID: ${user?.mission}');

      if (user?.mission != null) {
        // Try to get mission document
        final missionDoc =
            await _firestore.collection('missions').doc(user!.mission).get();

        print('Mission Document Exists: ${missionDoc.exists}');
        print('Mission Document Data: ${missionDoc.data()}');

        if (missionDoc.exists) {
          final missionName = missionDoc.data()?['name'] ?? user.mission!;
          print('Mission Name from Doc: $missionName');
          setState(() {
            _missionName = missionName;
          });
        } else {
          // If mission doc doesn't exist, use the mission ID as fallback
          print('Mission doc not found, using ID as name: ${user.mission}');
          setState(() {
            _missionName = user.mission!;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading mission name: $e');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      setState(() {
        _missionName = user?.mission ?? 'Unknown';
      });
    } finally {
      setState(() => _isLoadingMission = false);
    }
  }

  @override
  void dispose() {
    _regionNameController.dispose();
    _districtNameController.dispose();
    _churchNameController.dispose();
    _churchAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    setState(() => _isLoadingRegions = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user?.mission != null) {
        final regions =
            await _regionService.getRegionsByMission(user!.mission!);
        setState(() {
          _regions = regions;
          if (_regions.isEmpty) {
            // No regions available - user will need to create one
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading regions: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingRegions = false);
    }
  }

  Future<void> _loadDistricts(String regionId) async {
    setState(() => _isLoadingDistricts = true);
    try {
      final districts = await _districtService.getDistrictsByRegion(regionId);
      setState(() {
        _districts = districts;
        _selectedDistrictId = null;
        _churches = [];
        _selectedChurchId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading districts: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingDistricts = false);
    }
  }

  Future<void> _loadChurches(String districtId) async {
    setState(() => _isLoadingChurches = true);
    try {
      final churches = await _churchService.getChurchesByDistrict(districtId);
      setState(() {
        _churches = churches;
        _selectedChurchId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading churches: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingChurches = false);
    }
  }

  Future<void> _createRegion() async {
    if (_regionNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter region name')),
      );
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user?.mission == null) {
        throw 'Mission not set for user';
      }

      // Generate a unique ID
      final regionId = _firestore.collection('regions').doc().id;

      final region = Region(
        id: regionId,
        name: _regionNameController.text.trim(),
        code: _regionNameController.text.trim().toUpperCase().substring(0, 3),
        missionId: user!.mission!,
        createdAt: DateTime.now(),
        createdBy: user.uid,
      );

      await _regionService.createRegion(region);
      _regionNameController.clear();
      await _loadRegions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Region created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating region: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createDistrict() async {
    if (_districtNameController.text.trim().isEmpty ||
        _selectedRegionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select region and enter district name')),
      );
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Generate a unique ID
      final districtId = _firestore.collection('districts').doc().id;

      final district = District(
        id: districtId,
        name: _districtNameController.text.trim(),
        code: _districtNameController.text.trim().toUpperCase().substring(0, 3),
        regionId: _selectedRegionId!,
        missionId: user?.mission ?? '',
        createdAt: DateTime.now(),
        createdBy: user?.uid ?? '',
      );

      await _districtService.createDistrict(district);
      _districtNameController.clear();
      await _loadDistricts(_selectedRegionId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('District created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating district: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createAndAddChurch() async {
    if (_churchNameController.text.trim().isEmpty ||
        _selectedDistrictId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter church name')),
      );
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Generate a unique ID
      final churchId = _firestore.collection('churches').doc().id;

      final church = Church(
        id: churchId,
        userId: user?.uid ?? '',
        churchName: _churchNameController.text.trim(),
        elderName: '', // Will be set later
        status: ChurchStatus.organizedChurch,
        elderEmail: '',
        elderPhone: '',
        address: _churchAddressController.text.trim(),
        createdAt: DateTime.now(),
        districtId: _selectedDistrictId!,
        regionId: _selectedRegionId ?? '',
        missionId: user?.mission ?? '',
      );

      await _churchService.createChurch(church);

      // Add to selected churches list
      setState(() {
        _selectedChurchIds.add(churchId);
        _churches.add(church);
      });

      // Clear form but keep it open for adding more
      _churchNameController.clear();
      _churchAddressController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${church.churchName} added to your churches'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating church: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeOnboarding() async {
    // For mission-level roles, skip region/district validation
    if (!_isMissionLevelRole(_selectedRole)) {
      if (_selectedRegionId == null || _selectedDistrictId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select region and district')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw 'User not found';
      }

      // Pass the list of selected church IDs
      final missionId = user.mission;
      if (missionId == null || missionId.isEmpty) {
        throw 'Your profile is missing a mission assignment. Please contact an administrator.';
      }

      // For mission-level roles, use null for region and district
      String? region;
      String? district;

      if (!_isMissionLevelRole(_selectedRole)) {
        // Get the names for the selected items
        final selectedRegion =
            _regions.firstWhere((r) => r.id == _selectedRegionId);
        region = selectedRegion.name;
        district = _selectedDistrictId;
      }

      await _authService.completeOnboarding(
        uid: user.uid,
        missionId: missionId,
        region: region,
        district: district,
        churchIds: _selectedChurchIds.isNotEmpty ? _selectedChurchIds : null,
        userRole: _selectedRole,
        roleTitle: _getRoleTitle(_selectedRole),
      );

      // Refresh user data
      await authProvider.refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedChurchIds.isEmpty
                  ? 'Profile completed successfully!'
                  : 'Profile completed successfully! ${_selectedChurchIds.length} church(es) added.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home
        Navigator.pushReplacementNamed(context, AppConstants.routeHome);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing onboarding: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getRoleTitle(UserRole role) {
    switch (role) {
      case UserRole.user:
        return 'Pastor';
      case UserRole.churchTreasurer:
        return 'Church Treasurer';
      case UserRole.districtPastor:
        return 'District Pastor';
      case UserRole.ministerialSecretary:
        return 'Ministerial Secretary';
      case UserRole.officer:
        return 'Officer';
      case UserRole.director:
        return 'Director';
      case UserRole.editor:
        return 'Editor';
      case UserRole.missionAdmin:
        return 'Mission Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.superAdmin:
        return 'Super Admin';
    }
  }

  // Helper method to check if a role requires region/district/church selection
  bool _isMissionLevelRole(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.ministerialSecretary ||
        role == UserRole.officer ||
        role == UserRole.director ||
        role == UserRole.missionAdmin ||
        role == UserRole.editor ||
        role == UserRole.admin ||
        role == UserRole.superAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Onboarding?'),
                  content: const Text(
                    'Your profile is incomplete. You can complete it later from settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Stay'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(
                          context,
                          AppConstants.routeHome,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoadingRegions
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Mission Indicator Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.1),
                        AppTheme.primary.withOpacity(0.05),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Mission',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _isLoadingMission
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _missionName.isNotEmpty
                                        ? _missionName
                                        : 'Not set',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Setup Required',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stepper(
                    currentStep: _currentStep,
                    onStepContinue: () {
                      if (_currentStep == 0) {
                        // Step 1: Role - Just move to next step
                        setState(() => _currentStep++);
                      } else if (_currentStep == 1) {
                        // Step 2: Region
                        if (_selectedRegionId != null) {
                          setState(() => _currentStep++);
                          _loadDistricts(_selectedRegionId!);
                        } else {
                          // Skip region selection for mission-level roles
                          if (_isMissionLevelRole(_selectedRole)) {
                            setState(() => _currentStep++);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please select or create a region first.'),
                              ),
                            );
                          }
                        }
                      } else if (_currentStep == 2) {
                        // Step 3: District
                        if (_selectedDistrictId != null) {
                          setState(() => _currentStep++);
                          _loadChurches(_selectedDistrictId!);
                        } else {
                          // Skip district selection for mission-level roles
                          if (_isMissionLevelRole(_selectedRole)) {
                            setState(() => _currentStep++);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please select or create a district first.'),
                              ),
                            );
                          }
                        }
                      } else if (_currentStep == 3) {
                        // Step 4: Churches - Complete onboarding
                        // Church Treasurers MUST select at least one church if churches are available
                        if (_selectedRole == UserRole.churchTreasurer &&
                            _churches.isNotEmpty &&
                            _selectedChurchIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Church Treasurers must select at least one church'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } else {
                          _completeOnboarding();
                        }
                      }
                    },
                    onStepCancel: () {
                      if (_currentStep > 0) {
                        setState(() => _currentStep--);
                      }
                    },
                    steps: [
                      // Step 1: Select Role
                      Step(
                        title: const Text('Select Your Role'),
                        content: _buildRoleStep(user),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0
                            ? StepState.complete
                            : StepState.indexed,
                      ),
                      // Step 2: Select or Create Region
                      Step(
                        title: const Text('Select Region'),
                        content: _buildRegionStep(user),
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1
                            ? StepState.complete
                            : StepState.indexed,
                      ),
                      // Step 3: Select or Create District
                      Step(
                        title: const Text('Select District'),
                        content: _buildDistrictStep(user),
                        isActive: _currentStep >= 2,
                        state: _currentStep > 2
                            ? StepState.complete
                            : StepState.indexed,
                      ),
                      // Step 4: Add Churches (Optional)
                      Step(
                        title: const Text('Add Churches'),
                        content: _buildChurchStep(user),
                        isActive: _currentStep >= 3,
                        state: _currentStep > 3
                            ? StepState.complete
                            : StepState.indexed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRegionStep(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role info banner
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Role: ${_getRoleTitle(_selectedRole)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Skip region selection for mission-level roles
        if (_isMissionLevelRole(_selectedRole))
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'As a mission-level role, you don\'t need to select a specific region.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select your region or create a new one if it doesn\'t exist',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Existing Regions
        if (_regions.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Available Regions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRegionId,
                isExpanded: true,
                hint: const Text('Select a region'),
                icon: const Icon(Icons.arrow_drop_down),
                items: _regions.map((region) {
                  return DropdownMenuItem<String>(
                    value: region.id,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          region.name,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRegionId = value;
                    if (value != null) {
                      _loadDistricts(value);
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Create New Region
        Row(
          children: [
            Icon(Icons.add_location_alt,
                color: Colors.green.shade700, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Create New Region',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regionNameController,
          decoration: InputDecoration(
            labelText: 'Region Name',
            hintText: 'e.g., North Region',
            prefixIcon: const Icon(Icons.map),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _createRegion,
            icon: const Icon(Icons.add_circle),
            label: const Text(
              'Create Region',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictStep(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary of previous steps
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Role: ${_getRoleTitle(_selectedRole)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Region: ${_regions.where((r) => r.id == _selectedRegionId).firstOrNull?.name ?? 'None'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Skip district selection for mission-level roles
        if (_isMissionLevelRole(_selectedRole))
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'As a mission-level role, you don\'t need to select a specific district.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (_isLoadingDistricts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select your district or create a new one if it doesn\'t exist',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Existing Districts
          if (_districts.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.apartment, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Available Districts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDistrictId,
                  isExpanded: true,
                  hint: const Text('Select a district'),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: _districts.map((district) {
                    return DropdownMenuItem<String>(
                      value: district.id,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            district.name,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDistrictId = value;
                      if (value != null) {
                        _loadChurches(value);
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Create New District
          Row(
            children: [
              Icon(Icons.add_business, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Create New District',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _districtNameController,
            decoration: InputDecoration(
              labelText: 'District Name',
              hintText: 'e.g., Kota Kinabalu District',
              prefixIcon: const Icon(Icons.location_city),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _createDistrict,
              icon: const Icon(Icons.add_circle),
              label: const Text(
                'Create District',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRoleStep(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mission info banner
        if (_missionName.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.green.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mission: $_missionName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Select your role in the church organization',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.person, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Your Role',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UserRole>(
              value: _selectedRole,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              items: const [
                DropdownMenuItem(
                  value: UserRole.user,
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Pastor', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: UserRole.churchTreasurer,
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, size: 20),
                      SizedBox(width: 12),
                      Text('Church Treasurer', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: UserRole.districtPastor,
                  child: Row(
                    children: [
                      Icon(Icons.location_city, size: 20),
                      SizedBox(width: 12),
                      Text('District Pastor', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: UserRole.officer,
                  child: Row(
                    children: [
                      Icon(Icons.business_center, size: 20),
                      SizedBox(width: 12),
                      Text('Mission Officer', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: UserRole.director,
                  child: Row(
                    children: [
                      Icon(Icons.assignment_ind, size: 20),
                      SizedBox(width: 12),
                      Text('Mission Director', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: UserRole.ministerialSecretary,
                  child: Row(
                    children: [
                      Icon(Icons.emoji_people, size: 20),
                      SizedBox(width: 12),
                      Text('Ministerial Secretary',
                          style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value ?? UserRole.user;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChurchStep(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary of previous steps
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Role: ${_getRoleTitle(_selectedRole)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              // Only show region and district if not mission-level role
              if (!_isMissionLevelRole(_selectedRole)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Region: ${_regions.where((r) => r.id == _selectedRegionId).firstOrNull?.name ?? 'None'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'District: ${_districts.where((d) => d.id == _selectedDistrictId).firstOrNull?.name ?? 'None'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Skip church selection for mission-level roles
        if (_isMissionLevelRole(_selectedRole))
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'As a mission-level role, you don\'t need to select a specific church.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          // Info banner for church selection
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _selectedRole == UserRole.churchTreasurer
                  ? Colors.blue.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedRole == UserRole.churchTreasurer
                    ? Colors.blue.shade200
                    : Colors.green.shade200,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedRole == UserRole.churchTreasurer
                      ? Icons.church
                      : Icons.add_business,
                  color: _selectedRole == UserRole.churchTreasurer
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedRole == UserRole.churchTreasurer
                        ? 'Select the church(es) you will manage financial reports for.'
                        : 'Create your church(es) below. You can also select existing churches if needed.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Selected Churches Summary
        if (_selectedChurchIds.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Selected Churches (${_selectedChurchIds.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: _selectedChurchIds.map((churchId) {
                final church = _churches.firstWhere(
                  (c) => c.id == churchId,
                  orElse: () => Church(
                    id: churchId,
                    userId: '',
                    churchName: 'Unknown',
                    elderName: '',
                    status: ChurchStatus.organizedChurch,
                    elderEmail: '',
                    elderPhone: '',
                    address: '',
                    createdAt: DateTime.now(),
                    districtId: '',
                    regionId: '',
                    missionId: '',
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          church.churchName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle,
                            color: Colors.red.shade700, size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedChurchIds.remove(churchId);
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 20),

        if (_isLoadingChurches)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          // Existing Churches - Show as checkboxes (for all users)
          if (_churches.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.church, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Available Churches',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: _churches.map((church) {
                  final isSelected = _selectedChurchIds.contains(church.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedChurchIds.add(church.id);
                        } else {
                          _selectedChurchIds.remove(church.id);
                        }
                      });
                    },
                    title: Text(
                      church.churchName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    subtitle: church.address?.isNotEmpty ?? false
                        ? Text(
                            church.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          )
                        : null,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primary,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ] else if (_selectedRole == UserRole.churchTreasurer) ...[
            // No churches available for church treasurers
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.orange.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No Churches Available',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'There are no churches in your selected district yet. Please contact your mission administrator to create churches before you can manage financial reports.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Allow proceeding but show warning
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Warning: You have no churches assigned. Contact your admin to add churches.'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 5),
                          ),
                        );
                        _completeOnboarding();
                      },
                      icon: const Icon(Icons.warning),
                      label: const Text(
                        'Proceed Anyway',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // For non-church treasurers: Create New Church (optional)
          if (_selectedRole != UserRole.churchTreasurer) ...[
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.add_business,
                    color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Create New Church',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _churchNameController,
              decoration: InputDecoration(
                labelText: 'Church Name',
                hintText: 'e.g., KK Central Church',
                prefixIcon: const Icon(Icons.church),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _churchAddressController,
              decoration: InputDecoration(
                labelText: 'Church Address (Optional)',
                hintText: 'Street address',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _createAndAddChurch,
                icon: const Icon(Icons.add_circle),
                label: const Text(
                  'Add Church',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: 24),
        if (_isSubmitting) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
