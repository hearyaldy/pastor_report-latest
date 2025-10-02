import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/screens/dashboard_screen_improved.dart';
import 'package:pastor_report/screens/profile_screen.dart';
import 'package:pastor_report/screens/admin_dashboard.dart';
import 'package:pastor_report/utils/theme.dart';

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

    return [
      Stack(
        children: [
          const ImprovedDashboardScreen(),
          if (_showDebugInfo && authProvider.isAuthenticated)
            _buildDebugOverlay(authProvider),
        ],
      ),
      const ProfileScreen(),
      if (isAdmin) const AdminDashboard(),
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
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debug Info (${authProvider.user?.email})',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white30),
            Text('Mission: ${authProvider.user?.mission ?? "Not set"}',
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

  void _onTabTapped(int index) {
    // Check if trying to access profile without login
    if (index == 1) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        _showLoginPrompt();
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
      final result = await Navigator.pushNamed(context, '/login');
      if (result == true && mounted) {
        setState(() {
          _currentIndex = 1; // Switch to profile after successful login
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
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            if (Provider.of<AuthProvider>(context).isAuthenticated &&
                (Provider.of<AuthProvider>(context).user?.isAdmin ?? false))
              const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings_outlined),
                activeIcon: Icon(Icons.admin_panel_settings),
                label: 'Admin',
              ),
          ],
        ),
      ),
    );
  }
}
