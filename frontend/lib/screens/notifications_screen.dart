import 'package:flutter/material.dart';
import '../services/notification_api_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationApiService _service = NotificationApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = items;
        _loading = false;
      });
    }
  }

  String _timeAgo(String isoDate, AppLocalizations l) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return l.t('just_now');
      if (diff.inMinutes < 60) return '${diff.inMinutes} ${l.t('ago_min')}';
      if (diff.inHours < 24) return '${diff.inHours} ${l.t('ago_hour')}';
      return '${diff.inDays} ${l.t('ago_day')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;
        final isArabic = AppSettings.instance.isArabic;

        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF5F0FF),
            appBar: AppBar(
              title: Text(
                '🔔 ${l.t('notifications')}',
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              backgroundColor: isDark ? Theme.of(context).appBarTheme.backgroundColor : primaryColor,
              foregroundColor: isDark ? Theme.of(context).appBarTheme.foregroundColor : Colors.white,
              elevation: 0,
            ),
            body: _loading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _notifications.isEmpty
                     ? _buildEmpty(l, isArabic)
                     : RefreshIndicator(
                        onRefresh: _load,
                        color: primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          itemBuilder: (ctx, i) => _buildCard(_notifications[i], l, isArabic),
                        ),
                      ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(AppLocalizations l, bool isArabic) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: primaryColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            l.t('no_notifications'),
            textAlign: TextAlign.center,
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l.t('notify_market_action'),
              textAlign: TextAlign.center,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> notification, AppLocalizations l, bool isArabic) {
    final bool seen = notification['seen'] ?? true;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: seen
            ? (isDark ? Theme.of(context).cardColor : Colors.white)
            : primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seen
              ? Colors.transparent
              : primaryColor.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: seen
                ? (isDark ? Colors.white10 : Colors.grey.shade100)
                : primaryColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.notifications_active,
            color: seen
                ? (isDark ? Colors.grey.shade400 : Colors.grey.shade500)
                : primaryColor,
            size: 26,
          ),
        ),
        title: SizedBox(
          width: double.infinity,
          child: Text(
            notification['title'] ?? '',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontWeight: seen ? FontWeight.normal : FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['content'] ?? '',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _timeAgo(notification['createdAt'] ?? '', l),
              textAlign: TextAlign.right,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: seen
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
