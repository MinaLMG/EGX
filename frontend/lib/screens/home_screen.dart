import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'stock_list_screen.dart';
import 'match_wizard_screen.dart';
import 'recommendations_screen.dart';
import 'wallet_screen.dart';
import 'login_screen.dart';
import 'admin_users_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getUser();
    setState(() => _user = user);
  }

  Future<void> _logout() async {
    await _authService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassController,
              decoration: InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            SizedBox(height: 12),
            TextField(
              controller: newPassController,
              decoration: InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            SizedBox(height: 12),
            TextField(
              controller: confirmPassController,
              decoration: InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newPassController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Min 6 characters required')));
                return;
              }
              if (newPassController.text != confirmPassController.text) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
                return;
              }
              
              final result = await _authService.changePassword(
                oldPassController.text, 
                newPassController.text,
              );
              
              if (result['success']) {
                Navigator.pop(ctx);
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EGX Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          if (_user != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'password') _showChangePasswordDialog();
                if (value == 'logout') _logout();
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Chip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_user!.name, style: TextStyle(color: Colors.white, fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                        ],
                      ),
                      backgroundColor: Colors.deepPurple.shade300,
                      avatar: Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'password',
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Change Password'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text('Logout', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.white],
            stops: [0.0, 0.4],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome, ${_user?.name ?? "User"}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                isAdmin
                    ? 'Admin Dashboard — Full system control'
                    : 'Your portfolio intelligence hub',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 32),

              // ---- Common to all users ----
              _MenuCard(
                title: 'Market Data',
                subtitle: 'View all stocks and their current fair values',
                icon: Icons.show_chart,
                color: Colors.blue.shade400,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StockListScreen()),
                ),
              ),
              SizedBox(height: 20),
              _MenuCard(
                title: 'My Wallet',
                subtitle: 'Portfolio rebalancing & buy/sell recommendations',
                icon: Icons.account_balance_wallet,
                color: Colors.teal.shade400,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WalletScreen()),
                ),
              ),

              // ---- Admin-only cards ----
              if (isAdmin) ...[
                SizedBox(height: 20),
                _MenuCard(
                  title: 'ArabicStock Matching Wizard',
                  subtitle: 'Match unmatched stocks sequentially',
                  icon: Icons.auto_fix_high,
                  color: Colors.orange.shade400,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MatchWizardScreen()),
                  ),
                ),
                SizedBox(height: 20),
                _MenuCard(
                  title: 'Recommendations Management',
                  subtitle: 'Manage BF values, RFP, RSP, and more',
                  icon: Icons.recommend,
                  color: Colors.green.shade400,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RecommendationsScreen()),
                  ),
                ),
                SizedBox(height: 20),
                _MenuCard(
                  title: 'User Management',
                  subtitle: 'Approve or reject new registrations',
                  icon: Icons.people_outline,
                  color: Colors.pink.shade400,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminUsersScreen()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
