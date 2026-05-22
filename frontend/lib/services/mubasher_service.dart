import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class MubasherService {
  final String baseUrl = '${AppConfig.apiBaseUrl}/api/mubasher';

  Future<Map<String, List<String>>> fetchUnmatched() async {
    final response = await http.get(Uri.parse('$baseUrl/unmatched'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'stocks': List<String>.from(data['stocks']),
        'prices': List<String>.from(data['prices']),
      };
    } else {
      throw Exception('Failed to load unmatched items');
    }
  }

  Future<void> createMatch(String ticker, String mubasherName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/match'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ticker': ticker, 'mubasherName': mubasherName}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create match');
    }
  }

  Future<void> triggerScrape() async {
    final response = await http.post(Uri.parse('$baseUrl/trigger'));
    if (response.statusCode != 200) {
      throw Exception('Failed to trigger manual update');
    }
  }
}
