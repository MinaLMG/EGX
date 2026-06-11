import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/faq.dart';
import '../models/interest.dart';
import '../models/user_preferences.dart';

class ProfileService {
  final AuthService _auth = AuthService();

  String get _baseUrl => '${AppConfig.apiBaseUrl}/api';

  // ── Preferences ──────────────────────────────────────────────────────────────

  Future<UserPreferences> fetchPreferences() async {
    final headers = await _auth.authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/profile/preferences'), headers: headers);
    if (res.statusCode == 200) {
      return UserPreferences.fromJson(json.decode(res.body));
    }
    return UserPreferences.defaults();
  }

  Future<void> updatePreferences(Map<String, dynamic> data) async {
    final headers = await _auth.authHeaders();
    await http.patch(
      Uri.parse('$_baseUrl/profile/preferences'),
      headers: headers,
      body: jsonEncode(data),
    );
  }

  // ── Interests ─────────────────────────────────────────────────────────────────

  Future<List<Interest>> fetchAllInterests() async {
    final headers = await _auth.authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/profile/interests'), headers: headers);
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((e) => Interest.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> updateInterests(List<String> interestIds) async {
    final headers = await _auth.authHeaders();
    await http.patch(
      Uri.parse('$_baseUrl/profile/interests'),
      headers: headers,
      body: jsonEncode({'interestIds': interestIds}),
    );
  }

  // ── FAQ ───────────────────────────────────────────────────────────────────────

  Future<List<FAQ>> fetchFAQs() async {
    final headers = await _auth.authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/faq'), headers: headers);
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((e) => FAQ.fromJson(e)).toList();
    }
    return [];
  }

  // ── Account Deletion ──────────────────────────────────────────────────────────

  /// Returns a map with 'success' and 'message' keys.
  Future<Map<String, dynamic>> deleteAccount(String username) async {
    final headers = await _auth.authHeaders();
    final res = await http.delete(
      Uri.parse('$_baseUrl/profile/account'),
      headers: headers,
      body: jsonEncode({'username': username}),
    );
    final data = json.decode(res.body);
    return {
      'success': res.statusCode == 200,
      'message': data['message'] ?? 'An error occurred',
    };
  }
}
