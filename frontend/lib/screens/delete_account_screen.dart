import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings.dart';
import 'login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  final User? user;

  const DeleteAccountScreen({Key? key, required this.user}) : super(key: key);

  @override
  _DeleteAccountScreenState createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _profileService = ProfileService();
  final _authService = AuthService();
  final _usernameCtrl = TextEditingController();

  bool _checkboxChecked = false;
  bool _isDeleting = false;
  bool _usernameMatches = false;

  // Step: 1 = warning, 2 = confirmation form
  int _step = 1;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(() {
      final entered = _usernameCtrl.text.trim();
      final expected = widget.user?.name.trim() ?? '';
      setState(() => _usernameMatches = entered == expected && expected.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  bool get _canDelete => _usernameMatches && _checkboxChecked && !_isDeleting;

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    final result = await _profileService.deleteAccount(_usernameCtrl.text.trim());
    if (!mounted) return;
    if (result['success']) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t('delete_success')),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      if (mounted) setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'An error occurred'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: Text(l.t('delete_title')),
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SafeArea(
            child: _step == 1 ? _buildWarningStep(context, l, isDark) : _buildConfirmStep(context, l, isDark),
          ),
        );
      },
    );
  }

  // ── Step 1: Warning ────────────────────────────────────────────────────────
  Widget _buildWarningStep(BuildContext context, AppLocalizations l, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 56),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            l.t('delete_warning_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A1515) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              l.t('delete_warning_body'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.red.shade300 : Colors.red.shade800,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // What will be deleted checklist
          _warningItem('📁', l.t('delete_items_wallet')),
          _warningItem('🔔', l.t('delete_items_notif')),
          _warningItem('⚙️', l.t('delete_items_pref')),
          _warningItem('🔐', l.t('delete_items_auth')),
          const SizedBox(height: 36),
          ElevatedButton(
            onPressed: () => setState(() => _step = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              l.t('confirmation_step'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l.t('cancel'), style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _warningItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ),
      ]),
    );
  }

  // ── Step 2: Confirmation form ──────────────────────────────────────────────
  Widget _buildConfirmStep(BuildContext context, AppLocalizations l, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            l.t('delete_confirm_prompt'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Username input
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _usernameCtrl.text.isEmpty
                    ? Colors.grey.shade300
                    : _usernameMatches
                        ? Colors.green
                        : Colors.red.shade400,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(
                      hintText: widget.user?.name ?? l.t('delete_username_hint'),
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _usernameCtrl.text.isEmpty
                      ? const SizedBox.shrink()
                      : Icon(
                          _usernameMatches ? Icons.check_circle : Icons.cancel,
                          color: _usernameMatches ? Colors.green : Colors.red.shade400,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Checkbox
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _checkboxChecked ? Colors.red.withOpacity(0.05) : null,
              borderRadius: BorderRadius.circular(10),
              border: _checkboxChecked ? Border.all(color: Colors.red.shade200) : null,
            ),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _checkboxChecked,
              onChanged: (v) => setState(() => _checkboxChecked = v ?? false),
              activeColor: Colors.red,
              title: Text(l.t('delete_checkbox'),
                  style: TextStyle(fontSize: 14, color: Colors.red.shade700, fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 36),

          // Delete button
          AnimatedOpacity(
            opacity: _canDelete ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton.icon(
              onPressed: _canDelete ? _deleteAccount : null,
              icon: _isDeleting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.delete_forever, color: Colors.white),
              label: Text(
                _isDeleting ? l.t('deleting') : l.t('delete_button'),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                disabledBackgroundColor: Colors.red.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _step = 1),
            child: Text('← ${l.t('go_back')}', style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
