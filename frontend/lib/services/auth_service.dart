import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  String get _baseUrl => '${AppConfig.apiBaseUrl}/api/auth';

  static String? _cachedToken;
  static User? _cachedUser;

  // ---- Token Management ----

  Future<void> _saveSession(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode({
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
    }));
    _cachedToken = token;
    _cachedUser = user;
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<User?> getUser() async {
    if (_cachedUser != null) return _cachedUser;
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    _cachedUser = User.fromJson(jsonDecode(userJson));
    return _cachedUser;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _cachedToken = null;
    _cachedUser = null;
  }

  // ---- Auth header helper ----

  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---- API Calls ----

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return {'success': true, 'message': data['message']};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final user = User.fromJson(data['user']);
      await _saveSession(data['token'], user);
      return {'success': true, 'user': user};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    }
  }

  Future<List<dynamic>> getUsers() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users'),
      headers: await authHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<void> updateUserStatus(String userId, String status) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/users/$userId/status'),
      headers: await authHeaders(),
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update user status');
    }
  }

  Future<void> resetUserPassword(String userId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/users/$userId/reset-password'),
      headers: await authHeaders(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to reset password');
    }
  }

  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/change-password'),
      headers: await authHeaders(),
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword
      }),
    );
    final data = jsonDecode(response.body);
    return {
      'success': response.statusCode == 200,
      'message': data['message'] ?? 'Failed to update password',
    };
  }

  Future<void> updateFcmToken(String? fcmToken) async {
    if (fcmToken == null) return;
    try {
      await http.patch(
        Uri.parse('$_baseUrl/fcm-token'),
        headers: await authHeaders(),
        body: jsonEncode({'fcmToken': fcmToken}),
      );
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }
}
