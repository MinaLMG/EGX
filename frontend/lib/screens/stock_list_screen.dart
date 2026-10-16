import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/stock.dart';
import '../services/api_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';
import 'match_screen.dart';
import 'mubasher_matching_screen.dart';
import 'admin_stock_matrix_screen.dart';

class StockListScreen extends StatefulWidget {
  @override
  _StockListScreenState createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final ApiService apiService = ApiService();
  final WalletService walletService = WalletService();
  final AuthService authService = AuthService();
  late Future<List<Stock>> futureStocks;
  Set<String> walletTickers = {};
  bool _isAdmin = false;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkAdmin();
  }

  Future<void> _loadData() async {
    setState(() {
      futureStocks = apiService.fetchStocks();
    });
    _loadWallet();
  }

  Future<void> _checkAdmin() async {
    final user = await authService.getUser();
    if (user?.role == 'admin') {
      if (mounted) setState(() => _isAdmin = true);
    }
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await walletService.getWallet();
      final List items = wallet['wallet']?['items'] ?? [];
      if (mounted) {
        setState(() {
          walletTickers = items
              .map((i) => i['stock']['ticker'] as String)
              .toSet();
        });
      }
    } catch (e) {
      // User might not be logged in or other error, ignore
    }
  }

  void _refresh() {
    _loadData();
  }

  Future<void> _exportToExcel() async {
    final l = AppLocalizations.of(context);
    try {
      final bytes = await apiService.exportStocksExcel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel generated. Select location to save.')),
      );

      String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save generated_fair.xlsx',
        fileName: 'generated_fair.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (outputPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File saved to $outputPath')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.t('search_hint'),
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Text(
                l.t('market_data'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = "";
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: l.t('mubasher_matching'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MubasherMatchingScreen(),
                ),
              ),
            ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.grid_on),
              tooltip: l.t('market_matrix'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminStockMatrixScreen(),
                ),
              ),
            ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add_box),
              tooltip: l.t('add_ticker'),
              onPressed: _showAddStockDialog,
            ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.description), 
              tooltip: 'Export generated_fair.xlsx',
              onPressed: _exportToExcel,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<Stock>>(
                future: futureStocks,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('${l.t('error')}: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text(l.t('no_stocks_found')));
                  }

                  final List<Stock> sortedStocks = snapshot.data!.where((s) {
                    final q = _searchQuery.toUpperCase();
                    return s.ticker.toUpperCase().contains(q) ||
                        (s.name?.toUpperCase().contains(q) ?? false);
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedStocks.length,
                    itemBuilder: (context, index) {
                      final stock = sortedStocks[index];
                      final bool isMatched = stock.arabicStockGetter != null &&
                          stock.arabicStockGetter!.isNotEmpty;
                      final bool isInWallet =
                          walletTickers.contains(stock.ticker);

                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Card(
                        color: isInWallet 
                            ? (isDark ? Colors.amber.withOpacity(0.15) : Colors.amber.shade50) 
                            : Theme.of(context).cardColor,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: isInWallet
                              ? const BorderSide(color: Colors.amber, width: 2)
                              : BorderSide.none,
                        ),
                        elevation: isInWallet ? 8 : 4,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isMatched
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            child: Text(
                              stock.ticker[0],
                              style: TextStyle(
                                color: isMatched ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                stock.ticker,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (isInWallet) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'WALLET',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              if (stock.arabicStockTargetMode != 'max') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade400,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    stock.arabicStockTargetMode.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(stock.name ?? 'No Name'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                stock.totalScore.toStringAsFixed(2),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Icon(
                                isMatched
                                    ? Icons.check_circle
                                    : Icons.warning_amber_rounded,
                                color: isMatched ? Colors.green : Colors.orange,
                                size: 16,
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDataRow('${l.t('current_price')}:',
                                      '${stock.price} EGP', Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                                  if (stock.arabicStockFairValue != null)
                                    _buildDataRow('${l.t('fair_value')}:',
                                        '${stock.arabicStockFairValue} EGP', Colors.blue),
                                  if (stock.arabicStockAnalyzersFairValue !=
                                      null)
                                    _buildDataRow(
                                        '${l.t('analyzers_fair_value')}:',
                                        '${stock.arabicStockAnalyzersFairValue} EGP',
                                        Colors.teal),
                                  _buildDataRow(
                                      '${l.t('target_source')}:',
                                      _getTargetModeLabel(stock.arabicStockTargetMode, l),
                                      Colors.indigo),
                                  if (stock.effectiveArabicStockTarget != null)
                                    _buildDataRow(
                                        '${l.t('active_target')}:',
                                        '${stock.effectiveArabicStockTarget!.toStringAsFixed(2)} EGP',
                                        Colors.deepPurple),
                                  const Divider(height: 32),
                                  Text(
                                    l.t('recommendation_scores'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildScoreRow('BF Pot.', stock.bfScore),
                                  _buildScoreRow(l.t('fundamental'), stock.fundamentalScore),
                                  _buildScoreRow(l.t('technical'), stock.technicalScore),
                                  _buildScoreRow('ArabStock', stock.arabstockScore),
                                  _buildScoreRow(l.t('rfp'), stock.rfpScore),
                                  _buildScoreRow(l.t('rsp'), stock.rspScore),
                                  const SizedBox(height: 16),
                                  if (_isAdmin)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.link, size: 18),
                                            label: Text(
                                              isMatched
                                                  ? l.t('change_match')
                                                  : l.t('match_arabicstock'),
                                            ),
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      MatchScreen(stock: stock),
                                                ),
                                              );
                                              _refresh();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context).colorScheme.primary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.tune, size: 18),
                                            label: Text(l.t('configure_target')),
                                            onPressed: () => _showTargetModeDialog(stock),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.deepPurple,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStockDialog() {
    final l = AppLocalizations.of(context);
    final _tickerController = TextEditingController();
    final _nameController = TextEditingController();
    final _priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('add_ticker')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tickerController,
              decoration: const InputDecoration(
                labelText: 'Ticker (e.g. ABUK)',
                hintText: 'Uppercase ticker',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l.t('company_name'),
              ),
            ),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: l.t('initial_price'),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              try {
                final ticker = _tickerController.text.trim().toUpperCase();
                final name = _nameController.text.trim();
                final price = double.tryParse(_priceController.text) ?? 0;

                if (ticker.isEmpty) throw 'Ticker cannot be empty';

                await apiService.createStock(ticker, name, price);
                if (mounted) {
                  Navigator.pop(ctx);
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.t('stock_added'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
                }
              }
            },
            child: Text(l.t('create')),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _getTargetModeLabel(String mode, AppLocalizations l) {
    switch (mode) {
      case 'analyzers':
        return l.t('target_analyzers');
      case 'fair_value':
        return l.t('target_fair_value');
      case 'manual':
        return l.t('target_manual');
      case 'max':
      default:
        return l.t('target_max');
    }
  }

  void _showTargetModeDialog(Stock stock) {
    final l = AppLocalizations.of(context);
    String selectedMode = stock.arabicStockTargetMode;
    final customController = TextEditingController(
      text: stock.arabicStockCustomFairValue != null
          ? stock.arabicStockCustomFairValue.toString()
          : '',
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('${l.t('configure_target')} (${stock.ticker})'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.t('target_max')),
                    subtitle: Text(
                      'Analyzers: ${stock.arabicStockAnalyzersFairValue ?? "-"} | FV: ${stock.arabicStockFairValue ?? "-"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: 'max',
                    groupValue: selectedMode,
                    onChanged: isSubmitting
                        ? null
                        : (val) => setDialogState(() => selectedMode = val!),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.t('target_analyzers')),
                    subtitle: Text(
                      '${stock.arabicStockAnalyzersFairValue ?? "-"} EGP',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: 'analyzers',
                    groupValue: selectedMode,
                    onChanged: isSubmitting
                        ? null
                        : (val) => setDialogState(() => selectedMode = val!),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.t('target_fair_value')),
                    subtitle: Text(
                      '${stock.arabicStockFairValue ?? "-"} EGP',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: 'fair_value',
                    groupValue: selectedMode,
                    onChanged: isSubmitting
                        ? null
                        : (val) => setDialogState(() => selectedMode = val!),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.t('target_manual')),
                    subtitle: Text(
                      l.t('custom_fair_value_label'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: 'manual',
                    groupValue: selectedMode,
                    onChanged: isSubmitting
                        ? null
                        : (val) => setDialogState(() => selectedMode = val!),
                  ),
                  if (selectedMode == 'manual') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l.t('custom_fair_value_label'),
                        hintText: 'e.g. 45.50',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      autofocus: true,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: Text(l.t('cancel')),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        double? customVal;
                        if (selectedMode == 'manual') {
                          final parsed = double.tryParse(customController.text.trim());
                          if (parsed == null || parsed <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid positive number for custom fair value'),
                              ),
                            );
                            return;
                          }
                          customVal = parsed;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        setDialogState(() => isSubmitting = true);
                        try {
                          await apiService.updateArabicStockTarget(
                            ticker: stock.ticker,
                            targetMode: selectedMode,
                            customFairValue: customVal,
                          );
                          if (mounted) {
                            navigator.pop();
                            _refresh();
                            messenger.showSnackBar(
                              SnackBar(content: Text(l.t('target_mode_updated'))),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('${l.t('error')}: $e')),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.t('save_changes')),
              ),
            ],
          );
        },
      ),
    );
  }
}
