import 'package:flutter/material.dart';
import '../services/mubasher_service.dart';

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
        SnackBar(content: Text('Error loading orphans: $e')),
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
        SnackBar(content: Text('Market data refreshed successfully')),
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
        SnackBar(content: Text('Linked $_selectedStock to $_selectedPrice')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Mubasher Matching Wizard'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
          IconButton(
            icon: Icon(Icons.flash_on),
            tooltip: 'Trigger Market Scrape',
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
                            Text('Selected Ticker', style: TextStyle(color: Colors.grey)),
                            Text(
                              _selectedStock ?? 'None',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.link, color: Colors.blueGrey),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Selected Mubasher Name', style: TextStyle(color: Colors.grey)),
                            Text(
                              _selectedPrice ?? 'None',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                            'Unpriced Tickers',
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
                          'Unmatched Prices',
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
