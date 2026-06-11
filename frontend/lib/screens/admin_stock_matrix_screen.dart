import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class AdminStockMatrixScreen extends StatefulWidget {
  @override
  _AdminStockMatrixScreenState createState() => _AdminStockMatrixScreenState();
}

class _AdminStockMatrixScreenState extends State<AdminStockMatrixScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _users = [];
  List<dynamic> _matrix = [];
  List<dynamic> _filteredMatrix = [];

  String _tickerFilter = '';
  bool _showOnlyInWallets = false;

  String _sortColumn = 'score';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _apiService.fetchStocksMatrix();
      setState(() {
        _users = data['users'];
        _matrix = data['matrix'];
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMatrix = _matrix.where((item) {
        final matchesTicker = item['ticker']
            .toString()
            .toLowerCase()
            .contains(_tickerFilter.toLowerCase());
        final matchesParticipation = !_showOnlyInWallets || item['existsInAnyWallet'];
        return matchesTicker && matchesParticipation;
      }).toList();
      _sortData(_sortColumn, _sortAscending);
    });
  }

  void _sortData(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _filteredMatrix.sort((a, b) {
        dynamic valA, valB;
        if (column == 'ticker') {
          valA = a['ticker'];
          valB = b['ticker'];
        } else if (column == 'score') {
          valA = a['score'];
          valB = b['score'];
        } else if (column == 'participation') {
          valA = a['existsInAnyWallet'] ? 1 : 0;
          valB = b['existsInAnyWallet'] ? 1 : 0;
        } else {
          // User column
          valA = (a['userParticipation'][column] == true) ? 1 : 0;
          valB = (b['userParticipation'][column] == true) ? 1 : 0;
        }

        int result = valA.compareTo(valB);
        return ascending ? result : -result;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('market_matrix_admin')),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(l),
                Expanded(
                  child: _filteredMatrix.isEmpty
                      ? Center(child: Text(l.t('no_stocks_match_filters')))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              sortColumnIndex: _getColumnIndex(_sortColumn),
                              sortAscending: _sortAscending,
                              headingRowColor: MaterialStateProperty.all(
                                  Colors.deepPurple.shade50),
                              columns: [
                                DataColumn(
                                  label: Text(l.t('ticker_label')),
                                  onSort: (index, asc) => _sortData('ticker', asc),
                                ),
                                DataColumn(
                                  label: Text(l.t('score_label')),
                                  numeric: true,
                                  onSort: (index, asc) => _sortData('score', asc),
                                ),
                                ..._users.map((u) {
                                  final name = u['name'] ?? u['username'];
                                  return DataColumn(
                                    label: Text(name),
                                    onSort: (index, asc) => _sortData(u['_id'], asc),
                                  );
                                }).toList(),
                                DataColumn(
                                  label: Text(l.t('any_participation')),
                                  onSort: (index, asc) =>
                                      _sortData('participation', asc),
                                ),
                              ],
                              rows: _filteredMatrix.map((item) {
                                final hasAny = item['existsInAnyWallet'] == true;
                                return DataRow(
                                  color: hasAny
                                      ? MaterialStateProperty.all(
                                          Colors.green.withOpacity(0.05))
                                      : null,
                                  cells: [
                                    DataCell(Text(item['ticker'],
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                    DataCell(
                                        Text(item['score'].toStringAsFixed(2))),
                                    ..._users.map((u) {
                                      final isPresent =
                                          item['userParticipation'][u['_id']] == true;
                                      return DataCell(
                                        Icon(
                                          isPresent
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isPresent
                                              ? Colors.green
                                              : Colors.grey.shade200,
                                          size: 20,
                                        ),
                                      );
                                    }).toList(),
                                    DataCell(
                                      Icon(
                                        hasAny
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: hasAny ? Colors.blue : Colors.grey,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  int? _getColumnIndex(String column) {
    if (column == 'ticker') return 0;
    if (column == 'score') return 1;
    // We don't map user IDs to indices here to keep it simple,
    // DataTable sortColumnIndex is mostly visual anyway if we handle sort logic
    return null;
  }

  Widget _buildFilters(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: l.t('filter_ticker'),
                hintText: 'e.g. ABUK',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                _tickerFilter = val;
                _applyFilters();
              },
            ),
          ),
          SizedBox(width: 16),
          FilterChip(
            label: Text(l.t('in_any_wallet')),
            selected: _showOnlyInWallets,
            selectedColor: Colors.deepPurple.shade100,
            onSelected: (val) {
              setState(() {
                _showOnlyInWallets = val;
                _applyFilters();
              });
            },
          ),
        ],
      ),
    );
  }
}
