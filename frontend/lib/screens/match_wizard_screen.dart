import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class MatchWizardScreen extends StatefulWidget {
  @override
  _MatchWizardScreenState createState() => _MatchWizardScreenState();
}

class _MatchWizardScreenState extends State<MatchWizardScreen> {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Stock> unmatchedStocks = [];
  int currentIndex = 0;
  List<ArabicStockMatch> searchResults = [];
  bool isLoading = false;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUnmatchedStocks();
  }

  void _loadUnmatchedStocks() async {
    final l = AppLocalizations.of(context);
    setState(() => isLoading = true);
    try {
      final allStocks = await apiService.fetchStocks();
      if (mounted) {
        setState(() {
          unmatchedStocks = allStocks
              .where(
                (s) =>
                    s.arabicStockGetter == null || s.arabicStockGetter!.isEmpty,
              )
              .toList();
          if (unmatchedStocks.isNotEmpty) {
            _searchController.text = unmatchedStocks[currentIndex].ticker;
            _performSearch();
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _performSearch() async {
    final l = AppLocalizations.of(context);
    if (unmatchedStocks.isEmpty) return;

    setState(() => isSearching = true);
    try {
      final results = await apiService.searchArabicStock(
        _searchController.text,
      );
      if (mounted) setState(() => searchResults = results);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  void _match(String url) async {
    final l = AppLocalizations.of(context);
    setState(() => isSearching = true);
    try {
      await apiService.matchStock(unmatchedStocks[currentIndex].ticker, url);

      if (mounted) {
        if (currentIndex < unmatchedStocks.length - 1) {
          setState(() {
            currentIndex++;
            _searchController.text = unmatchedStocks[currentIndex].ticker;
            searchResults = [];
          });
          _performSearch();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('match_success'))));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.t('error')}: $e')));
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (unmatchedStocks.isEmpty)
      return Scaffold(
        appBar: AppBar(title: Text(l.t('wizard'))),
        body: Center(child: Text(l.t('no_unmatched'))),
      );

    final currentStock = unmatchedStocks[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l.t('admin_matching_wizard')} (${currentIndex + 1}/${unmatchedStocks.length})',
        ),
        backgroundColor: Colors.orange.shade700,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                CircleAvatar(child: Text(currentStock.ticker[0])),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStock.ticker,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(currentStock.name ?? l.t('no_name')),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (currentIndex < unmatchedStocks.length - 1) {
                      setState(() {
                        currentIndex++;
                        _searchController.text =
                            unmatchedStocks[currentIndex].ticker;
                        searchResults = [];
                      });
                      _performSearch();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(l.t('skip')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l.t('search_match'),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _performSearch,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          if (isSearching) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final match = searchResults[index];
                return ListTile(
                  title: Text(match.title),
                  subtitle: Text(
                    match.link,
                    style: const TextStyle(color: Colors.blue, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.link),
                  onTap: () => _match(match.link),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
