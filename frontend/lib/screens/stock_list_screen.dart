import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/api_service.dart';
import 'match_screen.dart';

class StockListScreen extends StatefulWidget {
  @override
  _StockListScreenState createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final ApiService apiService = ApiService();
  late Future<List<Stock>> futureStocks;

  @override
  void initState() {
    super.initState();
    futureStocks = apiService.fetchStocks();
  }

  void _refresh() {
    setState(() {
      futureStocks = apiService.fetchStocks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EGX Fair Values', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: FutureBuilder<List<Stock>>(
          future: futureStocks,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('No stocks found'));
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final stock = snapshot.data![index];
                final bool isMatched = stock.arabicStockGetter != null && stock.arabicStockGetter!.isNotEmpty;

                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: isMatched ? Colors.green.shade100 : Colors.orange.shade100,
                      child: Text(stock.ticker[0], style: TextStyle(color: isMatched ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(stock.ticker, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(stock.name ?? 'No Name'),
                    trailing: Icon(isMatched ? Icons.check_circle : Icons.warning_amber_rounded, color: isMatched ? Colors.green : Colors.orange),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Current Price:', style: TextStyle(color: Colors.grey)),
                                Text('${stock.price} EGP', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (stock.arabicStockFairValue != null) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Fair Value:', style: TextStyle(color: Colors.grey)),
                                  Text('${stock.arabicStockFairValue} EGP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            ],
                            if (stock.arabicStockAnalyzersFairValue != null) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Analyzers Fair Value:', style: TextStyle(color: Colors.grey)),
                                  Text('${stock.arabicStockAnalyzersFairValue} EGP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                ],
                              ),
                            ],
                            SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.link),
                                label: Text(isMatched ? 'Change Match' : 'Match ArabicStock'),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => MatchScreen(stock: stock)),
                                  );
                                  _refresh();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
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
    );
  }
}
