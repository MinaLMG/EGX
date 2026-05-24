import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:egx_mobile/config/app_config.dart';
import 'auth_service.dart';

class WalletService {
  final String _baseUrl = '${AppConfig.apiBaseUrl}/api/wallet';
  final AuthService _auth = AuthService();

  Future<Map<String, dynamic>> getWallet({String? targetUserId}) async {
    final headers = await _auth.authHeaders();
    var url = _baseUrl;
    if (targetUserId != null) url = '$_baseUrl/admin/$targetUserId';
    
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load wallet');
    }
  }

  Future<void> updateItem(String ticker, int quantity, {double? manualPrice}) async {
    final headers = await _auth.authHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/items'),
      headers: headers,
      body: jsonEncode({
        'ticker': ticker,
        'quantity': quantity,
        'manualPrice': manualPrice,
      }),
    );
    if (response.statusCode != 200) {
        throw Exception('Failed to update wallet item');
    }
  }

  Future<void> removeItem(String ticker) async {
    final headers = await _auth.authHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/items/$ticker'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove wallet item');
    }
  }

  Future<void> updateSettings({
    double? cash,
    double? factor,
    String? mode,
    double? manualTotalOverride,
    String? profitMode,
    double? manualProfitValue,
    double? liquidityFactor,
    double? rebalancingThreshold,
    String? targetUserId,
  }) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{};
    if (cash != null) body['cash'] = cash;
    if (factor != null) body['factor'] = factor;
    if (mode != null) body['mode'] = mode;
    if (manualTotalOverride != null) body['manualTotalOverride'] = manualTotalOverride;
    if (profitMode != null) body['profitMode'] = profitMode;
    if (manualProfitValue != null) body['manualProfitValue'] = manualProfitValue;
    if (liquidityFactor != null) body['liquidityFactor'] = liquidityFactor;
    if (rebalancingThreshold != null) body['rebalancingThreshold'] = rebalancingThreshold;
    if (targetUserId != null) body['userId'] = targetUserId;

    final response = await http.patch(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update settings: ${response.body}');
    }
  }

  // ----- Transactions -----

  Future<void> addTransaction({
    required DateTime date,
    required double value,
    required String type,
    String? targetUserId,
  }) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{
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
    if (response.statusCode != 201 && response.statusCode != 200) {
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
    final body = <String, dynamic>{
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

  // ----- Points-on-Time (balance snapshots) -----

  Future<void> addPointOnTime({
    required DateTime date,
    required double balance,
    double bankRatio = 0,
    String? targetUserId,
  }) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{
      'date': date.toUtc().toIso8601String(),
      'balance': balance,
      'bankRatio': bankRatio,
      if (targetUserId != null) 'userId': targetUserId,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/points'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add snapshot: ${response.body}');
    }
  }

  Future<void> updatePointOnTime({
    required String id,
    required DateTime date,
    required double balance,
    double bankRatio = 0,
    String? targetUserId,
  }) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{
      'date': date.toUtc().toIso8601String(),
      'balance': balance,
      'bankRatio': bankRatio,
      if (targetUserId != null) 'userId': targetUserId,
    };
    final response = await http.put(
      Uri.parse('$_baseUrl/points/$id'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update snapshot: ${response.body}');
    }
  }

  Future<void> deletePointOnTime(String id, {String? targetUserId}) async {
    final headers = await _auth.authHeaders();
    var url = '$_baseUrl/points/$id';
    if (targetUserId != null) url += '?userId=$targetUserId';
    final response = await http.delete(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete snapshot: ${response.body}');
    }
  }

  Future<void> setActivePointOnTime(String? id, {String? targetUserId}) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{'activePointOnTimeId': id};
    if (targetUserId != null) body['userId'] = targetUserId;
    
    final response = await http.patch(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set active snapshot: ${response.body}');
    }
  }

  Future<void> updateManualPricesBulk(Map<String, double> prices, {String? targetUserId}) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{
      'prices': prices,
      if (targetUserId != null) 'userId': targetUserId,
    };
    final response = await http.put(
      Uri.parse('$_baseUrl/manual-prices'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to bulk update prices: ${response.body}');
    }
  }
}
