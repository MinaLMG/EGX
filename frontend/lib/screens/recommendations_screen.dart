import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/foundation.dart'; // for kIsWeb
import '../models/recommendation.dart';
import '../services/recommendation_service.dart';
import '../services/api_service.dart';
import '../models/stock.dart';
import '../l10n/app_localizations.dart';

class RecommendationsScreen extends StatefulWidget {
  @override
  _RecommendationsScreenState createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final RecommendationService _service = RecommendationService();
  final ApiService _apiService = ApiService();
  AllRecommendations? _data;
  List<Stock> _allStocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final l = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final data = await _service.fetchAll();
      final stocks = await _apiService.fetchStocks();
      if (mounted) {
        setState(() {
          _data = data;
          _allStocks = stocks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('admin_recommendations')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l.t('bf_update')),
              Tab(text: '${l.t('fundamental')} (${_data?.fundamental.length ?? 0})'),
              Tab(text: '${l.t('technical')} (${_data?.technical.length ?? 0})'),
              Tab(text: '${l.t('rfp')} (${_data?.rfp.length ?? 0})'),
              Tab(text: '${l.t('rsp')} (${_data?.rsp.length ?? 0})'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                   _BfUpdateTab(onRefresh: _loadData),
                  _RecommendationListTab(
                    type: 'fundamental',
                    items: _data?.fundamental ?? [],
                    allStocks: _allStocks,
                    onRefresh: _loadData,
                  ),
                  _RecommendationListTab(
                    type: 'technical',
                    items: _data?.technical ?? [],
                    allStocks: _allStocks,
                    onRefresh: _loadData,
                  ),
                  _OrderedListTab(
                    type: 'rfp',
                    items: _data?.rfp ?? [],
                    allStocks: _allStocks,
                    onRefresh: _loadData,
                  ),
                  _OrderedListTab(
                    type: 'rsp',
                    items: _data?.rsp ?? [],
                    allStocks: _allStocks,
                    onRefresh: _loadData,
                  ),
                ],
              ),
      ),
    );
  }
}

class _BfUpdateTab extends StatefulWidget {
  final VoidCallback onRefresh;
  _BfUpdateTab({required this.onRefresh});

  @override
  __BfUpdateTabState createState() => __BfUpdateTabState();
}

class __BfUpdateTabState extends State<_BfUpdateTab> {
  bool _isProcessing = false;
  String? _fileName;
  List<Map<String, dynamic>> _parsedData = [];

