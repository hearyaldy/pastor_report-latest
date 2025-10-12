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

  List<Widget> get _screens {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin =
        authProvider.isAuthenticated && (authProvider.user?.isAdmin ?? false);
    final isChurchTreasurer = authProvider.isAuthenticated &&
        (authProvider.user?.userRole == UserRole.churchTreasurer);

    // Always create a list with fixed positions, but use empty containers for hidden tabs
    return [
      // 0: Dashboard (always visible)
      Stack(
        children: [
          // Church Treasurers see Treasurer Dashboard as home, others see regular dashboard
          isChurchTreasurer && !isAdmin
              ? const TreasurerDashboard()
              : const ImprovedDashboardScreen(),
          if (_showDebugInfo && authProvider.isAuthenticated)
            _buildDebugOverlay(authProvider),
        ],
      ),
      // 1: My Mission (hidden for non-admin church treasurers)
      isChurchTreasurer && !isAdmin
          ? Container() // Empty placeholder for church treasurers
          : Stack(
              children: [
                const MyMissionScreen(),
                if (_showDebugInfo && authProvider.isAuthenticated)
                  _buildDebugOverlay(authProvider),
              ],
            ),
      // 2: Profile (always visible)
      const ProfileScreen(),
      // 3: Admin Dashboard (visible for admins and district pastors) or Treasurer Dashboard (visible for treasurers)
      (isAdmin || authProvider.user?.userRole == UserRole.districtPastor)
          ? const ImprovedAdminDashboard()
          : isChurchTreasurer
              ? const TreasurerDashboard()
              : Container(), // Empty placeholder for regular users
    ];
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
    final isAdmin =
        authProvider.isAuthenticated && (authProvider.user?.isAdmin ?? false);
    final isChurchTreasurer = authProvider.isAuthenticated &&
        (authProvider.user?.userRole == UserRole.churchTreasurer);

    // Check if trying to access profile without login
    if (index == 2) {
      if (!authProvider.isAuthenticated) {
        _showLoginPrompt();
        return;
      }
    }

    // Skip My Mission tab for church treasurers who are not admins
    if (index == 1 && isChurchTreasurer && !isAdmin) {
      // Don't update the index, essentially ignoring the tap
      return;
    }

    // Check if trying to access admin/treasury tab
    if (index == 3) {
      if (!authProvider.isAuthenticated) {
        _showLoginPrompt();
        return;
      }

      // Only allow access if user is admin, church treasurer, or district pastor
      if (!isAdmin &&
          !isChurchTreasurer &&
          authProvider.user?.userRole != UserRole.districtPastor) {
        return;
      }
    }

    setState(() {
      _currentIndex = index;
    });
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
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.business_outlined),
              activeIcon: const Icon(Icons.business),
              label: 'My Mission',
              // This item will still be shown but tapping it won't do anything for church treasurers
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Provider.of<AuthProvider>(context).user?.userRole ==
                      UserRole.churchTreasurer
                  ? const Icon(Icons.account_balance_wallet_outlined)
                  : const Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Provider.of<AuthProvider>(context).user?.userRole ==
                      UserRole.churchTreasurer
                  ? const Icon(Icons.account_balance_wallet)
                  : const Icon(Icons.admin_panel_settings),
              label: Provider.of<AuthProvider>(context).user?.userRole ==
                      UserRole.churchTreasurer
                  ? 'Treasury'
                  : 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}
