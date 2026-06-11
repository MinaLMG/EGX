import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';
import 'wallet_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AuthService _authService = AuthService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final l = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final users = await _authService.getUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String userId, String status) async {
    final l = AppLocalizations.of(context);
    try {
      await _authService.updateUserStatus(userId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('status_success'))));
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    }
  }

  Future<void> _resetPassword(String userId) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('reset_confirm_title')),
        content: Text(l.t('reset_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.t('reset_password'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _authService.resetUserPassword(userId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('reset_success'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('admin_users')),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (ctx, i) {
                  final user = _users[i];
                  final isPending = user['status'] == 'pending';
                  final isActive = user['status'] == 'active';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(user['name'] ?? l.t('no_name'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${user['email']}\n${l.t('role')}: ${user['role']} | ${l.t('status')}: ${user['status']}'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPending) ...[
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () => _updateStatus(user['_id'], 'active'),
                              tooltip: l.t('approve'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _updateStatus(user['_id'], 'rejected'),
                              tooltip: l.t('reject'),
                            ),
                          ],
                          if (isActive)
                            IconButton(
                              icon: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => WalletScreen(targetUserId: user['_id'], targetUserName: user['name']),
                                  ),
                                );
                              },
                              tooltip: l.t('simulate_wallet'),
                            ),
                          if (isActive)
                            IconButton(
                              icon: const Icon(Icons.lock_reset, color: Colors.blue),
                              onPressed: () => _resetPassword(user['_id']),
                              tooltip: l.t('reset_password'),
                            ),
                          if (isActive && user['role'] != 'admin')
                            IconButton(
                              icon: const Icon(Icons.block, color: Colors.orange),
                              onPressed: () => _updateStatus(user['_id'], 'pending'),
                              tooltip: l.t('deactivate'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
