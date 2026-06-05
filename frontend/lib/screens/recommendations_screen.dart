import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/foundation.dart'; // for kIsWeb
import '../models/recommendation.dart';
import '../services/recommendation_service.dart';
import '../services/api_service.dart';
import '../models/stock.dart';

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
    setState(() => _isLoading = true);
    try {
      final data = await _service.fetchAll();
      final stocks = await _apiService.fetchStocks();
      setState(() {
        _data = data;
        _allStocks = stocks;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Recommendations Management'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'BF Update'),
              Tab(text: 'Fundamental (${_data?.fundamental.length ?? 0})'),
              Tab(text: 'Technical (${_data?.technical.length ?? 0})'),
              Tab(text: 'RFP (${_data?.rfp.length ?? 0})'),
              Tab(text: 'RSP (${_data?.rsp.length ?? 0})'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
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
        // Assuming first column is Ticker, second is BF Price
        // Skip header row if needed (I'll check if first row looks like header)
        for (var i = 0; i < table.maxRows; i++) {
          var row = table.rows[i];
          if (row.length < 2) continue;

          var ticker = row[0]?.value?.toString().trim();
          var valueStr = row[1]?.value?.toString().trim();

          if (ticker == null || valueStr == null) continue;

          var value = double.tryParse(valueStr);
          if (value == null) continue; // Skip header or invalid rows

          data.add({'ticker': ticker.toUpperCase(), 'value': value});
        }

        setState(() {
          _parsedData = data;
          _fileName = result.files.first.name;
          _isProcessing = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error parsing file: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _upload() async {
    if (_parsedData.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await RecommendationService().updateBfPrices(_parsedData);
      setState(() {
        _parsedData = [];
        _fileName = null;
      });
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BF Prices updated successfully from Excel')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.file_upload, size: 64, color: Colors.deepPurple),
          SizedBox(height: 20),
          Text(
            'BF Price Bulk Update (Excel)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Upload an Excel file with 2 columns: Ticker and BF Price.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 32),
          if (_fileName != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Loaded: $_fileName (${_parsedData.length} records)',
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => setState(() {
                      _fileName = null;
                      _parsedData = [];
                    }),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _pickAndParseFile,
            icon: Icon(Icons.search),
            label: Text('Select Excel File'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          if (_parsedData.isNotEmpty) ...[
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _upload,
              icon: Icon(Icons.cloud_upload),
              label: Text(_isProcessing ? 'Processing...' : 'Sync to Server'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
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
  final _tickerController = TextEditingController();
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
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _tickerController.clear();
    _targetController.clear();
    _notesController.clear();
    setState(() {
      _selectedStock = null;
      _editingId = null;
    });
  }

  Future<void> _save() async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _startEditing(Recommendation item) {
    setState(() {
      _editingId = item.id;
      _selectedStock = item.stock;
      _tickerController.text = item.stock.ticker;
      _targetController.text = item.target.toString();
      _notesController.text = item.notes ?? "";
    });
  }

  Future<void> _delete(String id) async {
    try {
      if (widget.type == 'fundamental') {
        await RecommendationService().deleteFundamental(id);
      } else {
        await RecommendationService().deleteTechnical(id);
      }
      widget.onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ExpansionTile(
            title: Text(
              'Add New Recommendation',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    SizedBox(height: 12),
                    if (_editingId != null)
                      Text(
                        'Editing: ${_selectedStock?.ticker}',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Autocomplete<Stock>(
                        displayStringForOption: (Stock option) =>
                            '${option.ticker} - ${option.name ?? ""}',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<Stock>.empty();
                          }
                          return widget.allStocks.where((Stock option) {
                            return option.ticker.contains(
                                  textEditingValue.text.toUpperCase(),
                                ) ||
                                (option.name?.toUpperCase() ?? "").contains(
                                  textEditingValue.text.toUpperCase(),
                                );
                          });
                        },
                        onSelected: (Stock selection) {
                          setState(() => _selectedStock = selection);
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Select Stock (Ticker or Name)',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              );
                            },
                      ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _targetController,
                      decoration: InputDecoration(labelText: 'Target Price'),
                      keyboardType: TextInputType.number,
                    ),
                    if (widget.type == 'technical')
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(labelText: 'Notes'),
                      ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        if (_editingId != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _clearForm,
                              child: Text('Cancel'),
                            ),
                          ),
                        if (_editingId != null) SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                (_isSaving ||
                                    (_editingId == null &&
                                        _selectedStock == null))
                                ? null
                                : _save,
                            child: Text(
                              _editingId == null ? 'Add Call' : 'Update Call',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _editingId == null
                                  ? Colors.deepPurple
                                  : Colors.green,
                              foregroundColor: Colors.white,
                              fixedSize: Size.fromHeight(45),
                            ),
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
        Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by Ticker',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: widget.items.where((item) => item.stock.ticker.toLowerCase().contains(_searchQuery)).length,
            itemBuilder: (context, index) {
              final filteredItems = widget.items.where((item) => item.stock.ticker.toLowerCase().contains(_searchQuery)).toList();
              final item = filteredItems[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(
                    item.stock.ticker,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Target: ${item.target}${item.notes != null && item.notes!.isNotEmpty ? "\nNotes: ${item.notes}" : ""}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.type == 'technical')
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _startEditing(item),
                        ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(item.id),
                      ),
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
  final _scoreController = TextEditingController();
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
    setState(() => _isSaving = true);
    try {
      final stocks = <Map<String, dynamic>>[];
      for (var i = 0; i < _currentItems.length; i++) {
        double score = 1.0;
        if (widget.type == 'rsp') {
          score = 1.0 - (i * 0.02);
          if (score < 0) score = 0; // Prevent negative scores
        } else if (widget.type == 'rfp') {
          score = 1.0; // Per user request: RFP internal score is always 1
        }

        stocks.add({'ticker': _currentItems[i].stock.ticker, 'score': score});
      }

      if (widget.type == 'rfp') {
        await RecommendationService().updateRFP(stocks);
      } else {
        await RecommendationService().updateRSP(stocks);
      }
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arrangement and scores saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _addItem() async {
    if (_selectedStock == null) return;

    // Check if already exists
    if (_currentItems.any((s) => s.stock.ticker == _selectedStock!.ticker)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Stock already in list')));
      return;
    }

    // Add to list then save to trigger re-calculation of all scores
    // Create a temporary Recommendation object
    final tempRec = Recommendation(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      stock: _selectedStock!,
      score: 1.0, // Will be recalculated on save
    );

    setState(() {
      _currentItems.add(tempRec);
    });

    // Save immediately to persist and sync scores
    await _save();

    _scoreController.clear();
    setState(() => _selectedStock = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Autocomplete<Stock>(
                displayStringForOption: (Stock option) =>
                    '${option.ticker} - ${option.name ?? ""}',
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<Stock>.empty();
                  }
                  return widget.allStocks.where((Stock option) {
                    return option.ticker.contains(
                          textEditingValue.text.toUpperCase(),
                        ) ||
                        (option.name?.toUpperCase() ?? "").contains(
                          textEditingValue.text.toUpperCase(),
                        );
                  });
                },
                onSelected: (Stock selection) {
                  setState(() => _selectedStock = selection);
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Select Stock to Add',
                          prefixIcon: Icon(Icons.search),
                        ),
                      );
                    },
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _selectedStock == null ? null : _addItem,
                child: Text('Add to List'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 40),
                ),
              ),
            ],
          ),
        ),
        Text('Drag items to reorder. Then click Save Arrangement.'),
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
                    IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _currentItems.remove(item);
                        });
                      },
                    ),
                    Icon(Icons.drag_handle),
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
            child: Text('Save Arrangement'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
