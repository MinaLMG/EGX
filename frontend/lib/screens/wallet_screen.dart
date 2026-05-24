import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../models/stock.dart';

class WalletScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  WalletScreen({this.targetUserId, this.targetUserName});

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
  final _liquidityController = TextEditingController();
  final _thresholdController = TextEditingController();

  // Profit controllers
  final _valController = TextEditingController();
  final _manualProfitValueController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _targetType = 'deposit';
  String _profitMode = 'automatic';

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
      final wallet = await _walletService.getWallet(
        targetUserId: widget.targetUserId,
      );
      final stocks = await _apiService.fetchStocks();
      setState(() {
        _walletData = wallet;
        _allStocks = stocks;
        _isLoading = false;
        // Pre-fill settings
        if (wallet['wallet'] != null) {
          _cashController.text = (wallet['wallet']['cash'] ?? 0).toString();
          _factorController.text = (wallet['wallet']['factor'] ?? 0.6)
              .toString();
          _mode = wallet['wallet']['mode'] ?? 'automatic';
          _totalOverrideController.text =
              (wallet['wallet']['manualTotalOverride'] ?? "").toString();

          _profitMode = wallet['wallet']['profitMode'] ?? 'automatic';
          _manualProfitValueController.text =
              (wallet['wallet']['manualProfitValue'] ?? "").toString();

          _liquidityController.text =
              (wallet['wallet']['liquidityFactor'] ?? 0.0).toString();
          _thresholdController.text =
              (wallet['wallet']['rebalancingThreshold'] ?? 0.10).toString();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addStock() async {
    if (_selectedStock == null || _qtyController.text.isEmpty) return;
    try {
      await _walletService.updateItem(
        _selectedStock!.ticker,
        int.parse(_qtyController.text),
        targetUserId: widget.targetUserId,
      );
      _qtyController.clear();
      setState(() => _selectedStock = null);
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateManualPrice(String ticker, double price) async {
    try {
      // Find current qty
      final items = _walletData?['wallet']?['items'] as List?;
      final item = items?.firstWhere(
        (i) => i['stock']['ticker'] == ticker,
        orElse: () => null,
      );
      int qty = item != null ? item['quantity'] : 0;

      await _walletService.updateItem(
        ticker,
        qty,
        manualPrice: price,
        targetUserId: widget.targetUserId,
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _removeStock(String ticker) async {
    try {
      await _walletService.updateItem(
        ticker,
        0,
        targetUserId: widget.targetUserId,
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _walletService.updateSettings(
        cash: double.tryParse(_cashController.text),
        factor: double.tryParse(_factorController.text),
        mode: _mode,
        manualTotalOverride: double.tryParse(_totalOverrideController.text),
        profitMode: _profitMode,
        manualProfitValue: double.tryParse(_manualProfitValueController.text),
        liquidityFactor: double.tryParse(_liquidityController.text),
        rebalancingThreshold: double.tryParse(_thresholdController.text),
        targetUserId: widget.targetUserId,
      );
      await _loadData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Settings saved')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Profit Actions
  Future<void> _saveTransaction({String? id}) async {
    try {
      final val = double.tryParse(_valController.text) ?? 0;
      if (id == null) {
        await _walletService.addTransaction(
          date: _selectedDate,
          value: val,
          type: _targetType,
          targetUserId: widget.targetUserId,
        );
      } else {
        await _walletService.updateTransaction(
          id: id,
          date: _selectedDate,
          value: val,
          type: _targetType,
          targetUserId: widget.targetUserId,
        );
      }
      _valController.clear();
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteTransaction(String id) async {
    try {
      await _walletService.deleteTransaction(
        id,
        targetUserId: widget.targetUserId,
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Snapshot actions
  Future<void> _setActiveSnapshot(String? id) async {
    try {
      await _walletService.setActivePointOnTime(
        id,
        targetUserId: widget.targetUserId,
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteSnapshot(String id) async {
    try {
      await _walletService.deletePointOnTime(
        id,
        targetUserId: widget.targetUserId,
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Admin-only: Add / edit a snapshot
  void _showSnapshotDialog({Map? snap}) {
    final balanceCtrl = TextEditingController(
      text: snap != null ? snap['balance'].toString() : '',
    );
    final bankRatioCtrl = TextEditingController(
      text: snap != null ? (snap['bankRatio'] ?? '0').toString() : '0',
    );
    DateTime snapDate = snap != null
        ? DateTime.parse(snap['date']).toLocal()
        : DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(snap == null ? 'Add Balance Snapshot' : 'Edit Snapshot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${snapDate.toString().split(' ')[0]}'),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: snapDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(), // no future dates
                    );
                    if (d != null) setLocal(() => snapDate = d);
                  },
                ),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Wallet Balance (EGP)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: bankRatioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Bank Interest Ratio (Annual %)',
                    border: OutlineInputBorder(),
                    helperText: 'e.g. 25 for 25% annual return',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final bal = double.tryParse(balanceCtrl.text);
                final ratio = double.tryParse(bankRatioCtrl.text) ?? 0;
                if (bal == null) return;
                Navigator.pop(ctx);
                try {
                  if (snap == null) {
                    await _walletService.addPointOnTime(
                      date: snapDate,
                      balance: bal,
                      bankRatio: ratio,
                      targetUserId: widget.targetUserId,
                    );
                  } else {
                    await _walletService.updatePointOnTime(
                      id: snap['_id'],
                      date: snapDate,
                      balance: bal,
                      bankRatio: ratio,
                      targetUserId: widget.targetUserId,
                    );
                  }
                  await _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Color _suggestionColor(String suggestion) {
    switch (suggestion) {
      case 'Buy':
        return Colors.green;
      case 'Sell':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _suggestionIcon(String suggestion) {
    switch (suggestion) {
      case 'Buy':
        return Icons.arrow_upward;
      case 'Sell':
        return Icons.arrow_downward;
      default:
        return Icons.pause;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.targetUserName != null
        ? 'Simulating: ${widget.targetUserName}'
        : 'My Wallet';
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.deepPurple,
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                text: 'Portfolio',
                icon: Icon(Icons.account_balance_wallet, size: 20),
              ),
              Tab(
                text: 'Pending',
                icon: Icon(Icons.notifications_active, size: 20),
              ),
              Tab(text: 'Next', icon: Icon(Icons.trending_up, size: 20)),
              Tab(text: 'Profit', icon: Icon(Icons.calculate, size: 20)),
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
                  _buildProfitTab(),
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
          Text(
            'Full Portfolio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          if (_mode == 'manual')
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton.icon(
                onPressed: _showBulkPriceDialog,
                icon: Icon(Icons.edit_note),
                label: Text('Bulk Edit Manual Prices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 45),
                ),
              ),
            ),
          _buildAnalysisList(onlyPending: false),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    final hasActions =
        _walletData?['analysis'] != null &&
        (_walletData!['analysis'] as List).any(
          (item) => item['suggestion'] != 'Hold',
        );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Decisions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          Text(
            'Stocks requiring rebalancing (±10% deviation)',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          SizedBox(height: 16),
          if (hasActions)
            _buildAnalysisList(onlyPending: true)
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green.shade200,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Your portfolio is balanced!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'No pending Buy/Sell actions.',
                      style: TextStyle(color: Colors.black54),
                    ),
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
      final devA =
          ((a['realMarketValue'] - a['supposedValue']) / a['supposedValue'])
              .abs();
      final devB =
          ((b['realMarketValue'] - b['supposedValue']) / b['supposedValue'])
              .abs();
      return devB.compareTo(devA);
    });

    final top3 = items.take(3).toList();
    const margin = 0.01;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          Text(
            'Predicted targets based on current trends',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          SizedBox(height: 16),
          if (top3.isEmpty)
            _emptyState('No stocks in wallet to predict.')
          else
            ...top3.map((item) {
              final qty = item['quantity'] as num;
              if (qty == 0) return SizedBox.shrink();

              final isSellingSide =
                  item['realMarketValue'] > item['supposedValue'];
              final targetFactor = isSellingSide
                  ? (1.1 + margin)
                  : (0.9 - margin);
              final targetPrice = (item['supposedValue'] * targetFactor) / qty;
              final tradeValue = item['supposedValue'] * 0.1;
              final currentPrice = item['currentPrice'] as num;

              return Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item['ticker']}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          _trendBadge(isSellingSide),
                        ],
                      ),
                      Divider(),
                      _predictRow(
                        'Trigger Price',
                        'EGP ${targetPrice.toStringAsFixed(2)}',
                        isPrimary: true,
                      ),
                      _predictRow(
                        'Current Price',
                        'EGP ${currentPrice.toStringAsFixed(2)}',
                      ),
                      _predictRow(
                        'Expected Trade Value',
                        'EGP ${tradeValue.toStringAsFixed(0)}',
                      ),
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (currentPrice / targetPrice).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: isSellingSide
                            ? Colors.red.shade300
                            : Colors.green.shade300,
                        minHeight: 8,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${((targetPrice - currentPrice) / currentPrice * 100).toStringAsFixed(1)}% to target',
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
        border: Border.all(
          color: isSell ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Text(
        isSell ? 'SELL TREND' : 'BUY TREND',
        style: TextStyle(
          color: isSell ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
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
          Text(
            value,
            style: TextStyle(
              fontSize: isPrimary ? 18 : 14,
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
              color: isPrimary ? Colors.black87 : Colors.black54,
            ),
          ),
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

  Widget _buildProfitTab() {
    final profit = _walletData?['profit'];
    final trans = (_walletData?['wallet']?['transactions'] as List?) ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Performance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          SizedBox(height: 16),
          _buildProfitSummary(profit),
          SizedBox(height: 24),
          _buildSnapshotsSection(),
          SizedBox(height: 24),
          _buildProfitSettingsSection(),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showTransactionDialog(),
                icon: Icon(Icons.add, size: 18),
                label: Text('New'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildTransactionList(trans),
        ],
      ),
    );
  }

  Widget _buildSnapshotsSection() {
    final points = (_walletData?['wallet']?['pointsOnTime'] as List?) ?? [];
    final activeId = _walletData?['wallet']?['activePointOnTimeId'] as String?;
    final isAdmin = widget.targetUserId != null;

    // Sort desc by date
    final sorted = List.from(points)
      ..sort((a, b) => b['date'].compareTo(a['date']));

    return ExpansionTile(
      leading: Icon(Icons.timeline, color: Colors.indigo),
      title: Text(
        'Balance Snapshots',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        activeId != null
            ? 'Profit anchored to a snapshot (tap to change)'
            : 'Using all transactions (tap to anchor)',
        style: TextStyle(fontSize: 12),
      ),
      children: [
        if (sorted.isEmpty)
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              isAdmin
                  ? 'No snapshots yet. Add one below.'
                  : 'No snapshots available. Ask an admin to add one.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final snap = sorted[i];
              final snapId = snap['_id'] as String;
              final isActive = activeId == snapId;
              final date = DateTime.parse(snap['date']).toLocal();
              final balance = (snap['balance'] as num).toDouble();

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isActive ? Colors.indigo : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                color: isActive ? Colors.indigo.shade50 : null,
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () => _setActiveSnapshot(isActive ? null : snapId),
                    child: Icon(
                      isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isActive ? Colors.indigo : Colors.grey,
                    ),
                  ),
                  title: Text(
                    'EGP ${balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.indigo : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '${date.toString().split(' ')[0]}${isActive ? '  •  ACTIVE' : ''}\nBank Ratio: ${snap['bankRatio'] ?? 0}%',
                    style: TextStyle(
                      color: isActive ? Colors.indigo : Colors.black54,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                  trailing: isAdmin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, size: 18),
                              onPressed: () => _showSnapshotDialog(snap: snap),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteSnapshot(snapId),
                            ),
                          ],
                        )
                      : null,
                  onTap: () => _setActiveSnapshot(isActive ? null : snapId),
                ),
              );
            },
          ),
        if (isAdmin)
          Padding(
            padding: EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: () => _showSnapshotDialog(),
              icon: Icon(Icons.add, size: 18),
              label: Text('Add Snapshot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 42),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfitSettingsSection() {
    return ExpansionTile(
      title: Text(
        'Revenue Calculation Mode',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('Current Value Source: ${_profitMode.toUpperCase()}'),
      leading: Icon(Icons.tune, color: Colors.deepPurple),
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _profitMode,
                decoration: InputDecoration(
                  labelText: 'Calculation Source',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'automatic',
                    child: Text('Automatic (Wallet + Stocks)'),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('Manual (User Entered Value)'),
                  ),
                ],
                onChanged: (val) => setState(() => _profitMode = val!),
              ),
              if (_profitMode == 'manual') ...[
                SizedBox(height: 12),
                TextField(
                  controller: _manualProfitValueController,
                  decoration: InputDecoration(
                    labelText: 'Custom Total Wallet Value (EGP)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: Icon(Icons.save),
                label: Text('Save Profit Settings'),
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

  Widget _buildProfitSummary(Map<String, dynamic>? profit) {
    if (profit == null) return SizedBox.shrink();
    final activeSnap = _walletData?['activeSnapshot'];
    final bankComp = _walletData?['bankComparison'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeSnap != null) _buildActiveSnapshotBanner(activeSnap),
        if (activeSnap != null) SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _infoCard(
              'Effective Value',
              'EGP ${_fmt(profit['walletEffectiveValue'])}',
              Icons.account_balance,
            ),
            _infoCard(
              'Net Revenue',
              'EGP ${_fmt(profit['revenue'])}',
              Icons.monetization_on,
              color: (profit['revenue'] ?? 0) >= 0 ? Colors.green : Colors.red,
            ),
            _infoCard(
              'Revenue %',
              '${((profit['revenuePercentage'] ?? 0) * 100).toStringAsFixed(2)}%',
              Icons.percent,
            ),
            _infoCard(
              'Daily Ratio',
              '${profit['dailyRatio']?.toStringAsFixed(6)}',
              Icons.today,
            ),
            _infoCard(
              'Yearly Return',
              '${((profit['yearlyRevenue'] ?? 0) * 100).toStringAsFixed(1)}%',
              Icons.calendar_today,
              color: Colors.orange,
            ),
            _infoCard(
              'Total Duration',
              '${(profit['totalDuration'] ?? 0).toInt()} Days',
              Icons.timer,
            ),
            if (bankComp != null) ...[
              _infoCard(
                'Extra Revenue',
                'EGP ${_fmt(bankComp['extraRevenue'])}',
                Icons.star,
                color: (bankComp['extraRevenue'] ?? 0) >= 0
                    ? Colors.blue
                    : Colors.orange,
              ),
              _infoCard(
                'Bank Revenue',
                'EGP ${_fmt(bankComp['bankSupposedRevenue'])}',
                Icons.account_balance_outlined,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActiveSnapshotBanner(Map<String, dynamic> snap) {
    final date = DateTime.parse(
      snap['date'],
    ).toLocal().toString().split(' ')[0];
    final balance = (snap['balance'] as num).toStringAsFixed(0);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.anchor, color: Colors.indigo, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anchored to snapshot',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.indigo.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$date  •  EGP $balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Transactions before this date are excluded',
                  style: TextStyle(fontSize: 10, color: Colors.indigo.shade400),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _setActiveSnapshot(null),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              'Clear',
              style: TextStyle(color: Colors.indigo, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon, {Color? color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color ?? Colors.deepPurple),
            SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List trans) {
    if (trans.isEmpty) return _emptyState('No transactions yet.');
    // Sort transactions by date desc
    final sorted = List.from(trans)
      ..sort((a, b) => b['date'].compareTo(a['date']));

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final t = sorted[i];
        final isDep = t['type'] == 'deposit';
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              isDep ? Icons.add_circle : Icons.remove_circle,
              color: isDep ? Colors.green : Colors.red,
            ),
            title: Text(
              'EGP ${t['value']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${DateTime.parse(t['date']).toLocal().toString().split(' ')[0]} - ${t['type'].toUpperCase()}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 18),
                  onPressed: () => _showTransactionDialog(t: t),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 18),
                  onPressed: () => _deleteTransaction(t['_id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTransactionDialog({Map? t}) {
    if (t != null) {
      _valController.text = t['value'].toString();
      _selectedDate = DateTime.parse(t['date']).toLocal();
      _targetType = t['type'];
    } else {
      _valController.clear();
      _selectedDate = DateTime.now();
      _targetType = 'deposit';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          return AlertDialog(
            title: Text(t == null ? 'Add Transaction' : 'Edit Transaction'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _targetType,
                  items: [
                    DropdownMenuItem(value: 'deposit', child: Text('Deposit')),
                    DropdownMenuItem(
                      value: 'withdrawal',
                      child: Text('Withdrawal'),
                    ),
                  ],
                  onChanged: (v) => setLocalState(() => _targetType = v!),
                  decoration: InputDecoration(labelText: 'Type'),
                ),
                TextField(
                  controller: _valController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Value (EGP)'),
                ),
                ListTile(
                  title: Text(
                    'Date: ${_selectedDate.toString().split(' ')[0]}',
                  ),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setLocalState(() => _selectedDate = d);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveTransaction(id: t?['_id']);
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return "0.00";
    return (val as num).toStringAsFixed(0);
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
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
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
      title: Text(
        'Wallet Settings',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      leading: Icon(Icons.settings, color: Colors.deepPurple),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _mode,
                decoration: InputDecoration(
                  labelText: 'Calculation Mode',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'automatic',
                    child: Text('Automatic (Market Prices)'),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('Manual (Custom Prices)'),
                  ),
                ],
                onChanged: (val) => setState(() => _mode = val!),
              ),
              SizedBox(height: 12),
              SizedBox(height: 12),
              /* Manual Total Override removed from portfolio - functionality moved to profit context only */
              TextField(
                controller: _cashController,
                decoration: InputDecoration(
                  labelText: 'Cash (EGP)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showSensitiveSettingsDialog,
                icon: Icon(Icons.tune, size: 18),
                label: Text('Advanced Sensitive Settings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade900,
                  side: BorderSide(color: Colors.orange.shade200),
                  minimumSize: Size(double.infinity, 40),
                ),
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
      title: Text(
        'Add Stock to Wallet',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      leading: Icon(Icons.add_circle_outline, color: Colors.green),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Autocomplete<Stock>(
                displayStringForOption: (Stock s) =>
                    '${s.ticker} - ${s.name ?? ""}',
                optionsBuilder: (TextEditingValue val) {
                  if (val.text.isEmpty) return Iterable<Stock>.empty();
                  return _allStocks.where(
                    (s) =>
                        s.ticker.contains(val.text.toUpperCase()) ||
                        (s.name?.toUpperCase() ?? '').contains(
                          val.text.toUpperCase(),
                        ),
                  );
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
                decoration: InputDecoration(
                  labelText: 'Quantity (Shares)',
                  border: OutlineInputBorder(),
                ),
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
        case 'ticker':
          valA = a['ticker'];
          valB = b['ticker'];
          break;
        case 'supposed':
          valA = a['supposedValue'];
          valB = b['supposedValue'];
          break;
        case 'real':
          valA = a['realMarketValue'];
          valB = b['realMarketValue'];
          break;
        case 'deviation':
          valA =
              ((a['realMarketValue'] - a['supposedValue']) / a['supposedValue'])
                  .abs();
          valB =
              ((b['realMarketValue'] - b['supposedValue']) / b['supposedValue'])
                  .abs();
          break;
        default: // score (backend default order)
          return 0; // Keep current order if score selected
      }
      return _isAscending ? valA.compareTo(valB) : valB.compareTo(valA);
    });

    final filteredItems = onlyPending
        ? items.where((i) => i['suggestion'] != 'Hold').toList()
        : items;

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
            final deviation =
                ((item['realMarketValue'] - item['supposedValue']) /
                    item['supposedValue']) *
                100;

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
                  backgroundColor: _suggestionColor(
                    suggestion,
                  ).withOpacity(0.15),
                  child: Text(
                    '${item['rank']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _suggestionColor(suggestion),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      '${item['ticker']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '(${deviation.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (item['realMarketValue'] > item['supposedValue'])
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.settings,
                        size: 14,
                        color: Colors.blue.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qty: ${item['quantity']}  ×  EGP ${(item['currentPrice'] as num).toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.black87),
                    ),
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
                      Icon(
                        _suggestionIcon(suggestion),
                        color: _suggestionColor(suggestion),
                        size: 20,
                      ),
                      Text(
                        suggestion,
                        style: TextStyle(
                          color: _suggestionColor(suggestion),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'EGP ${gap.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
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
          Text(
            'Sort by:',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          SizedBox(width: 8),
          _sortChip('Ticker', 'ticker'),
          _sortChip('Supposed', 'supposed'),
          _sortChip('Real', 'real'),
          _sortChip('% Diff', 'deviation'),
          Spacer(),
          IconButton(
            icon: Icon(
              _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
            ),
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
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.deepPurple : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showManageModal(Map<String, dynamic> item) {
    final qtyController = TextEditingController(
      text: item['quantity'].toString(),
    );
    final priceController = TextEditingController(
      text: item['currentPrice'].toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                Text(
                  'Manage ${item['ticker']}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            SizedBox(height: 24),
            TextField(
              controller: qtyController,
              decoration: InputDecoration(
                labelText: 'Quantity (Shares)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            if (_mode == 'manual') ...[
              SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: 'Custom Price (EGP)',
                  border: OutlineInputBorder(),
                ),
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
                    targetUserId: widget.targetUserId,
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
              label: Text(
                'Remove From Wallet',
                style: TextStyle(color: Colors.red),
              ),
              style: TextButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showBulkPriceDialog() {
    if (_walletData?['analysis'] == null) return;
    final List items = _walletData!['analysis'];
    final controllers = <String, TextEditingController>{};

    for (var item in items) {
      controllers[item['ticker']] = TextEditingController(
        text: item['currentPrice'].toString(),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bulk Edit Manual Prices'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final ticker = items[i]['ticker'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: TextField(
                  controller: controllers[ticker],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: ticker,
                    border: OutlineInputBorder(),
                    prefixText: 'EGP ',
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final Map<String, double> prices = {};
              controllers.forEach((ticker, ctrl) {
                final val = double.tryParse(ctrl.text);
                if (val != null) prices[ticker] = val;
              });
              Navigator.pop(ctx);
              try {
                await _walletService.updateManualPricesBulk(
                  prices,
                  targetUserId: widget.targetUserId,
                );
                _loadData();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text('Save All'),
          ),
        ],
      ),
    );
  }

  void _showSensitiveSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Sensitive Settings', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'These parameters affect the core rebalancing algorithm. Only change them if you understand the mathematical implications.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _factorController,
                decoration: InputDecoration(
                  labelText: 'Matching Factor (Score Weight)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _liquidityController,
                decoration: InputDecoration(
                  labelText: 'Liquidity Factor (Cash %)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _thresholdController,
                decoration: InputDecoration(
                  labelText: 'Rebalancing Factor (Threshold)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              bool confirm =
                  await showDialog(
                    context: context,
                    builder: (innerCtx) => AlertDialog(
                      title: Text('Are you sure?'),
                      content: Text(
                        'Those data are sensitive and needs experience to be determined are you sure about changing?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(innerCtx, false),
                          child: Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(innerCtx, true),
                          child: Text(
                            'Yes',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (confirm) {
                Navigator.pop(ctx);
                _saveSettings();
              }
            },
            child: Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
