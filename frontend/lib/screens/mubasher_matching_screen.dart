import 'package:flutter/material.dart';
import '../services/mubasher_service.dart';
import '../l10n/app_localizations.dart';

class MubasherMatchingScreen extends StatefulWidget {
  @override
  _MubasherMatchingScreenState createState() => _MubasherMatchingScreenState();
}

class _MubasherMatchingScreenState extends State<MubasherMatchingScreen> {
  final MubasherService _service = MubasherService();
  List<String> _unmatchedStocks = [];
  List<String> _unmatchedPrices = [];
  String? _selectedStock;
  String? _selectedPrice;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.fetchUnmatched();
      setState(() {
        _unmatchedStocks = data['stocks']!;
        _unmatchedPrices = data['prices']!;
        _selectedStock = null;
        _selectedPrice = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).t('error_loading_orphans')}: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerManualUpdate() async {
    setState(() => _isLoading = true);
    try {
      await _service.triggerScrape();
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('market_data_refreshed'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing data: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _match() async {
    if (_selectedStock == null || _selectedPrice == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.createMatch(_selectedStock!, _selectedPrice!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('linked_stocks_success'))),
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error linking items: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('mubasher_matching_wizard')),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
          IconButton(
            icon: Icon(Icons.flash_on),
            tooltip: l.t('trigger_market_scrape'),
            onPressed: _isLoading ? null : _triggerManualUpdate,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.blueGrey.shade50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(l.t('selected_ticker'), style: TextStyle(color: Colors.grey)),
                            Text(
                              _selectedStock ?? l.t('none'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.link, color: Colors.blueGrey),
                      Expanded(
                        child: Column(
                          children: [
                            Text(l.t('selected_mubasher_name'), style: TextStyle(color: Colors.grey)),
                            Text(
                              _selectedPrice ?? l.t('none'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      // Stocks List
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
                          child: _buildList(
                            l.t('unpriced_tickers'),
                            _unmatchedStocks,
                            _selectedStock,
                            (val) => setState(() => _selectedStock = val),
                            Colors.orange,
                          ),
                        ),
                      ),
                      // Prices List
                      Expanded(
                        child: _buildList(
                          l.t('unmatched_prices'),
                          _unmatchedPrices,
                          _selectedPrice,
                          (val) => setState(() => _selectedPrice = val),
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.link),
                    label: Text('Link Selected Pair'),
                    onPressed: (_selectedStock == null || _selectedPrice == null) ? null : _match,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 60),
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildList(String title, List<String> items, String? selected, Function(String) onSelect, Color color) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final isSelected = selected == items[index];
              return ListTile(
                dense: true,
                title: Text(
                  items[index],
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
                tileColor: isSelected ? color : null,
                onTap: () => onSelect(items[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
