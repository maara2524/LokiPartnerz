import 'package:flutter/material.dart';
import 'admin_dashboard_page.dart';
import 'admin_users_page.dart';
import 'admin_leads_page.dart';
import 'admin_subscriptions_page.dart';
import 'admin_settings_page.dart';
import 'bbm_admin_theme.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<_AdminTab> _tabs = const [
    _AdminTab(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    _AdminTab(
      label: 'Users',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
    ),
    _AdminTab(
      label: 'Leads',
      icon: Icons.leaderboard_outlined,
      activeIcon: Icons.leaderboard,
    ),
    _AdminTab(
      label: 'Plans',
      icon: Icons.card_membership_outlined,
      activeIcon: Icons.card_membership,
    ),
    _AdminTab(
      label: 'Settings',
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (!mounted || index < 0 || index >= _tabs.length) {
      return;
    }

    if (index == _currentIndex) {
      return;
    }

    if (!_pageController.hasClients) {
      setState(() => _currentIndex = index);
      return;
    }

    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Users & Artists';
      case 2:
        return 'Lead Management';
      case 3:
        return 'Plans & Subscriptions';
      case 4:
        return 'System Settings';
      default:
        return 'BBM Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BbmAdminTheme.bgPrimary,
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) {
          if (!mounted) return;
          setState(() => _currentIndex = i);
        },
        children: const [
          AdminDashboardPage(),
          AdminUsersPage(),
          AdminLeadsPage(),
          AdminSubscriptionsPage(),
          AdminSettingsPage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [BbmAdminTheme.purple700, BbmAdminTheme.purple500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _getTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      // actions: [
      //   Padding(
      //     padding: const EdgeInsets.only(right: 12),
      //     child: Container(
      //       decoration: BoxDecoration(
      //         color: Colors.white.withValues(alpha: 0.15),
      //         borderRadius: BorderRadius.circular(20),
      //       ),
      //       child: IconButton(
      //         icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
      //         onPressed: () {},
      //         padding: const EdgeInsets.all(6),
      //         constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      //       ),
      //     ),
      //   ),
      // ],
      elevation: 0,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: BbmAdminTheme.purple700.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) => _buildNavItem(i)),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final tab = _tabs[index];
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? BbmAdminTheme.purple100 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                isActive ? tab.activeIcon : tab.icon,
                key: ValueKey(isActive),
                color: isActive
                    ? BbmAdminTheme.purple700
                    : Colors.grey.shade400,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? BbmAdminTheme.purple700
                    : Colors.grey.shade400,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _AdminTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
