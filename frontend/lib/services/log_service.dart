import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogService {
  static final List<Map<String, String>> logHistory = [];
  static bool _isEnabled = false;
  static const String _prefKey = 'debug_logs_enabled';

  static bool get isEnabled => _isEnabled;

  /// Load initial state from storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefKey) ?? false;
  }

  /// Toggle and save state
  static Future<void> toggle(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  static Future<void> log(String message, {String level = 'info'}) async {
    // We always print to debug console during development
    debugPrint('[$level] $message');

    if (!_isEnabled) return;

    final timestamp = DateTime.now()
        .toString()
        .split('.')
        .first
        .split(' ')
        .last;
    
    // Update local history (keep last 5000)
    logHistory.insert(0, {
      'time': timestamp,
      'msg': message,
      'lvl': level,
    });
    if (logHistory.length > 5000) logHistory.removeLast();
  }

  static Future<void> error(String message, [dynamic error, StackTrace? stack]) async {
    final fullMessage = error != null ? '$message | Error: $error' : message;
    await log(fullMessage, level: 'error');
  }
}
