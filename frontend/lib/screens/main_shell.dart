import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_api_service.dart';
import '../models/user.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'faq_screen.dart';
import 'more_actions_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  _MainShellState createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  final NotificationApiService _notifService = NotificationApiService();
  User? _user;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadUnreadCount();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getUser();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _loadUnreadCount() async {
    final count = await _notifService.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  void _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()));
    _loadUnreadCount();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return HomeScreenContent(user: _user);
      case 1: return ProfileScreen(user: _user, onLogout: _handleLogout, onUserUpdated: _loadUser);
      case 2: return FAQScreen();
      case 3: return MoreActionsScreen(user: _user);
      default: return HomeScreenContent(user: _user);
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when app settings change (locale, theme)
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'EGX',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            actions: [
              // Notification bell
              IconButton(
                onPressed: _openNotifications,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined, size: 26),
                    if (_unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            _unreadCount > 9 ? '9+' : '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          body: _buildBody(),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: l.t('nav_home'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: l.t('nav_profile'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.help_outline),
                  activeIcon: const Icon(Icons.help),
                  label: l.t('nav_faq'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.more_horiz_outlined),
                  activeIcon: const Icon(Icons.more_horiz),
                  label: l.t('nav_more'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
