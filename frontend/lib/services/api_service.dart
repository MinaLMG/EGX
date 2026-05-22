import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS or Web
  static const String baseUrl = 'http://localhost:5000/api';

  Future<List<Stock>> fetchStocks() async {
    final response = await http.get(Uri.parse('$baseUrl/stocks'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Stock.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load stocks');
    }
  }

  Future<List<ArabicStockMatch>> searchArabicStock(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/stocks/search-arabic?q=$query'),
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
    final response = await http.patch(
      Uri.parse('$baseUrl/stocks/$ticker/match-arabic'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to match stock');
    }
  }
}
