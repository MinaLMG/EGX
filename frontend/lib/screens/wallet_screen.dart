import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../models/stock.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _walletData;
  List<Stock> _allStocks = [];
  bool _isLoading = true;

  // Settings controllers
  final _cashController = TextEditingController();
  final _factorController = TextEditingController();
  final _totalOverrideController = TextEditingController();
  final _qtyController = TextEditingController();
  Stock? _selectedStock;
  String _mode = 'automatic';
  String _sortCriteria = 'score'; // score (default), supposed, real, deviation
  bool _isAscending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final wallet = await _walletService.getWallet();
      final stocks = await _apiService.fetchStocks();
      setState(() {
        _walletData = wallet;
        _allStocks = stocks;
        _isLoading = false;
        // Pre-fill settings
        if (wallet['wallet'] != null) {
          _cashController.text = (wallet['wallet']['cash'] ?? 0).toString();
          _factorController.text = (wallet['wallet']['factor'] ?? 0.6).toString();
          _mode = wallet['wallet']['mode'] ?? 'automatic';
          _totalOverrideController.text = (wallet['wallet']['manualTotalOverride'] ?? "").toString();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addStock() async {
    if (_selectedStock == null || _qtyController.text.isEmpty) return;
    try {
      await _walletService.updateItem(_selectedStock!.ticker, int.parse(_qtyController.text));
      _qtyController.clear();
      setState(() => _selectedStock = null);
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateManualPrice(String ticker, double price) async {
    try {
      // Find current qty
      final items = _walletData?['wallet']?['items'] as List?;
      final item = items?.firstWhere((i) => i['stock']['ticker'] == ticker, orElse: () => null);
      int qty = item != null ? item['quantity'] : 0;
      
      await _walletService.updateItem(ticker, qty, manualPrice: price);
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _removeStock(String ticker) async {
    try {
      await _walletService.updateItem(ticker, 0);
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _walletService.updateSettings(
        cash: double.tryParse(_cashController.text),
        factor: double.tryParse(_factorController.text),
        mode: _mode,
        manualTotalOverride: double.tryParse(_totalOverrideController.text),
      );
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Color _suggestionColor(String suggestion) {
    switch (suggestion) {
      case 'Buy': return Colors.green;
      case 'Sell': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _suggestionIcon(String suggestion) {
    switch (suggestion) {
      case 'Buy': return Icons.arrow_upward;
      case 'Sell': return Icons.arrow_downward;
      default: return Icons.pause;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My Wallet'),
          backgroundColor: Colors.deepPurple,
          bottom: TabBar(
            tabs: [
              Tab(text: 'My Portfolio', icon: Icon(Icons.account_balance_wallet)),
              Tab(text: 'Pending Actions', icon: Icon(Icons.notifications_active)),
              Tab(text: 'Next Moves', icon: Icon(Icons.trending_up)),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
          ),
          actions: [
            IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildPortfolioTab(),
                  _buildActionsTab(),
                  _buildPredictionsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildPortfolioTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          SizedBox(height: 16),
          _buildSettingsSection(),
          SizedBox(height: 8),
          _buildAddStockSection(),
          SizedBox(height: 16),
          Divider(),
          Text('Full Portfolio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          SizedBox(height: 8),
          _buildAnalysisList(onlyPending: false),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    final hasActions = _walletData?['analysis'] != null &&
        (_walletData!['analysis'] as List).any((item) => item['suggestion'] != 'Hold');

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending Decisions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          Text('Stocks requiring rebalancing (±10% deviation)', style: TextStyle(color: Colors.black54, fontSize: 13)),
          SizedBox(height: 16),
          if (hasActions)
            _buildAnalysisList(onlyPending: true)
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade200),
                    SizedBox(height: 16),
                    Text('Your portfolio is balanced!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87)),
                    Text('No pending Buy/Sell actions.', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPredictionsTab() {
    if (_walletData?['analysis'] == null) return SizedBox.shrink();
    
    // Filter to only 'Hold' stocks (less than 10% diff)
    final List items = (_walletData!['analysis'] as List)
        .where((i) => i['suggestion'] == 'Hold')
        .toList();

    // Sort by absolute deviation percentage (real - supposed) / supposed
    items.sort((a, b) {
      final devA = ((a['realMarketValue'] - a['supposedValue']) / a['supposedValue']).abs();
      final devB = ((b['realMarketValue'] - b['supposedValue']) / b['supposedValue']).abs();
      return devB.compareTo(devA);
    });

    final top3 = items.take(3).toList();
    const margin = 0.01;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          Text('Predicted targets based on current trends', style: TextStyle(color: Colors.black54, fontSize: 13)),
          SizedBox(height: 16),
          if (top3.isEmpty)
             _emptyState('No stocks in wallet to predict.')
          else
            ...top3.map((item) {
              final qty = item['quantity'] as num;
              if (qty == 0) return SizedBox.shrink();

              final isSellingSide = item['realMarketValue'] > item['supposedValue'];
              final targetFactor = isSellingSide ? (1.1 + margin) : (0.9 - margin);
              final targetPrice = (item['supposedValue'] * targetFactor) / qty;
              final tradeValue = item['supposedValue'] * 0.1;
              final currentPrice = item['currentPrice'] as num;

              return Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item['ticker']}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                          _trendBadge(isSellingSide),
                        ],
                      ),
                      Divider(),
                      _predictRow('Trigger Price', 'EGP ${targetPrice.toStringAsFixed(2)}', isPrimary: true),
                      _predictRow('Current Price', 'EGP ${currentPrice.toStringAsFixed(2)}'),
                      _predictRow('Expected Trade Value', 'EGP ${tradeValue.toStringAsFixed(0)}'),
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (currentPrice / targetPrice).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: isSellingSide ? Colors.red.shade300 : Colors.green.shade300,
                        minHeight: 8,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${((currentPrice / targetPrice) * 100).toStringAsFixed(1)}% to target',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _trendBadge(bool isSell) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSell ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSell ? Colors.red.shade200 : Colors.green.shade200),
      ),
      child: Text(
        isSell ? 'SELL TREND' : 'BUY TREND',
        style: TextStyle(color: isSell ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _predictRow(String label, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.black87, fontSize: 14)),
          Text(value, style: TextStyle(
            fontSize: isPrimary ? 18 : 14, 
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
            color: isPrimary ? Colors.black87 : Colors.black54,
          )),
        ],
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(msg, style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_walletData?['totalValue'] == null) return SizedBox.shrink();
    return Card(
      color: Colors.deepPurple.shade50,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Value', style: TextStyle(color: Colors.black54)),
                  Text(
                    'EGP ${((_walletData?['totalValue'] ?? 0) as num).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Diff Value', style: TextStyle(color: Colors.black54)),
                  Text(
                    'EGP ${((_walletData?['diffValue'] ?? 0) as num).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return ExpansionTile(
      title: Text('Wallet Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      leading: Icon(Icons.settings, color: Colors.deepPurple),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _mode,
                decoration: InputDecoration(labelText: 'Calculation Mode', border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'automatic', child: Text('Automatic (Market Prices)')),
                  DropdownMenuItem(value: 'manual', child: Text('Manual (Custom Prices)')),
                ],
                onChanged: (val) => setState(() => _mode = val!),
              ),
              SizedBox(height: 12),
              if (_mode == 'manual') ...[
                TextField(
                  controller: _totalOverrideController,
                  decoration: InputDecoration(labelText: 'Manual Total Portfolio Value (EGP)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 12),
              ],
              TextField(
                controller: _cashController,
                decoration: InputDecoration(labelText: 'Cash (EGP)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _factorController,
                decoration: InputDecoration(labelText: 'Factor (default 0.6)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: Icon(Icons.save),
                label: Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 45),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddStockSection() {
    return ExpansionTile(
      title: Text('Add Stock to Wallet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      leading: Icon(Icons.add_circle_outline, color: Colors.green),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Autocomplete<Stock>(
                displayStringForOption: (Stock s) => '${s.ticker} - ${s.name ?? ""}',
                optionsBuilder: (TextEditingValue val) {
                  if (val.text.isEmpty) return Iterable<Stock>.empty();
                  return _allStocks.where((s) =>
                      s.ticker.contains(val.text.toUpperCase()) ||
                      (s.name?.toUpperCase() ?? '').contains(val.text.toUpperCase()));
                },
                onSelected: (Stock s) => setState(() => _selectedStock = s),
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                  return TextField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: InputDecoration(
                      labelText: 'Select Stock',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              SizedBox(height: 12),
              TextField(
                controller: _qtyController,
                decoration: InputDecoration(labelText: 'Quantity (Shares)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _selectedStock == null ? null : _addStock,
                icon: Icon(Icons.add),
                label: Text('Add to Wallet'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 45),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisList({required bool onlyPending}) {
    if (_walletData?['analysis'] == null) return SizedBox.shrink();

    final List items = List.from(_walletData!['analysis']);

    // Sort Logic
    items.sort((a, b) {
      dynamic valA, valB;
      switch (_sortCriteria) {
        case 'supposed':
          valA = a['supposedValue'];
          valB = b['supposedValue'];
          break;
        case 'real':
          valA = a['realMarketValue'];
          valB = b['realMarketValue'];
          break;
        case 'deviation':
          valA = ((a['realMarketValue'] - a['supposedValue']) / a['supposedValue']).abs();
          valB = ((b['realMarketValue'] - b['supposedValue']) / b['supposedValue']).abs();
          break;
        default: // score (backend default order)
          return 0; // Keep current order if score selected
      }
      return _isAscending ? valA.compareTo(valB) : valB.compareTo(valA);
    });

    final filteredItems = onlyPending ? items.where((i) => i['suggestion'] != 'Hold').toList() : items;

    if (filteredItems.isEmpty && !onlyPending) {
      return _emptyState('Your wallet is empty.');
    }

    return Column(
      children: [
        if (!onlyPending) _buildSortHeader(),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final suggestion = item['suggestion'] ?? 'Hold';
            final gap = (item['gap'] as num?) ?? 0;
            final deviation = ((item['realMarketValue'] - item['supposedValue']) / item['supposedValue']) * 100;

            return Card(
              margin: EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: _suggestionColor(suggestion).withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: ListTile(
                isThreeLine: true,
                onTap: () => _showManageModal(item),
                leading: CircleAvatar(
                  backgroundColor: _suggestionColor(suggestion).withOpacity(0.15),
                  child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: _suggestionColor(suggestion))),
                ),
                title: Row(
                  children: [
                    Text(
                      '${item['ticker']}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '(${deviation.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (item['realMarketValue'] > item['supposedValue']) ? Colors.red : Colors.green,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.settings, size: 14, color: Colors.blue.withOpacity(0.5)),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qty: ${item['quantity']}  ×  EGP ${(item['currentPrice'] as num).toStringAsFixed(2)}', style: TextStyle(color: Colors.black87)),
                    Text(
                      'Real: EGP ${(item['realMarketValue'] as num).toStringAsFixed(0)}  →  Supposed: EGP ${(item['supposedValue'] as num).toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                trailing: SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_suggestionIcon(suggestion), color: _suggestionColor(suggestion), size: 20),
                      Text(suggestion, style: TextStyle(color: _suggestionColor(suggestion), fontWeight: FontWeight.bold, fontSize: 10)),
                      Text('EGP ${gap.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSortHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text('Sort by:', style: TextStyle(fontSize: 12, color: Colors.black54)),
          SizedBox(width: 8),
          _sortChip('Supposed', 'supposed'),
          _sortChip('Real', 'real'),
          _sortChip('% Diff', 'deviation'),
          Spacer(),
          IconButton(
            icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
            onPressed: () => setState(() => _isAscending = !_isAscending),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            color: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String criteria) {
    final isSelected = _sortCriteria == criteria;
    return GestureDetector(
      onTap: () => setState(() => _sortCriteria = criteria),
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.deepPurple : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.deepPurple : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  void _showManageModal(Map<String, dynamic> item) {
    final qtyController = TextEditingController(text: item['quantity'].toString());
    final priceController = TextEditingController(text: item['currentPrice'].toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 32,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Manage ${item['ticker']}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            SizedBox(height: 24),
            TextField(
              controller: qtyController,
              decoration: InputDecoration(labelText: 'Quantity (Shares)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            if (_mode == 'manual') ...[
              SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Custom Price (EGP)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final newQty = int.tryParse(qtyController.text);
                final newPrice = double.tryParse(priceController.text);
                if (newQty != null) {
                  Navigator.pop(ctx);
                  await _walletService.updateItem(
                    item['ticker'],
                    newQty,
                    manualPrice: _mode == 'manual' ? newPrice : null,
                  );
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Update Stock Info'),
            ),
            SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _removeStock(item['ticker']);
              },
              icon: Icon(Icons.delete, color: Colors.red),
              label: Text('Remove From Wallet', style: TextStyle(color: Colors.red)),
              style: TextButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
