import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _auth = AuthService();
  final String baseUrl = '${AppConfig.apiBaseUrl}/api';

  Future<List<Stock>> fetchStocks() async {
    final headers = await _auth.authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stocks'), headers: headers);
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Stock.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load stocks');
    }
  }

  Future<Map<String, dynamic>> fetchStocksMatrix() async {
    final headers = await _auth.authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stocks/admin/matrix'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load stocks matrix');
    }
  }

  Future<List<int>> exportStocksExcel() async {
    final headers = await _auth.authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stocks/admin/export-excel'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to export Excel');
    }
  }

  Future<List<ArabicStockMatch>> searchArabicStock(String query) async {
    final headers = await _auth.authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stocks/search-arabic?q=$query'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse
          .map((data) => ArabicStockMatch.fromJson(data))
          .toList();
    } else {
      throw Exception('Failed to search ArabicStock');
    }
  }

  Future<void> matchStock(String ticker, String url) async {
    final headers = await _auth.authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/stocks/$ticker/match-arabic'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to match stock');
    }
  }
}
