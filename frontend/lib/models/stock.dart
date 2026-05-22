class Stock {
  final String ticker;
  final String? name;
  final double price;
  final double? arabicStockFairValue;
  final double? arabicStockAnalyzersFairValue;
  final String? arabicStockGetter;
  final DateTime lastUpdated;

  Stock({
    required this.ticker,
    this.name,
    required this.price,
    this.arabicStockFairValue,
    this.arabicStockAnalyzersFairValue,
    this.arabicStockGetter,
    required this.lastUpdated,
    this.bfPotential = 0.0,
    this.fundamentalPotential = 0.0,
    this.technicalPotential = 0.0,
    this.arabstockScore = 0.0,
    this.rfpScore = 0.0,
    this.rspScore = 0.0,
    this.totalScore = 0.0,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      ticker: json['ticker'] ?? 'UNKNOWN',
      name: json['name'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0,
      arabicStockFairValue: json['arabic_stock_fair_value'] != null 
          ? (json['arabic_stock_fair_value'] as num).toDouble() 
          : null,
      arabicStockAnalyzersFairValue: json['arabic_stock_analyzers_fair_value'] != null 
          ? (json['arabic_stock_analyzers_fair_value'] as num).toDouble() 
          : null,
      arabicStockGetter: json['arabic_stock_getter'],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : DateTime.now(),
      bfPotential: (json['bf_potential'] as num?)?.toDouble() ?? 0.0,
      fundamentalPotential: (json['fundamental_potential'] as num?)?.toDouble() ?? 0.0,
      technicalPotential: (json['technical_potential'] as num?)?.toDouble() ?? 0.0,
      arabstockScore: (json['arabstock_score'] as num?)?.toDouble() ?? 0.0,
      rfpScore: (json['rfp_score'] as num?)?.toDouble() ?? 0.0,
      rspScore: (json['rsp_score'] as num?)?.toDouble() ?? 0.0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final double bfPotential;
  final double fundamentalPotential;
  final double technicalPotential;
  final double arabstockScore;
  final double rfpScore;
  final double rspScore;
  final double totalScore;
}

class ArabicStockMatch {
  final String title;
  final String link;

  ArabicStockMatch({required this.title, required this.link});

  factory ArabicStockMatch.fromJson(Map<String, dynamic> json) {
    return ArabicStockMatch(
      title: json['title'],
      link: json['link'],
    );
  }
}
