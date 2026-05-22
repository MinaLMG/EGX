import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/api_service.dart';
import '../services/wallet_service.dart';
import 'match_screen.dart';
import 'mubasher_matching_screen.dart';

class StockListScreen extends StatefulWidget {
  @override
  _StockListScreenState createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final ApiService apiService = ApiService();
  final WalletService walletService = WalletService();
  late Future<List<Stock>> futureStocks;
  Set<String> walletTickers = {};
  String _sortCriteria = 'total'; // total, i1, i2, i3, i4, rfp, rsp

  @override
  void initState() {
    super.initState();
    futureStocks = apiService.fetchStocks();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await walletService.getWallet();
      final List items = wallet['wallet']?['items'] ?? [];
      setState(() {
        walletTickers = items.map((i) => i['stock']['ticker'] as String).toSet();
      });
    } catch (e) {
      // User might not be logged in or other error, ignore
    }
  }

  void _refresh() {
    setState(() {
      futureStocks = apiService.fetchStocks();
      _loadWallet();
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
          IconButton(
            icon: Icon(Icons.link),
            tooltip: 'Mubasher Matching',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MubasherMatchingScreen()),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort),
            onSelected: (String criteria) {
              setState(() {
                _sortCriteria = criteria;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'total', child: Text('Sort by Total Score')),
              PopupMenuItem<String>(value: 'i1', child: Text('Sort by BF Potential (i1)')),
              PopupMenuItem<String>(value: 'i2', child: Text('Sort by Fundamental (i2)')),
              PopupMenuItem<String>(value: 'i3', child: Text('Sort by Technical (i3)')),
              PopupMenuItem<String>(value: 'i4', child: Text('Sort by ArabStock (i4)')),
              PopupMenuItem<String>(value: 'rfp', child: Text('Sort by RFP Score')),
              PopupMenuItem<String>(value: 'rsp', child: Text('Sort by RSP Score')),
            ],
          ),
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

            final List<Stock> sortedStocks = List.from(snapshot.data!);
            sortedStocks.sort((a, b) {
              switch (_sortCriteria) {
                case 'i1': return b.bfPotential.compareTo(a.bfPotential);
                case 'i2': return b.fundamentalPotential.compareTo(a.fundamentalPotential);
                case 'i3': return b.technicalPotential.compareTo(a.technicalPotential);
                case 'i4': return b.arabstockScore.compareTo(a.arabstockScore);
                case 'rfp': return b.rfpScore.compareTo(a.rfpScore);
                case 'rsp': return b.rspScore.compareTo(a.rspScore);
                default: return b.totalScore.compareTo(a.totalScore);
              }
            });

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: sortedStocks.length,
              itemBuilder: (context, index) {
                final stock = sortedStocks[index];
                final bool isMatched = stock.arabicStockGetter != null && stock.arabicStockGetter!.isNotEmpty;
                final bool isInWallet = walletTickers.contains(stock.ticker);

                return Card(
                  color: isInWallet ? Colors.amber.shade50 : Colors.white,
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: isInWallet ? BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
                  ),
                  elevation: isInWallet ? 8 : 4,
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: isMatched ? Colors.green.shade100 : Colors.orange.shade100,
                      child: Text(stock.ticker[0], style: TextStyle(color: isMatched ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                    title: Row(
                      children: [
                        Text(stock.ticker, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        if (isInWallet) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('WALLET', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
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
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          ),
                        ),
                        Icon(
                          isMatched ? Icons.check_circle : Icons.warning_amber_rounded,
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
                            Divider(height: 32),
                            Text('Recommendation Scores', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            SizedBox(height: 8),
                            _buildScoreRow('BF Potential (i1)', stock.bfPotential),
                            _buildScoreRow('Fundamental (i2)', stock.fundamentalPotential),
                            _buildScoreRow('Technical (i3)', stock.technicalPotential),
                            _buildScoreRow('ArabStock (i4)', stock.arabstockScore),
                            _buildScoreRow('RFP Score', stock.rfpScore),
                            _buildScoreRow('RSP Score', stock.rspScore),
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

  Widget _buildScoreRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
