import 'package:flutter/material.dart';
import '../models/user.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings.dart';
import 'stock_list_screen.dart';
import 'match_wizard_screen.dart';
import 'recommendations_screen.dart';
import 'wallet_screen.dart';
import 'admin_users_screen.dart';

/// Home tab content — embedded inside MainShell.
/// No Scaffold or AppBar here; those live in the shell.
class HomeScreenContent extends StatelessWidget {
  final User? user;

  const HomeScreenContent({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final isAdmin = user?.isAdmin ?? false;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF1A1A2E), const Color(0xFF121212)]
                  : [const Color(0xFF6A1B9A), const Color(0xFFF5F5F5)],
              stops: const [0.0, 0.4],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${l.t('welcome')}, ${user?.name ?? l.t('user_label')} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAdmin ? l.t('admin_subtitle') : l.t('user_subtitle'),
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
                ),
                const SizedBox(height: 32),

                // ── Common to all users ────────────────────────────────────
                _MenuCard(
                  title: l.t('market_data'),
                  subtitle: l.t('market_data_sub'),
                  icon: Icons.show_chart,
                  color: Colors.blue.shade400,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockListScreen())),
                ),
                const SizedBox(height: 20),
                _MenuCard(
                  title: l.t('my_wallet'),
                  subtitle: l.t('my_wallet_sub'),
                  icon: Icons.account_balance_wallet,
                  color: Colors.teal.shade400,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen())),
                ),

                // ── Admin-only ─────────────────────────────────────────────
                if (isAdmin) ...[
                  const SizedBox(height: 20),
                  _MenuCard(
                    title: l.t('admin_matching_wizard'),
                    subtitle: l.t('admin_matching_wizard_sub'),
                    icon: Icons.auto_fix_high,
                    color: Colors.orange.shade400,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchWizardScreen())),
                  ),
                  const SizedBox(height: 20),
                  _MenuCard(
                    title: l.t('admin_recommendations'),
                    subtitle: l.t('admin_recommendations_sub'),
                    icon: Icons.recommend,
                    color: Colors.green.shade400,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecommendationsScreen())),
                  ),
                  const SizedBox(height: 20),
                  _MenuCard(
                    title: l.t('admin_users'),
                    subtitle: l.t('admin_users_sub'),
                    icon: Icons.people_outline,
                    color: Colors.pink.shade400,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUsersScreen())),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Keep the legacy HomeScreen class so old imports don't break ───────────────
// (Main shell will use HomeScreenContent directly)
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HomeScreenContent(user: null);
  }
}

// ── Menu Card ─────────────────────────────────────────────────────────────────
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
