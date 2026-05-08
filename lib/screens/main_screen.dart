import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/screens/my_mission_screen.dart';
import 'package:pastor_report/screens/dashboard_screen_improved.dart';
import 'package:pastor_report/screens/profile_screen.dart';
import 'package:pastor_report/screens/admin_dashboard_improved.dart';
import 'package:pastor_report/screens/treasurer/treasurer_dashboard.dart';
import 'package:pastor_report/utils/theme.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/models/user_model.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _showDebugInfo = false;

  bool _hasSpecialTab(UserModel? user) {
    if (user == null) return false;
    return user.isAdmin ||
        user.userRole == UserRole.missionAdmin ||
        user.userRole == UserRole.districtPastor ||
        user.userRole == UserRole.churchTreasurer;
  }

  bool _hasMissionTab(UserModel? user) {
    if (user == null) return true;
    // Church Treasurers (non-admin) skip My Mission
    return !(user.userRole == UserRole.churchTreasurer && !user.isAdmin);
  }

  List<Widget> _buildScreens(AuthProvider authProvider) {
    final user = authProvider.user;
    final isAdmin = user?.isAdmin ?? false;
    final isChurchTreasurer = user?.userRole == UserRole.churchTreasurer;

    final screens = <Widget>[
      // 0: Dashboard
      Stack(
        children: [
          isChurchTreasurer && !isAdmin
              ? const TreasurerDashboard()
              : const ImprovedDashboardScreen(),
          if (_showDebugInfo && authProvider.isAuthenticated)
            _buildDebugOverlay(authProvider),
        ],
      ),
      // 1: My Mission (skipped for non-admin treasurers)
      if (_hasMissionTab(user))
        Stack(
          children: [
            const MyMissionScreen(),
            if (_showDebugInfo && authProvider.isAuthenticated)
              _buildDebugOverlay(authProvider),
          ],
        ),
      // 2: Profile
      const ProfileScreen(),
      // 3: Admin / Treasury (only for eligible roles)
      if (_hasSpecialTab(user))
        (isAdmin || user?.userRole == UserRole.districtPastor)
            ? const ImprovedAdminDashboard()
            : const TreasurerDashboard(),
    ];
    return screens;
  }

  Widget _buildDebugOverlay(AuthProvider authProvider) {
    return Positioned(
      top: 100,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debug Info (${authProvider.user?.email})',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white30),
            Text(
                'Mission: ${_getMissionNameFromId(authProvider.user?.mission)}',
                style: const TextStyle(color: Colors.white)),
            Text('District: ${authProvider.user?.district ?? "Not set"}',
                style: const TextStyle(color: Colors.white)),
            Text('Region: ${authProvider.user?.region ?? "Not set"}',
                style: const TextStyle(color: Colors.white)),
            Text('Role: ${authProvider.user?.role ?? "Not set"}',
                style: const TextStyle(color: Colors.white)),
            Text('Admin: ${authProvider.user?.isAdmin}',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => setState(() => _showDebugInfo = false),
              child: const Text('Close Debug'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to convert mission ID to name
  String _getMissionNameFromId(String? missionId) {
    if (missionId == null || missionId.isEmpty) {
      return "Not set";
    }

    // Try to find the mission by ID in the constants
    for (var mission in AppConstants.missions) {
      if (mission['id'] == missionId) {
        return mission['name'] ?? "Unknown Mission";
      }
    }

    // If not found by ID, maybe it's already the name
    for (var mission in AppConstants.missions) {
      if (mission['name'] == missionId) {
        return missionId;
      }
    }

    return missionId; // Return the ID if name not found
  }

  void _onTabTapped(int index) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final screens = _buildScreens(authProvider);

    // Guard against out-of-range taps (can happen during role changes)
    if (index >= screens.length) return;

    // Profile tab requires login
    final profileIndex = _hasMissionTab(authProvider.user) ? 2 : 1;
    if (index == profileIndex && !authProvider.isAuthenticated) {
      _showLoginPrompt();
      return;
    }

    setState(() => _currentIndex = index);
  }

  Future<void> _showLoginPrompt() async {
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppTheme.primary),
            const SizedBox(width: 10),
            const Text('Login Required'),
          ],
        ),
        content: const Text(
          'You need to sign in to access your profile.\n\nWould you like to login now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Login'),
          ),
        ],
      ),
    );

    if (shouldLogin == true && mounted) {
      final result =
          await Navigator.pushNamed(context, AppConstants.routeWelcome);
      if (result == true && mounted) {
        setState(() {
          _currentIndex = 2; // Switch to profile after successful login
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      onLongPress: () {
        // Toggle debug info on long press anywhere in the app
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated && !_showDebugInfo) {
          setState(() {
            _showDebugInfo = true;
          });
        }
      },
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;
          final screens = _buildScreens(authProvider);
          final safeIndex = _currentIndex.clamp(0, screens.length - 1);

          // Nav items — built dynamically to match screens list
          const dashboardItem = BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          );
          const missionItem = BottomNavigationBarItem(
            icon: Icon(Icons.business_outlined),
            activeIcon: Icon(Icons.business),
            label: 'My Mission',
          );
          const profileItem = BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          );
          final specialItem = _hasSpecialTab(user)
              ? BottomNavigationBarItem(
                  icon: user?.userRole == UserRole.churchTreasurer
                      ? const Icon(Icons.account_balance_wallet_outlined)
                      : const Icon(Icons.admin_panel_settings_outlined),
                  activeIcon: user?.userRole == UserRole.churchTreasurer
                      ? const Icon(Icons.account_balance_wallet)
                      : const Icon(Icons.admin_panel_settings),
                  label: user?.userRole == UserRole.churchTreasurer
                      ? 'Treasury'
                      : 'Admin',
                )
              : null;

          final navItems = [
            dashboardItem,
            if (_hasMissionTab(user)) missionItem,
            profileItem,
            if (specialItem != null) specialItem,
          ];

          // Rail destinations mirror nav items
          final railDestinations = [
            const NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: Text('Dashboard'),
            ),
            if (_hasMissionTab(user))
              const NavigationRailDestination(
                icon: Icon(Icons.business_outlined),
                selectedIcon: Icon(Icons.business),
                label: Text('My Mission'),
              ),
            const NavigationRailDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: Text('Profile'),
            ),
            if (_hasSpecialTab(user))
              NavigationRailDestination(
                icon: user?.userRole == UserRole.churchTreasurer
                    ? const Icon(Icons.account_balance_wallet_outlined)
                    : const Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: user?.userRole == UserRole.churchTreasurer
                    ? const Icon(Icons.account_balance_wallet)
                    : const Icon(Icons.admin_panel_settings),
                label: Text(user?.userRole == UserRole.churchTreasurer
                    ? 'Treasury'
                    : 'Admin'),
              ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1024) {
                return Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: NavigationRail(
                        selectedIndex: safeIndex,
                        onDestinationSelected: _onTabTapped,
                        labelType: NavigationRailLabelType.all,
                        destinations: railDestinations,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: IndexedStack(
                        index: safeIndex,
                        children: screens,
                      ),
                    ),
                  ],
                );
              } else {
                return Scaffold(
                  body: IndexedStack(
                    index: safeIndex,
                    children: screens,
                  ),
                  bottomNavigationBar: BottomNavigationBar(
                    currentIndex: safeIndex,
                    onTap: _onTabTapped,
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: AppTheme.primary,
                    unselectedItemColor: AppTheme.textSecondary,
                    selectedFontSize: 12,
                    unselectedFontSize: 12,
                    items: navItems,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
