// lib/screens/enhanced_onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/theme.dart';

class EnhancedOnboardingScreen extends StatefulWidget {
  final bool isFromSettings;

  const EnhancedOnboardingScreen({
    super.key,
    this.isFromSettings = false,
  });

  @override
  State<EnhancedOnboardingScreen> createState() =>
      _EnhancedOnboardingScreenState();
}

class _EnhancedOnboardingScreenState extends State<EnhancedOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserManagementService _userService = UserManagementService();
  final RegionService _regionService = RegionService();
  final DistrictService _districtService = DistrictService();
  final ChurchService _churchService = ChurchService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _regionNameController = TextEditingController();
  final _districtNameController = TextEditingController();
  final _churchNameController = TextEditingController();
  final _churchAddressController = TextEditingController();

  String? _selectedMission;
  String? _selectedRegion;
  String? _selectedDistrict;
  String? _selectedRole;
  String? _selectedChurch;
  bool _isLoading = false;
  bool _addingNewRegion = false;
  bool _addingNewDistrict = false;
  bool _addingNewChurch = false;

  List<Mission> _missions = [];
  List<Region> _regions = [];
  List<District> _districts = [];
  List<Church> _churches = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _regionNameController.dispose();
    _districtNameController.dispose();
    _churchNameController.dispose();
    _churchAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load mission data
      _missions = await MissionService.instance.getAllMissions();

      // Set selected mission from user data
      if (user.mission != null) {
        _selectedMission = user.mission;

        // Load regions for this mission
        await _loadRegions(_selectedMission!);

        // If user has a region, select it and load districts
        if (user.region != null) {
          _selectedRegion = user.region;
          await _loadDistricts(_selectedRegion!);

          // If user has a district, select it and load churches
          if (user.district != null) {
            _selectedDistrict = user.district;
            await _loadChurches(_selectedDistrict!);

            // If user has a church, select it
            if (user.churchId != null) {
              _selectedChurch = user.churchId;
            }
          }
        }
      }

      // Set user role
      if (user.role != null) {
        _selectedRole = user.role;
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRegions(String missionId) async {
    try {
      final regions = await _regionService.getRegionsByMission(missionId);
      setState(() {
        _regions = regions;
        _selectedRegion = null;
        _districts = [];
        _selectedDistrict = null;
        _churches = [];
        _selectedChurch = null;
      });
    } catch (e) {
      print('Error loading regions: $e');
    }
  }

  Future<void> _loadDistricts(String regionId) async {
    try {
      final districts = await _districtService.getDistrictsByRegion(regionId);
      setState(() {
        _districts = districts;
        _selectedDistrict = null;
        _churches = [];
        _selectedChurch = null;
      });
    } catch (e) {
      print('Error loading districts: $e');
    }
  }

  Future<void> _loadChurches(String districtId) async {
    try {
      final churches = await _churchService.getChurchesByDistrict(districtId);
      setState(() {
        _churches = churches;
      });
    } catch (e) {
      print('Error loading churches: $e');
    }
  }

  Future<void> _addNewRegion() async {
    if (_selectedMission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mission is not selected')),
      );
      return;
    }

    if (_regionNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Region name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create a new region with the entered name
      final newRegion = Region(
        id: const Uuid().v4(),
        name: _regionNameController.text.trim(),
        code: _regionNameController.text.trim().toUpperCase().substring(0, 3),
        missionId: _selectedMission!,
        createdAt: DateTime.now(),
        createdBy:
            Provider.of<AuthProvider>(context, listen: false).user?.uid ??
                'system',
      );

      // Add the region to Firestore
      await _regionService.createRegion(newRegion);

      // Clear the text field and update the UI
      _regionNameController.clear();
      setState(() {
        _addingNewRegion = false;
      });

      // Reload the regions list
      await _loadRegions(_selectedMission!);

      // Select the newly added region
      setState(() {
        _selectedRegion = newRegion.id;
        _selectedDistrict = null;
        _selectedChurch = null;
        _districts = [];
        _churches = [];
      });
    } catch (e) {
      print('Error adding region: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding region: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewDistrict() async {
    if (_selectedRegion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Region is not selected')),
      );
      return;
    }

    if (_districtNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('District name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create a new district with the entered name
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String districtCode =
          _districtNameController.text.trim().substring(0, 2).toUpperCase();

      // Create the District object
      final newDistrict = District(
        id: const Uuid().v4(),
        name: _districtNameController.text.trim(),
        regionId: _selectedRegion!,
        missionId: _selectedMission!,
        createdBy: authProvider.user!.uid,
        createdAt: DateTime.now(),
        code: districtCode,
      );

      // Add the district to Firestore
      await _districtService.createDistrict(newDistrict);

      // Clear the text field and update the UI
      _districtNameController.clear();
      setState(() {
        _addingNewDistrict = false;
      });

      // Reload the districts list
      await _loadDistricts(_selectedRegion!);

      // Select the newly added district
      setState(() {
        _selectedDistrict = newDistrict.id;
        _selectedChurch = null;
        _churches = [];
      });
    } catch (e) {
      print('Error adding district: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding district: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewChurch() async {
    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('District is not selected')),
      );
      return;
    }

    if (_churchNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Church name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create a new church with the entered details
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final newChurch = Church(
        id: const Uuid().v4(),
        userId: authProvider.user!.uid,
        churchName: _churchNameController.text.trim(),
        elderName: 'To be updated', // Placeholder value
        status: ChurchStatus.church, // Default to church status
        elderEmail: 'email@example.com', // Placeholder value
        elderPhone: '0000000000', // Placeholder value
        address: _churchAddressController.text.trim(),
        memberCount: 0,
        createdAt: DateTime.now(),
        districtId: _selectedDistrict,
        regionId: _selectedRegion,
        missionId: _selectedMission,
      );

      // Add the church to Firestore
      await _churchService.createChurch(newChurch);

      // Clear the text fields and update the UI
      _churchNameController.clear();
      _churchAddressController.clear();
      setState(() {
        _addingNewChurch = false;
      });

      // Reload the churches list
      await _loadChurches(_selectedDistrict!);

      // Select the newly added church
      setState(() {
        _selectedChurch = newChurch.id;
      });
    } catch (e) {
      print('Error adding church: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding church: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all required fields correctly')),
      );
      return;
    }

    // Check if role is church treasurer and church is selected
    if (_selectedRole == UserRole.churchTreasurer.displayName &&
        (_selectedChurch == null || _selectedChurch!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Church Treasurers must select a church')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not found');
      }

      // Update user profile
      await _userService.updateUserProfile(
        uid: user.uid,
        mission: _selectedMission,
        region: _selectedRegion,
        district: _selectedDistrict,
        role: _selectedRole,
        // Note: church and isOnboardingCompleted aren't supported by the method
        // We need to update the user differently
      );

      // Update the onboarding status separately if needed
      await _firestore.collection('users').doc(user.uid).update({
        'isOnboardingCompleted': true,
        'churchId': _selectedRole == UserRole.churchTreasurer.displayName
            ? _selectedChurch
            : null,
      });

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isFromSettings
              ? 'Profile updated successfully!'
              : 'Setup completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate accordingly
      if (widget.isFromSettings) {
        Navigator.pop(context);
      } else {
        // Navigate to home instead of non-existent dashboard route
        Navigator.pushReplacementNamed(
          context,
          AppConstants.routeHome,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isFromSettings
              ? 'Failed to update profile: $e'
              : 'Failed to complete setup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Bar replacement
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              if (widget.isFromSettings)
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios,
                                      color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              Text(
                                widget.isFromSettings
                                    ? 'Update Profile'
                                    : 'Complete Your Profile',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Introduction
                              if (!widget.isFromSettings)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color:
                                              AppTheme.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          size: 36,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Welcome! Let\'s complete your profile',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: AppTheme.primary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'You need to select or create your region, district, and role information. If you are a Church Treasurer, you will also need to select a church.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),

                              // Region Section
                              _buildSectionHeader('Region'),
                              if (!_addingNewRegion)
                                _buildDropdownWithAddButton(
                                  value: _selectedRegion,
                                  items: _regions
                                      .map((region) => DropdownMenuItem(
                                            value: region.id,
                                            child: Text(region.name),
                                          ))
                                      .toList(),
                                  hint: 'Select your region',
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRegion = value;
                                      _selectedDistrict = null;
                                      _selectedChurch = null;
                                      _districts = [];
                                      _churches = [];
                                    });
                                    if (value != null) {
                                      _loadDistricts(value);
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select or add a region';
                                    }
                                    return null;
                                  },
                                  onAddPressed: () {
                                    setState(() {
                                      _addingNewRegion = true;
                                    });
                                  },
                                )
                              else
                                _buildAddNewForm(
                                  controller: _regionNameController,
                                  label: 'Region Name',
                                  onSave: _addNewRegion,
                                  onCancel: () {
                                    setState(() {
                                      _addingNewRegion = false;
                                      _regionNameController.clear();
                                    });
                                  },
                                ),
                              const SizedBox(height: 16),

                              // District Section
                              _buildSectionHeader('District'),
                              if (_selectedRegion == null)
                                const Text(
                                  'Please select a region first',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else if (!_addingNewDistrict)
                                _buildDropdownWithAddButton(
                                  value: _selectedDistrict,
                                  items: _districts
                                      .map((district) => DropdownMenuItem(
                                            value: district.id,
                                            child: Text(district.name),
                                          ))
                                      .toList(),
                                  hint: 'Select your district',
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDistrict = value;
                                      _selectedChurch = null;
                                      _churches = [];
                                    });
                                    if (value != null) {
                                      _loadChurches(value);
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select or add a district';
                                    }
                                    return null;
                                  },
                                  onAddPressed: () {
                                    setState(() {
                                      _addingNewDistrict = true;
                                    });
                                  },
                                )
                              else
                                _buildAddNewForm(
                                  controller: _districtNameController,
                                  label: 'District Name',
                                  onSave: _addNewDistrict,
                                  onCancel: () {
                                    setState(() {
                                      _addingNewDistrict = false;
                                      _districtNameController.clear();
                                    });
                                  },
                                ),
                              const SizedBox(height: 16),

                              // Role Section
                              _buildSectionHeader('Your Role'),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedRole,
                                  decoration: const InputDecoration(
                                    labelText: 'Select your role',
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    border: InputBorder.none,
                                    fillColor: Colors.transparent,
                                    filled: true,
                                  ),
                                  items: [
                                    // Include all possible user roles
                                    ...UserRole.values
                                        .map((role) => DropdownMenuItem(
                                              value: role.displayName,
                                              child: Text(role.displayName),
                                            )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRole = value;
                                      _selectedChurch = null;

                                      // Load churches if district is selected
                                      if (_selectedDistrict != null) {
                                        _loadChurches(_selectedDistrict!);
                                      }
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select your role';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Church Section
                              _buildSectionHeader('Church'),
                              if (_selectedDistrict == null)
                                const Text(
                                  'Please select a district first',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else if (!_addingNewChurch)
                                _buildDropdownWithAddButton(
                                  value: _selectedChurch,
                                  items: _churches
                                      .map((church) => DropdownMenuItem(
                                            value: church.id,
                                            child: Text(church.churchName),
                                          ))
                                      .toList(),
                                  hint: 'Select your church',
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedChurch = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (_selectedRole ==
                                            UserRole
                                                .churchTreasurer.displayName &&
                                        (value == null || value.isEmpty)) {
                                      return 'Church Treasurers must select a church';
                                    }
                                    return null;
                                  },
                                  onAddPressed: _selectedRole ==
                                          UserRole.churchTreasurer.displayName
                                      ? null
                                      : () {
                                          setState(() {
                                            _addingNewChurch = true;
                                          });
                                        },
                                )
                              else
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildAddNewForm(
                                      controller: _churchNameController,
                                      label: 'Church Name',
                                      onSave: _addNewChurch,
                                      onCancel: () {
                                        setState(() {
                                          _addingNewChurch = false;
                                          _churchNameController.clear();
                                          _churchAddressController.clear();
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _churchAddressController,
                                      decoration: const InputDecoration(
                                        labelText: 'Church Address (Optional)',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 2,
                                    ),
                                  ],
                                ),

                              // Complete Button
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _completeOnboarding,
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
                                      : Text(
                                          widget.isFromSettings
                                              ? 'Update Profile'
                                              : 'Complete Setup',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownWithAddButton({
    String? value,
    required List<DropdownMenuItem<String>> items,
    required String hint,
    required Function(String?) onChanged,
    required String? Function(String?)? validator,
    VoidCallback? onAddPressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                labelText: hint,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
              ),
              items: items,
              onChanged: onChanged,
              validator: validator,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_circle_outlined),
              iconEnabledColor: AppTheme.primary,
            ),
          ),
        ),
        if (onAddPressed != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add),
                tooltip: 'Add new',
                color: AppTheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddNewForm({
    required TextEditingController controller,
    required String label,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
