import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  static Map<String, dynamic> _config = {};

  static Future<void> load() async {
    try {
      final String response = await rootBundle.loadString('assets/cfg/constants.json');
      _config = json.decode(response);
      print('Configuration loaded successfully: $_config');
    } catch (e) {
      print('Error loading configuration: $e');
      // Fallback to localhost if file is missing
      _config = {'api_base_url': 'http://localhost:5000'};
    }
  }

  static String get apiBaseUrl => _config['api_base_url'] ?? 'http://localhost:5000';
}
