import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/api_service.dart';

class MatchScreen extends StatefulWidget {
  final Stock stock;

  MatchScreen({required this.stock});

  @override
  _MatchScreenState createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<ArabicStockMatch> matches = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.stock.ticker;
    _search();
  }

  void _search() async {
    setState(() => isLoading = true);
    try {
      final results = await apiService.searchArabicStock(_searchController.text);
      setState(() => matches = results);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _match(String url) async {
    setState(() => isLoading = true);
    try {
      await apiService.matchStock(widget.stock.ticker, url);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Matching failed: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Match: ${widget.stock.ticker}'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search ArabicStock.com',
                suffixIcon: IconButton(icon: Icon(Icons.search), onPressed: _search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (isLoading) LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                return ListTile(
                  title: Text(match.title, style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(match.link, style: TextStyle(fontSize: 12, color: Colors.blue)),
                  trailing: Icon(Icons.add_link),
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
