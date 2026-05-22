import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class WalletService {
  final AuthService _auth = AuthService();
  String get _baseUrl => '${AppConfig.apiBaseUrl}/api/wallet';

  Future<Map<String, dynamic>> getWallet() async {
    final headers = await _auth.authHeaders();
    final response = await http.get(Uri.parse(_baseUrl), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load wallet: ${response.body}');
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

  Future<void> updateSettings({double? cash, double? factor, String? mode, double? manualTotalOverride}) async {
    final headers = await _auth.authHeaders();
    final body = <String, dynamic>{};
    if (cash != null) body['cash'] = cash;
    if (factor != null) body['factor'] = factor;
    if (mode != null) body['mode'] = mode;
    if (manualTotalOverride != null) body['manualTotalOverride'] = manualTotalOverride;

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
