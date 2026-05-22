import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/api_service.dart';

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
    setState(() => isLoading = true);
    try {
      final allStocks = await apiService.fetchStocks();
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
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load stocks: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _performSearch() async {
    if (unmatchedStocks.isEmpty) return;

    setState(() => isSearching = true);
    try {
      final results = await apiService.searchArabicStock(
        _searchController.text,
      );
      setState(() => searchResults = results);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setState(() => isSearching = false);
    }
  }

  void _match(String url) async {
    setState(() => isSearching = true);
    try {
      await apiService.matchStock(unmatchedStocks[currentIndex].ticker, url);

      if (currentIndex < unmatchedStocks.length - 1) {
        setState(() {
          currentIndex++;
          _searchController.text = unmatchedStocks[currentIndex].ticker;
          searchResults = [];
        });
        _performSearch();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('All stocks matched!')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Match failed: $e')));
    } finally {
      setState(() => isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    if (unmatchedStocks.isEmpty)
      return Scaffold(
        appBar: AppBar(title: Text('Wizard')),
        body: Center(child: Text('No unmatched stocks found!')),
      );

    final currentStock = unmatchedStocks[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ArabicStock Matching Wizard (${currentIndex + 1}/${unmatchedStocks.length})',
        ),
        backgroundColor: Colors.orange.shade700,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                CircleAvatar(child: Text(currentStock.ticker[0])),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStock.ticker,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(currentStock.name ?? 'No Name'),
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
                  child: Text('Skip'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for match on ArabicStock',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _performSearch,
                ),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          if (isSearching) LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final match = searchResults[index];
                return ListTile(
                  title: Text(match.title),
                  subtitle: Text(
                    match.link,
                    style: TextStyle(color: Colors.blue, fontSize: 11),
                  ),
                  trailing: Icon(Icons.link),
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
