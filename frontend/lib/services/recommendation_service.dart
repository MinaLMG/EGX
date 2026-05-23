import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class RecommendationService {
  final AuthService _auth = AuthService();
  final String baseUrl = '${AppConfig.apiBaseUrl}/api/recommendations';

  Future<AllRecommendations> fetchAll() async {
    final headers = await _auth.authHeaders();
    final response = await http.get(Uri.parse(baseUrl), headers: headers);
    if (response.statusCode == 200) {
      return AllRecommendations.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load recommendations');
    }
  }

  Future<void> updateBfPrices(List<Map<String, dynamic>> bfValues) async {
    final headers = await _auth.authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/bf-update'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'bfValues': bfValues}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update BF prices');
    }
  }

  Future<void> updateFundamental(String ticker, double target) async {
    final headers = await _auth.authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/fundamental'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'ticker': ticker, 'target': target}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update fundamental recommendation');
    }
  }

  Future<void> deleteFundamental(String id) async {
    final headers = await _auth.authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/fundamental/$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete fundamental recommendation');
    }
  }

  Future<void> updateTechnical(
    String ticker,
    double target,
    String? notes,
  ) async {
    final headers = await _auth.authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/technical'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'ticker': ticker, 'target': target, 'notes': notes}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update technical recommendation');
    }
  }

  Future<void> updateTechnicalById(
    String id,
    double target,
    String? notes,
  ) async {
    final headers = await _auth.authHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/technical/$id'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'target': target, 'notes': notes}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update technical recommendation');
    }
  }

  Future<void> deleteTechnical(String id) async {
    final headers = await _auth.authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/technical/$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete technical recommendation');
    }
  }

  Future<void> updateRFP(List<Map<String, dynamic>> stocks) async {
    final headers = await _auth.authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/rfp'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'stocks': stocks}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update RFP');
    }
  }

  Future<void> updateRSP(List<Map<String, dynamic>> stocks) async {
    final headers = await _auth.authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/rsp'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'stocks': stocks}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update RSP');
    }
  }
}
