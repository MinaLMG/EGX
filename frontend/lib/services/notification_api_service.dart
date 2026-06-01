import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class NotificationApiService {
  final AuthService _auth = AuthService();

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('${_auth.baseUrl}/notifications'),
        headers: await _auth.authHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
    return [];
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('${_auth.baseUrl}/notifications/unread-count'),
        headers: await _auth.authHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
    } catch (e) {
      print('Error fetching unread count: $e');
    }
    return 0;
  }
}
