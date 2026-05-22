import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';

class RecommendationService {
  static const String baseUrl = 'http://localhost:5000/api/recommendations';

  Future<AllRecommendations> fetchAll() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      return AllRecommendations.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load recommendations');
    }
  }

  Future<void> updateBfPrices(List<Map<String, dynamic>> bfValues) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bf-update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'bfValues': bfValues}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update BF prices');
    }
  }

  Future<void> updateFundamental(String ticker, double target) async {
    final response = await http.post(
      Uri.parse('$baseUrl/fundamental'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ticker': ticker, 'target': target}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update fundamental recommendation');
    }
  }

  Future<void> deleteFundamental(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/fundamental/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete fundamental recommendation');
    }
  }

  Future<void> updateTechnical(String ticker, double target, String? notes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/technical'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ticker': ticker, 'target': target, 'notes': notes}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update technical recommendation');
    }
  }

  Future<void> deleteTechnical(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/technical/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete technical recommendation');
    }
  }

  Future<void> updateRFP(List<Map<String, dynamic>> stocks) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rfp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'stocks': stocks}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update RFP');
    }
  }

  Future<void> updateRSP(List<Map<String, dynamic>> stocks) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rsp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'stocks': stocks}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update RSP');
    }
  }
}
