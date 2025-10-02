import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/utils/theme.dart';
import 'package:pastor_report/utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserManagementService _userService = UserManagementService();
  final _displayNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _regionController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  String? _selectedMission;
  String? _selectedRole;

  @override
  void dispose() {
    _displayNameController.dispose();
    _districtController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      await _userService.updateUserProfile(
        uid: authProvider.user!.uid,
        displayName: _displayNameController.text.trim(),
        mission: _selectedMission,
        district: _districtController.text.trim(),
        region: _regionController.text.trim(),
        role: _selectedRole,
      );

      if (!mounted) return;

      // Refresh auth provider
      await authProvider.refreshUser();

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'At least 6 characters',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await _userService.updatePassword(newPasswordController.text);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = authProvider.user?.email;

    if (email == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text(
            'A password reset link will be sent to:\n\n$email\n\nAre you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _userService.sendPasswordResetEmail(email);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent to your email!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;

          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 120,
                    color: AppTheme.textSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Not Logged In',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary,
                        AppTheme.primaryLight,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // Avatar
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: AppTheme.accent,
                          child: Text(
                            user.displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Email
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Role Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getRoleIcon(user), size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  user.roleString.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (user.isPremium) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'PREMIUM',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),

                // Profile Edit Section
                const SizedBox(height: 16),

                // Account Section
                _buildSectionHeader(context, 'Account'),

                // Edit Profile Card
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Display Name',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_isEditing)
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: AppTheme.primary),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                    _displayNameController.text =
                                        user.displayName;
                                    _selectedMission = user.mission;
                                    _districtController.text =
                                        user.district ?? '';
                                    _regionController.text = user.region ?? '';
                                    _selectedRole = user.role;
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isEditing)
                          Column(
                            children: [
                              TextField(
                                controller: _displayNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Display Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedMission,
                                decoration: const InputDecoration(
                                  labelText: 'Mission',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.church_outlined),
                                ),
                                items:
                                    AppConstants.missions.map((String mission) {
                                  return DropdownMenuItem<String>(
                                    value: mission,
                                    child: Text(mission),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedMission = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _districtController,
                                decoration: const InputDecoration(
                                  labelText: 'District',
                                  border: OutlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.location_city_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _regionController,
                                decoration: const InputDecoration(
                                  labelText: 'Region',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.map_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  border: OutlineInputBorder(),
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
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = false;
                                      });
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _saveProfile,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.save),
                                    label: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Text(
                            user.displayName,
                            style: const TextStyle(fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                ),

                // Email (read-only)
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.email, color: AppTheme.primary),
                    title: const Text('Email'),
                    subtitle: Text(user.email),
                  ),
                ),

                // Mission
                if (user.mission != null && user.mission!.isNotEmpty)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.church_outlined,
                          color: AppTheme.primary),
                      title: const Text('Mission'),
                      subtitle: Text(user.mission!),
                    ),
                  ),

                // District
                if (user.district != null && user.district!.isNotEmpty)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.location_city_outlined,
                          color: AppTheme.primary),
                      title: const Text('District'),
                      subtitle: Text(user.district!),
                    ),
                  ),

                // Region
                if (user.region != null && user.region!.isNotEmpty)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.map_outlined,
                          color: AppTheme.primary),
                      title: const Text('Region'),
                      subtitle: Text(user.region!),
                    ),
                  ),

                // Role
                if (user.role != null && user.role!.isNotEmpty)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.badge_outlined,
                          color: AppTheme.primary),
                      title: const Text('Role'),
                      subtitle: Text(user.role!),
                    ),
                  ),

                // Security Section
                const SizedBox(height: 16),
                _buildSectionHeader(context, 'Security'),
                _buildListTile(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: _changePassword,
                ),
                _buildListTile(
                  context,
                  icon: Icons.lock_reset,
                  title: 'Reset Password via Email',
                  onTap: _resetPassword,
                ),

                // App Section
                const SizedBox(height: 16),
                _buildSectionHeader(context, 'About'),
                _buildListTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'App Version',
                  trailing: Text(
                    AppConstants.appVersion,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),

                // Logout
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout, color: AppTheme.error),
                      label: const Text(
                        'Logout',
                        style: TextStyle(color: AppTheme.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        trailing: trailing ??
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }

  Color _getRoleColor(UserModel user) {
    switch (user.userRole) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.admin:
        return AppTheme.error;
      case UserRole.missionAdmin:
        return Colors.blue;
      case UserRole.editor:
        return Colors.orange;
      case UserRole.user:
        return AppTheme.success;
    }
  }

  IconData _getRoleIcon(UserModel user) {
    switch (user.userRole) {
      case UserRole.superAdmin:
        return Icons.verified_user;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.missionAdmin:
        return Icons.business;
      case UserRole.editor:
        return Icons.edit;
      case UserRole.user:
        return Icons.person;
    }
  }
}
