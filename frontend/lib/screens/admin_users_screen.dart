import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
    setState(() => _isLoading = true);
    try {
      final users = await _authService.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String userId, String status) async {
    try {
      await _authService.updateUserStatus(userId, status);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User $status successfully')));
      _fetchUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _resetPassword(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password?'),
        content: Text('This will set the password to "00000000". Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Reset', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _authService.resetUserPassword(userId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset to 00000000')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (ctx, i) {
                  final user = _users[i];
                  final isPending = user['status'] == 'pending';
                  final isActive = user['status'] == 'active';

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(user['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${user['email']}\nRole: ${user['role']} | Status: ${user['status']}'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPending) ...[
                            IconButton(
                              icon: Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () => _updateStatus(user['_id'], 'active'),
                              tooltip: 'Approve',
                            ),
                            IconButton(
                              icon: Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _updateStatus(user['_id'], 'rejected'),
                              tooltip: 'Reject',
                            ),
                          ],
                          if (isActive) 
                            IconButton(
                              icon: Icon(Icons.lock_reset, color: Colors.blue),
                              onPressed: () => _resetPassword(user['_id']),
                              tooltip: 'Reset Password',
                            ),
                          if (isActive && user['role'] != 'admin')
                            IconButton(
                              icon: Icon(Icons.block, color: Colors.orange),
                              onPressed: () => _updateStatus(user['_id'], 'pending'),
                              tooltip: 'Deactivate',
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
