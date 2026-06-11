import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../models/stock.dart';
import '../l10n/app_localizations.dart';

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
  final Set<String> _showSharesTickers = {};

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
      if (mounted) _checkShowHint(AppLocalizations.of(context));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
      if (mounted) _checkShowHint(AppLocalizations.of(context));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('settings_saved'))));
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

  Future<void> _checkShowHint(AppLocalizations l) async {
    final rank = _walletData?['requesterRank'];
    if (rank == null || rank == 3) return;

    final lastHintStr = _walletData?['requesterLastHintDate'];
    if (lastHintStr != null) {
      final lastDate = DateTime.parse(lastHintStr).toLocal();
      final diff = DateTime.now().difference(lastDate);
      if (diff.inHours < 24) return;
    }

    // Show modal
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          l.t('hint_title'),
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l.t('hint_body'),
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _apiService.acceptHint();
                  // No need to reload data immediately as it's a metadata increase
                  // But we'll reload just to be sure next update check is fresh
                  _loadData();
                } catch (e) {
                  print('Error accepting hint: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(l.t('hint_confirm')),
            ),
          ),
        ],
      ),
    );
  }

  // Admin-only: Add / edit a snapshot
  void _showSnapshotDialog(AppLocalizations l, {Map? snap}) {
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
          title: Text(snap == null ? l.t('add_snapshot') : l.t('edit_snapshot')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l.t('snap_date')}: ${snapDate.toString().split(' ')[0]}'),
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
                    labelText: l.t('snap_balance_label'),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: bankRatioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.t('snap_bank_ratio_label'),
                    border: OutlineInputBorder(),
                    helperText: l.t('snap_bank_ratio_helper'),
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
    final l = AppLocalizations.of(context);
    final userNameFromData = _walletData?['wallet']?['user']?['name'];
    final title = widget.targetUserId != null
        ? '${l.t('simulating_prefix')}${widget.targetUserName ?? "..."}'
        : (userNameFromData != null
              ? "$userNameFromData${l.t('users_wallet_suffix')}"
              : l.t('my_wallet_title'));
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
                text: l.t('portfolio'),
                icon: Icon(Icons.account_balance_wallet, size: 20),
              ),
              Tab(
                text: l.t('pending'),
                icon: Icon(Icons.notifications_active, size: 20),
              ),
              Tab(text: l.t('next'), icon: Icon(Icons.trending_up, size: 20)),
              Tab(text: l.t('profit'), icon: Icon(Icons.calculate, size: 20)),
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
                  _buildPortfolioTab(l),
                  _buildActionsTab(l),
                  _buildPredictionsTab(l),
                  _buildProfitTab(l),
                ],
              ),
      ),
    );
  }

  Widget _buildPortfolioTab(AppLocalizations l) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          SizedBox(height: 16),
          _buildSettingsSection(l),
          SizedBox(height: 8),
          _buildAddStockSection(l),
          SizedBox(height: 16),
          Divider(),
          Text(
            l.t('full_portfolio'),
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
                onPressed: () => _showBulkPriceDialog(l),
                icon: Icon(Icons.edit_note),
                label: Text(l.t('bulk_edit_manual_prices')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 45),
                ),
              ),
            ),
          _buildAnalysisList(onlyPending: false, l: l),
        ],
      ),
    );
  }

  Widget _buildActionsTab(AppLocalizations l) {
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
            l.t('pending_decisions'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          Text(
            '${l.t('stocks_rebalancing_hint_prefix')}${((_walletData?['wallet']?['rebalancingThreshold'] ?? 0.1) * 100).toStringAsFixed(0)}${l.t('stocks_rebalancing_hint_suffix')}',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          SizedBox(height: 16),
          if (hasActions)
            _buildAnalysisList(onlyPending: true, l: l)
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
                      l.t('portfolio_balanced'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      l.t('no_actions_needed'),
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

  Widget _buildPredictionsTab(AppLocalizations l) {
    if (_walletData?['analysis'] == null) return SizedBox.shrink();

    // Filter to only 'Hold' stocks (less than deviation% diff)
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('next_transactions'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          Text(
            l.t('predicted_targets_subtitle'),
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          SizedBox(height: 16),
          if (top3.isEmpty)
            _emptyState(l.t('no_stocks_to_predict'))
          else
            ...top3.map((item) {
              final qty = item['quantity'] as num;
              if (qty == 0) return SizedBox.shrink();

              final currentPrice = item['currentPrice'] as num;
              final isSellingSide =
                  item['realMarketValue'] > item['supposedValue'];
              final targetPrice =
                  (isSellingSide ? item['sellTarget'] : item['buyTarget']) ??
                  0.0;
              final tradeValue = (item['gap'] as num).abs();

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
                          _trendBadge(isSellingSide, l),
                        ],
                      ),
                      Divider(),
                      _predictRow(
                        l.t('trigger_price'),
                        'EGP ${targetPrice.toString().contains('.') ? targetPrice.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : targetPrice.toStringAsFixed(0)}',
                        isPrimary: true,
                      ),
                      _predictRow(
                        l.t('current_price_label'),
                        'EGP ${currentPrice.toString().contains('.') ? currentPrice.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : currentPrice.toStringAsFixed(0)}',
                      ),
                      _predictRow(
                        l.t('expected_trade_val'),
                        'EGP ${tradeValue.toStringAsFixed(0)}',
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_showSharesTickers.contains(item['ticker'])) {
                              _showSharesTickers.remove(item['ticker']);
                            } else {
                              _showSharesTickers.add(item['ticker']);
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Text(
                              _showSharesTickers.contains(item['ticker'])
                                  ? '${item['predictShares']}${l.t('shares_suffix')}'
                                  : '${l.t('balanced_trade_prefix')}${tradeValue.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isSellingSide
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.swap_horiz,
                              size: 16,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                          ],
                        ),
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
                          '${((targetPrice - currentPrice) / currentPrice * 100).toStringAsFixed(1)}${l.t('to_target')}',
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

  Widget _trendBadge(bool isSell, AppLocalizations l) {
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
        isSell ? l.t('sell_trend') : l.t('buy_trend'),
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

  Widget _buildProfitTab(AppLocalizations l) {
    final profit = _walletData?['profit'];
    final trans = (_walletData?['wallet']?['transactions'] as List?) ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('financial_performance'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          SizedBox(height: 16),
          _buildProfitSummary(profit, l),
          SizedBox(height: 24),
          _buildSnapshotsSection(l),
          SizedBox(height: 24),
          _buildProfitSettingsSection(l),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.t('transactions'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showTransactionDialog(l),
                icon: Icon(Icons.add, size: 18),
                label: Text(l.t('new_transaction')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildTransactionList(trans, l),
        ],
      ),
    );
  }

  Widget _buildSnapshotsSection(AppLocalizations l) {
    final points = (_walletData?['wallet']?['pointsOnTime'] as List?) ?? [];
    final activeId = _walletData?['wallet']?['activePointOnTimeId'] as String?;
    final isAdmin = widget.targetUserId != null;

    // Sort desc by date
    final sorted = List.from(points)
      ..sort((a, b) => b['date'].compareTo(a['date']));

    return ExpansionTile(
      leading: Icon(Icons.timeline, color: Colors.indigo),
      title: Text(
        l.t('balance_snapshots'),
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
                              onPressed: () => _showSnapshotDialog(l, snap: snap),
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
              onPressed: () => _showSnapshotDialog(l),
              icon: Icon(Icons.add, size: 18),
              label: Text(l.t('add_snapshot')),
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

  Widget _buildProfitSettingsSection(AppLocalizations l) {
    return ExpansionTile(
      title: Text(
        l.t('revenue_calculation_mode'),
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${l.t('current_value_source')}${_profitMode.toUpperCase()}'),
      leading: Icon(Icons.tune, color: Colors.deepPurple),
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _profitMode,
                decoration: InputDecoration(
                  labelText: l.t('calculation_source_label'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'automatic',
                    child: Text(l.t('auto_source')),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text(l.t('manual_source')),
                  ),
                ],
                onChanged: (val) => setState(() => _profitMode = val!),
              ),
              if (_profitMode == 'manual') ...[
                SizedBox(height: 12),
                TextField(
                  controller: _manualProfitValueController,
                  decoration: InputDecoration(
                    labelText: l.t('custom_wallet_value'),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: Icon(Icons.save),
                label: Text(l.t('save_profit_settings')),
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

  Widget _buildProfitSummary(Map<String, dynamic>? profit, AppLocalizations l) {
    if (profit == null) return SizedBox.shrink();
    final activeSnap = _walletData?['activeSnapshot'];
    final bankComp = _walletData?['bankComparison'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeSnap != null) _buildActiveSnapshotBanner(activeSnap, l),
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
              l.t('effective_value'),
              'EGP ${_fmt(profit['walletEffectiveValue'])}',
              Icons.account_balance,
            ),
            _infoCard(
              l.t('net_revenue'),
              'EGP ${_fmt(profit['revenue'])}',
              Icons.monetization_on,
              color: (profit['revenue'] ?? 0) >= 0 ? Colors.green : Colors.red,
            ),
            _infoCard(
              l.t('revenue_percent'),
              '${((profit['revenuePercentage'] ?? 0) * 100).toStringAsFixed(2)}%',
              Icons.percent,
            ),
            _infoCard(
              l.t('daily_ratio'),
              '${profit['dailyRatio']?.toStringAsFixed(6)}',
              Icons.today,
            ),
            _infoCard(
              l.t('yearly_return'),
              '${((profit['yearlyRevenue'] ?? 0) * 100).toStringAsFixed(1)}%',
              Icons.calendar_today,
              color: Colors.orange,
            ),
            _infoCard(
              l.t('total_duration'),
              '${(profit['totalDuration'] ?? 0).toInt()} ${l.t('days')}',
              Icons.timer,
            ),
            if (bankComp != null) ...[
              _infoCard(
                l.t('extra_revenue'),
                'EGP ${_fmt(bankComp['extraRevenue'])}',
                Icons.star,
                color: (bankComp['extraRevenue'] ?? 0) >= 0
                    ? Colors.blue
                    : Colors.orange,
              ),
              _infoCard(
                l.t('bank_revenue'),
                'EGP ${_fmt(bankComp['bankSupposedRevenue'])}',
                Icons.account_balance_outlined,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActiveSnapshotBanner(Map<String, dynamic> snap, AppLocalizations l) {
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
                  l.t('anchored_to_snap'),
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
                  l.t('snap_exclusion_hint'),
                  style: TextStyle(fontSize: 10, color: Colors.indigo.shade400),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _setActiveSnapshot(null),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              l.t('clear'),
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

  Widget _buildTransactionList(List trans, AppLocalizations l) {
    if (trans.isEmpty) return _emptyState(l.t('no_transactions'));
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
                  onPressed: () => _showTransactionDialog(l, t: t),
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

  void _showTransactionDialog(AppLocalizations l, {Map? t}) {
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
            title: Text(t == null ? l.t('add_transaction') : l.t('edit_transaction')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _targetType,
                  items: [
                    DropdownMenuItem(value: 'deposit', child: Text(l.t('deposit'))),
                    DropdownMenuItem(
                      value: 'withdrawal',
                      child: Text(l.t('withdrawal')),
                    ),
                  ],
                  onChanged: (v) => setLocalState(() => _targetType = v!),
                  decoration: InputDecoration(labelText: l.t('type')),
                ),
                TextField(
                  controller: _valController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.t('value_egp')),
                ),
                ListTile(
                  title: Text(
                    '${l.t('snap_date')}: ${_selectedDate.toString().split(' ')[0]}',
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
                child: Text(l.t('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveTransaction(id: t?['_id']);
                },
                child: Text(l.t('save_all')),
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
                  Text(AppLocalizations.of(context).t('total_value'), style: TextStyle(color: Colors.black54)),
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

  Widget _buildSettingsSection(AppLocalizations l) {
    return ExpansionTile(
      title: Text(
        l.t('wallet_settings'),
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      leading: Icon(Icons.settings, color: Colors.deepPurple),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
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
              ElevatedButton.icon(
                onPressed: () => _showSensitiveSettingsDialog(l),
                icon: Icon(Icons.lock_open, size: 18),
                label: Text(l.t('advanced_settings')),
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
                label: Text(AppLocalizations.of(context).t('save_settings')),
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

  Widget _buildAddStockSection(AppLocalizations l) {
    return ExpansionTile(
      title: Text(
        AppLocalizations.of(context).t('add_stock_to_wallet'),
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
                      labelText: l.t('select_stock_label'),
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
                  labelText: l.t('quantity_label'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _selectedStock == null ? null : _addStock,
                icon: Icon(Icons.add),
                label: Text(l.t('add_to_wallet_btn')),
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

  Widget _buildAnalysisList({required bool onlyPending, required AppLocalizations l}) {
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
      return _emptyState(l.t('wallet_empty'));
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
              child: InkWell(
                onTap: () => _showManageModal(item, l),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Leading: Rank Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _suggestionColor(
                          suggestion,
                        ).withOpacity(0.15),
                        child: Text(
                          '${item['rank']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _suggestionColor(suggestion),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),

                      // Middle: Title & Subtitle (Ticker, Price, Qty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${item['ticker']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '(${deviation.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        (item['realMarketValue'] >
                                            item['supposedValue'])
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.settings,
                                  size: 13,
                                  color: Colors.blue.withOpacity(0.4),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${l.t('qty_label_short')}${item['quantity']}  ×  EGP ${((item['currentPrice'] as num).toDouble()).toString().contains('.') ? (item['currentPrice'] as num).toDouble().toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : (item['currentPrice'] as num).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${l.t('real_value_label')}${(item['realMarketValue'] as num).toStringAsFixed(0)}${l.t('supposed_value_label')}${(item['supposedValue'] as num).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),

                      // Trailing: Suggestion & Toggleable Value
                      SizedBox(
                        width: 80,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _suggestionIcon(suggestion),
                                  color: _suggestionColor(suggestion),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  l.t('suggestion_${suggestion.toLowerCase()}'),
                                  style: TextStyle(
                                    color: _suggestionColor(suggestion),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (_showSharesTickers.contains(
                                    item['ticker'],
                                  )) {
                                    _showSharesTickers.remove(item['ticker']);
                                  } else {
                                    _showSharesTickers.add(item['ticker']);
                                  }
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _showSharesTickers.contains(
                                        item['ticker'],
                                      )
                                      ? Colors.indigo.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _showSharesTickers.contains(item['ticker'])
                                      ? '${item['gapShares']}${l.t('shares_suffix')}'
                                      : 'EGP ${(item['gap'] as num).toStringAsFixed(0)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        _showSharesTickers.contains(
                                          item['ticker'],
                                        )
                                        ? Colors.indigo
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  void _showManageModal(Map<String, dynamic> item, AppLocalizations l) {
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
                  await _loadData();
                  if (mounted) _checkShowHint(l);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(l.t('update_stock_info')),
            ),
            SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _removeStock(item['ticker']);
              },
              icon: Icon(Icons.delete, color: Colors.red),
              label: Text(
                l.t('remove_from_wallet'),
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

  void _showBulkPriceDialog(AppLocalizations l) {
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

  void _showSensitiveSettingsDialog(AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text(l.t('sensitive_settings'), style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.t('sensitive_settings_hint'),
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _factorController,
                decoration: InputDecoration(
                  labelText: l.t('matching_factor'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _liquidityController,
                decoration: InputDecoration(
                  labelText: l.t('liquidity_factor_label'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _thresholdController,
                decoration: InputDecoration(
                  labelText: l.t('rebalancing_factor'),
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
                      title: Text(l.t('are_you_sure')),
                      content: Text(
                        l.t('sensitive_confirm_body'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(innerCtx, false),
                          child: Text(l.t('no')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(innerCtx, true),
                          child: Text(
                            l.t('yes'),
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
            child: Text(l.t('save_changes')),
          ),
        ],
      ),
    );
  }
}
