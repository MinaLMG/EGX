import 'package:flutter/material.dart';
import '../models/user.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings.dart';
import 'delete_account_screen.dart';

class MoreActionsScreen extends StatelessWidget {
  final User? user;

  const MoreActionsScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.primary;
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final appVersion = '1.0.0';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // ── Account Actions ─────────────────────────────────────────
              _SectionTitle(title: l.t('account_actions')),
              _ActionCard(cardColor: cardColor, isDark: isDark, children: [
                _ActionTile(
                  icon: Icons.download_outlined,
                  title: l.t('export_data'),
                  subtitle: l.t('export_data_sub'),
                  color: Colors.teal,
                  onTap: () => _showComingSoon(context, l),
                ),
                _Divider(),
                _ActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: l.t('privacy_settings'),
                  subtitle: l.t('privacy_settings_sub'),
                  color: Colors.indigo,
                  onTap: () => _showComingSoon(context, l),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Legal ────────────────────────────────────────────────────
              _SectionTitle(title: l.t('legal')),
              _ActionCard(cardColor: cardColor, isDark: isDark, children: [
                _ActionTile(
                  icon: Icons.description_outlined,
                  title: l.t('terms'),
                  color: Colors.blue.shade600,
                  onTap: () => _showComingSoon(context, l),
                ),
                _Divider(),
                _ActionTile(
                  icon: Icons.policy_outlined,
                  title: l.t('privacy_policy'),
                  color: Colors.blue.shade400,
                  onTap: () => _showComingSoon(context, l),
                ),
              ]),
              const SizedBox(height: 20),

              // ── About ────────────────────────────────────────────────────
              _SectionTitle(title: l.t('about')),
              _ActionCard(cardColor: cardColor, isDark: isDark, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.info_outline, color: primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.t('version'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${l.t('version')} $appVersion', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 28),

              // ── Danger Zone ──────────────────────────────────────────────
              _SectionTitle(title: l.t('danger_zone'), color: Colors.red.shade700),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200, width: 1),
                  boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_forever_outlined, color: Colors.red, size: 24),
                  ),
                  title: Text(l.t('delete_account'),
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text(l.t('remove_account_sub'),
                      style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DeleteAccountScreen(user: user)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.t('coming_soon'))),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color? color;
  const _SectionTitle({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: color ?? Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final Color cardColor;
  final bool isDark;
  final List<Widget> children;
  const _ActionCard({required this.cardColor, required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 52, color: Colors.grey.shade200);
  }
}
