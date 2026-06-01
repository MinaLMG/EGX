import 'package:flutter/material.dart';
import '../services/notification_api_service.dart';

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
    setState(() {
      _notifications = items;
      _loading = false;
    });
  }

  String _timeAgo(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
      return 'منذ ${diff.inDays} يوم';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: const Text(
          '🔔 الإشعارات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _notifications.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: Colors.deepPurple,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (ctx, i) => _buildCard(_notifications[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.deepPurple.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'لا توجد إشعارات بعد',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'هنعلمك لما يكون فيه اكشن في البورصة 😄',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> notification) {
    final bool seen = notification['seen'] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: seen ? Colors.white : Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seen ? Colors.transparent : Colors.deepPurple.shade200,
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
            color: seen ? Colors.grey.shade100 : Colors.deepPurple.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.notifications_active,
            color: seen ? Colors.grey.shade500 : Colors.deepPurple,
            size: 26,
          ),
        ),
        title: Text(
          notification['title'] ?? '',
          style: TextStyle(
            fontWeight: seen ? FontWeight.normal : FontWeight.bold,
            fontSize: 15,
          ),
          textDirection: TextDirection.rtl,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['content'] ?? '',
              style: const TextStyle(fontSize: 13),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 6),
            Text(
              _timeAgo(notification['createdAt'] ?? ''),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: seen
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
