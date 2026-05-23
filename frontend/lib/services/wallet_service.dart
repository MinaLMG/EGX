import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class WalletService {
  final AuthService _auth = AuthService();
  String get _baseUrl => '${AppConfig.apiBaseUrl}/api/wallet';

  Future<Map<String, dynamic>> getWallet({String? targetUserId}) async {
    final headers = await _auth.authHeaders();
    final url = targetUserId != null ? '$_baseUrl/admin/$targetUserId' : _baseUrl;
    
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load wallet: ${response.body}');
    }
  }

  Future<void> addTransaction({
    required DateTime date,
    required double value,
    required String type,
    String? targetUserId,
  }) async {
    final headers = await _auth.authHeaders();
    final body = {
      'date': date.toUtc().toIso8601String(),
      'value': value,
      'type': type,
      if (targetUserId != null) 'userId': targetUserId,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/transactions'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add transaction: ${response.body}');
    }
  }

  Future<void> updateTransaction({
    required String id,
    required DateTime date,
    required double value,
    required String type,
    String? targetUserId,
  }) async {
    final headers = await _auth.authHeaders();
    final body = {
      'date': date.toUtc().toIso8601String(),
      'value': value,
      'type': type,
      if (targetUserId != null) 'userId': targetUserId,
    };

    final response = await http.put(
      Uri.parse('$_baseUrl/transactions/$id'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update transaction: ${response.body}');
    }
  }

  Future<void> deleteTransaction(String id, {String? targetUserId}) async {
    final headers = await _auth.authHeaders();
    var url = '$_baseUrl/transactions/$id';
    if (targetUserId != null) url += '?userId=$targetUserId';

    final response = await http.delete(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete transaction: ${response.body}');
    }
  }

  Future<void> updateItem(String ticker, int quantity, {double? manualPrice}) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{'ticker': ticker, 'quantity': quantity};
    if (manualPrice != null) body['manualPrice'] = manualPrice;

    final response = await http.post(
      Uri.parse('$_baseUrl/items'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update item: ${response.body}');
    }
  }

  Future<void> updateSettings({
    double? cash,
    double? factor,
    String? mode,
    double? manualTotalOverride,
    String? profitMode,
    double? manualProfitValue,
  }) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{};
    if (cash != null) body['cash'] = cash;
    if (factor != null) body['factor'] = factor;
    if (mode != null) body['mode'] = mode;
    if (manualTotalOverride != null) body['manualTotalOverride'] = manualTotalOverride;
    if (profitMode != null) body['profitMode'] = profitMode;
    if (manualProfitValue != null) body['manualProfitValue'] = manualProfitValue;

    final response = await http.patch(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update settings: ${response.body}');
    }
  }
}
