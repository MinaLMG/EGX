import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../models/interest.dart';
import '../providers/app_settings.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  final User? user;
  final VoidCallback onLogout;
  final VoidCallback onUserUpdated;

  const ProfileScreen({
    Key? key,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _authService = AuthService();

  UserPreferences? _prefs;
  List<Interest> _allInterests = [];
  List<String> _selectedInterestIds = [];

  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _showPasswordSection = false;
  bool _isSavingPassword = false;
  bool _isSavingInterests = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await _profileService.fetchPreferences();
    final interests = await _profileService.fetchAllInterests();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _allInterests = interests;
        _selectedInterestIds = List.from(prefs.selectedInterestIds);
      });
      // Sync AppSettings with server values
      await AppSettings.instance.setLocale(Locale(prefs.language));
      await AppSettings.instance.setTheme(_themeModeFromString(prefs.theme));
    }
  }

  ThemeMode _themeModeFromString(String s) {
    switch (s) {
      case 'dark':  return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      default:      return ThemeMode.system;
    }
  }

  Future<void> _onThemeChanged(String value) async {
    await _profileService.updatePreferences({'theme': value});
    await AppSettings.instance.setTheme(_themeModeFromString(value));
    if (mounted) {
      setState(() => _prefs = UserPreferences(
        language: _prefs!.language,
        theme: value,
        selectedInterestIds: _selectedInterestIds,
      ));
    }
  }

  Future<void> _onLanguageChanged(String lang) async {
    await _profileService.updatePreferences({'language': lang});
    await AppSettings.instance.setLocale(Locale(lang));
    if (mounted) {
      setState(() => _prefs = UserPreferences(
        language: lang,
        theme: _prefs!.theme,
        selectedInterestIds: _selectedInterestIds,
      ));
    }
  }

  Future<void> _saveInterests() async {
    setState(() => _isSavingInterests = true);
    await _profileService.updateInterests(_selectedInterestIds);
    if (mounted) {
      setState(() => _isSavingInterests = false);
      _showSnack(AppLocalizations.of(context).t('interests_updated'), success: true);
    }
  }

  Future<void> _changePassword() async {
    final l = AppLocalizations.of(context);
    if (_newPassCtrl.text.length < 6) {
      _showSnack(l.t('min_6_chars'));
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _showSnack(l.t('passwords_no_match'));
      return;
    }
    setState(() => _isSavingPassword = true);
    final result = await _authService.changePassword(_oldPassCtrl.text, _newPassCtrl.text);
    if (mounted) {
      setState(() {
        _isSavingPassword = false;
        if (result['success']) _showPasswordSection = false;
      });
      _showSnack(result['success'] ? l.t('password_updated') : result['message'], success: result['success']);
      if (result['success']) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
    ));
  }

  void _confirmLogout() {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.t('logout_confirm_title')),
        content: Text(l.t('logout_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.t('cancel'))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); widget.onLogout(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.t('logout')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final lang = AppSettings.instance.locale.languageCode;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final primary = Theme.of(context).colorScheme.primary;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar Header ────────────────────────────────────────────
              _buildAvatarHeader(primary, isDark),
              const SizedBox(height: 20),

              // ── Account Information ──────────────────────────────────────
              _sectionCard(
                l.t('account_info'),
                Icons.person_outline,
                [
                  _infoRow(l.t('username'), widget.user?.name ?? '—', Icons.badge_outlined),
                  _divider(),
                  _infoRow(l.t('email'), widget.user?.email ?? '—', Icons.email_outlined),
                ],
                cardColor,
              ),
              const SizedBox(height: 16),

              // ── Change Password ──────────────────────────────────────────
              _buildPasswordSection(l, cardColor),
              const SizedBox(height: 16),

              // ── Preferences ──────────────────────────────────────────────
              if (_prefs != null)
                _sectionCard(l.t('preferences'), Icons.tune_outlined, [
                  // Language
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(Icons.language, size: 20, color: primary),
                      const SizedBox(width: 12),
                      Text(l.t('language'), style: const TextStyle(fontSize: 15)),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _prefs!.language,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: 'en', child: Text(l.t('lang_english'))),
                          DropdownMenuItem(value: 'ar', child: Text(l.t('lang_arabic'))),
                        ],
                        onChanged: (v) => v != null ? _onLanguageChanged(v) : null,
                      ),
                    ]),
                  ),
                  _divider(),
                  // Theme
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(Icons.brightness_6_outlined, size: 20, color: primary),
                      const SizedBox(width: 12),
                      Text(l.t('theme'), style: const TextStyle(fontSize: 15)),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _prefs!.theme,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: 'light', child: Text(l.t('theme_light'))),
                          DropdownMenuItem(value: 'dark',  child: Text(l.t('theme_dark'))),
                          DropdownMenuItem(value: 'system', child: Text(l.t('theme_system'))),
                        ],
                        onChanged: (v) => v != null ? _onThemeChanged(v) : null,
                      ),
                    ]),
                  ),
                ], cardColor),
              const SizedBox(height: 16),

              // ── Interests ────────────────────────────────────────────────
              if (_allInterests.isNotEmpty)
                _buildInterestsSection(l, lang, cardColor, primary),
              const SizedBox(height: 24),

              // ── Logout ───────────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(l.t('logout'), style: const TextStyle(color: Colors.red, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarHeader(Color primary, bool isDark) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: primary.withOpacity(0.15),
            child: Text(
              (widget.user?.name ?? 'U').substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.user?.name ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.user?.email ?? '',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection(AppLocalizations l, Color cardColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.lock_outline, color: primary),
            title: Text(l.t('change_password'), style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Icon(_showPasswordSection ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _showPasswordSection = !_showPasswordSection),
          ),
          if (_showPasswordSection) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _passField(_oldPassCtrl, l.t('current_password')),
                  const SizedBox(height: 12),
                  _passField(_newPassCtrl, l.t('new_password')),
                  const SizedBox(height: 12),
                  _passField(_confirmPassCtrl, l.t('confirm_password')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _showPasswordSection = false),
                          child: Text(l.t('cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSavingPassword ? null : _changePassword,
                          style: ElevatedButton.styleFrom(backgroundColor: primary),
                          child: _isSavingPassword
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(l.t('update'), style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterestsSection(AppLocalizations l, String lang, Color cardColor, Color primary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.interests_outlined, color: primary),
            const SizedBox(width: 10),
            Text(l.t('my_interests'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(l.t('interests_subtitle'), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allInterests.map((interest) {
              final selected = _selectedInterestIds.contains(interest.id);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedInterestIds.remove(interest.id);
                    } else {
                      _selectedInterestIds.add(interest.id);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? primary : primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primary.withOpacity(selected ? 0 : 0.3)),
                  ),
                  child: Text(
                    interest.localizedName(lang),
                    style: TextStyle(
                      color: selected ? Colors.white : primary,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingInterests ? null : _saveInterests,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSavingInterests
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l.t('save_interests'), style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _sectionCard(String title, IconData icon, List<Widget> children, Color cardColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade200);

  Widget _passField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