  Future<void> _pickAndParseFile() async {
    final l = AppLocalizations.of(context);
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      setState(() => _isProcessing = true);
      try {
        var bytes = result.files.first.bytes;
        if (bytes == null && !kIsWeb) {
          final file = File(result.files.first.path!);
          bytes = await file.readAsBytes();
        }

        if (bytes == null) throw Exception("Could not read file bytes");

        var excel = excel_pkg.Excel.decodeBytes(bytes);
        var table = excel.tables[excel.tables.keys.first];

        if (table == null) throw Exception("Excel sheet is empty");

        List<Map<String, dynamic>> data = [];
        for (var i = 0; i < table.maxRows; i++) {
          var row = table.rows[i];
          if (row.length < 2) continue;

          var ticker = row[0]?.value?.toString().trim();
          var valueStr = row[1]?.value?.toString().trim();

          if (ticker == null || valueStr == null) continue;

          var value = double.tryParse(valueStr);
          if (value == null) continue; 

          data.add({'ticker': ticker.toUpperCase(), 'value': value});
        }

        if (mounted) {
          setState(() {
            _parsedData = data;
            _fileName = result.files.first.name;
            _isProcessing = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _upload() async {
    final l = AppLocalizations.of(context);
    if (_parsedData.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await RecommendationService().updateBfPrices(_parsedData);
      if (mounted) {
        setState(() {
          _parsedData = [];
          _fileName = null;
        });
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('success'))),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.file_upload, size: 64, color: Colors.deepPurple),
          const SizedBox(height: 20),
          Text(
            l.t('bf_update'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload an Excel file with 2 columns: Ticker and BF Price.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          if (_fileName != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Loaded: $_fileName (${_parsedData.length} records)',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _fileName = null;
                      _parsedData = [];
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _pickAndParseFile,
            icon: const Icon(Icons.search),
            label: Text(l.t('select_excel')),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          if (_parsedData.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _upload,
              icon: const Icon(Icons.cloud_upload),
              label: Text(_isProcessing ? '${l.t('loading')}...' : l.t('sync_server')),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationListTab extends StatefulWidget {
  final String type;
  final List<Recommendation> items;
  final List<Stock> allStocks;
  final VoidCallback onRefresh;

  _RecommendationListTab({
    required this.type,
    required this.items,
    required this.allStocks,
    required this.onRefresh,
  });

  @override
  __RecommendationListTabState createState() => __RecommendationListTabState();
}

class __RecommendationListTabState extends State<_RecommendationListTab> {
  final _targetController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  Stock? _selectedStock;
  bool _isSaving = false;
  String? _editingId;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _targetController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _targetController.clear();
    _notesController.clear();
    setState(() {
      _selectedStock = null;
      _editingId = null;
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_targetController.text.isEmpty) return;
    if (_editingId == null && _selectedStock == null) return;

    setState(() => _isSaving = true);
    try {
      if (widget.type == 'fundamental') {
        await RecommendationService().updateFundamental(
          _selectedStock!.ticker,
          double.parse(_targetController.text),
        );
      } else {
        if (_editingId != null) {
          await RecommendationService().updateTechnicalById(
            _editingId!,
            double.parse(_targetController.text),
            _notesController.text,
          );
        } else {
          await RecommendationService().updateTechnical(
            _selectedStock!.ticker,
            double.parse(_targetController.text),
            _notesController.text,
          );
        }
      }
      _clearForm();
      widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _startEditing(Recommendation item) {
    setState(() {
      _editingId = item.id;
      _selectedStock = item.stock;
      _targetController.text = item.target.toString();
      _notesController.text = item.notes ?? "";
    });
  }

  Future<void> _delete(String id) async {
    final l = AppLocalizations.of(context);
    try {
      if (widget.type == 'fundamental') {
        await RecommendationService().deleteFundamental(id);
      } else {
        await RecommendationService().deleteTechnical(id);
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ExpansionTile(
            title: Text(
              _editingId == null ? l.t('add_call') : l.t('update_call'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    if (_editingId != null)
                      Text(
                        'Editing: ${_selectedStock?.ticker}',
                        style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                      )
                    else
                      Autocomplete<Stock>(
                        displayStringForOption: (Stock option) => '${option.ticker} - ${option.name ?? ""}',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') return const Iterable<Stock>.empty();
                          return widget.allStocks.where((Stock option) {
                            final q = textEditingValue.text.toUpperCase();
                            return option.ticker.contains(q) || (option.name?.toUpperCase() ?? "").contains(q);
                          });
                        },
                        onSelected: (Stock selection) => setState(() => _selectedStock = selection),
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: '${l.t('market_data')} (Ticker/Name)',
                              prefixIcon: const Icon(Icons.search),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _targetController,
                      decoration: InputDecoration(labelText: l.t('target_price')),
                      keyboardType: TextInputType.number,
                    ),
                    if (widget.type == 'technical')
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(labelText: l.t('notes')),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_editingId != null)
                          Expanded(
                            child: OutlinedButton(onPressed: _clearForm, child: Text(l.t('cancel'))),
                          ),
                        if (_editingId != null) const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isSaving || (_editingId == null && _selectedStock == null)) ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _editingId == null ? Colors.deepPurple : Colors.green,
                              foregroundColor: Colors.white,
                              fixedSize: const Size.fromHeight(45),
                            ),
                            child: Text(_editingId == null ? l.t('add_call') : l.t('update_call')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: l.t('search_ticker'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: widget.items.where((item) => item.stock.ticker.toLowerCase().contains(_searchQuery)).length,
            itemBuilder: (context, index) {
              final filteredItems = widget.items.where((item) => item.stock.ticker.toLowerCase().contains(_searchQuery)).toList();
              final item = filteredItems[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(item.stock.ticker, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Target: ${item.target}${item.notes != null && item.notes!.isNotEmpty ? "\n${l.t('notes')}: ${item.notes}" : ""}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.type == 'technical')
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _startEditing(item)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(item.id)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrderedListTab extends StatefulWidget {
  final String type;
  final List<Recommendation> items;
  final List<Stock> allStocks;
  final VoidCallback onRefresh;

  _OrderedListTab({
    required this.type,
    required this.items,
    required this.allStocks,
    required this.onRefresh,
  });

  @override
  __OrderedListTabState createState() => __OrderedListTabState();
}

class __OrderedListTabState extends State<_OrderedListTab> {
  late List<Recommendation> _currentItems;
  Stock? _selectedStock;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentItems = List.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant _OrderedListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _currentItems = List.from(widget.items);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    try {
      final stocks = <Map<String, dynamic>>[];
      for (var i = 0; i < _currentItems.length; i++) {
        double score = 1.0;
        if (widget.type == 'rsp') { score = 1.0 - (i * 0.02); if (score < 0) score = 0; }
        else if (widget.type == 'rfp') { score = 1.0; }
        stocks.add({'ticker': _currentItems[i].stock.ticker, 'score': score});
      }
      if (widget.type == 'rfp') { await RecommendationService().updateRFP(stocks); }
      else { await RecommendationService().updateRSP(stocks); }
      widget.onRefresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('success'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addItem() async {
    final l = AppLocalizations.of(context);
    if (_selectedStock == null) return;
    if (_currentItems.any((s) => s.stock.ticker == _selectedStock!.ticker)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('stock_already_in_list'))));
      return;
    }
    final tempRec = Recommendation(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      stock: _selectedStock!,
      score: 1.0,
    );
    setState(() => _currentItems.add(tempRec));
    await _save();
    setState(() => _selectedStock = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Autocomplete<Stock>(
                displayStringForOption: (Stock option) => '${option.ticker} - ${option.name ?? ""}',
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') return const Iterable<Stock>.empty();
                  return widget.allStocks.where((Stock option) {
                    final q = textEditingValue.text.toUpperCase();
                    return option.ticker.contains(q) || (option.name?.toUpperCase() ?? "").contains(q);
                  });
                },
                onSelected: (Stock selection) => setState(() => _selectedStock = selection),
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(labelText: l.t('add_to_list'), prefixIcon: const Icon(Icons.search)),
                  );
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _selectedStock == null ? null : _addItem,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                child: Text(l.t('add_to_list')),
              ),
            ],
          ),
        ),
        Text(l.t('drag_reorder')),
        Expanded(
          child: ReorderableListView(
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _currentItems.removeAt(oldIndex);
                _currentItems.insert(newIndex, item);
              });
            },
            children: _currentItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return ListTile(
                key: Key(item.id),
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(item.stock.ticker),
                subtitle: Text('Score: ${item.score}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _currentItems.remove(item))),
                    const Icon(Icons.drag_handle),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text(l.t('save_arrangement')),
          ),
        ),
      ],
    );
  }
}
