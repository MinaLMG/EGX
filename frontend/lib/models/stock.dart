class Stock {
  final String ticker;
  final String? name;
  final double price;
  final double? arabicStockFairValue;
  final double? arabicStockAnalyzersFairValue;
  final String? arabicStockGetter;
  final DateTime? lastUpdated;

  Stock({
    required this.ticker,
    this.name,
    required this.price,
    this.arabicStockFairValue,
    this.arabicStockAnalyzersFairValue,
    this.arabicStockGetter,
    this.lastUpdated,
    this.arabicStockTargetMode = 'max',
    this.arabicStockCustomFairValue,
    this.bfScore = 0.0,
    this.fundamentalScore = 0.0,
    this.technicalScore = 0.0,
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
      arabicStockTargetMode: json['arabic_stock_target_mode'] ?? 'max',
      arabicStockCustomFairValue: (json['arabic_stock_custom_fair_value'] as num?)?.toDouble(),
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : DateTime.now(),
      bfScore: (json['bf_score'] as num?)?.toDouble() ?? 0.0,
      fundamentalScore: (json['fundamental_score'] as num?)?.toDouble() ?? 0.0,
      technicalScore: (json['technical_score'] as num?)?.toDouble() ?? 0.0,
      arabstockScore: (json['arabstock_score'] as num?)?.toDouble() ?? 0.0,
      rfpScore: (json['rfp_score'] as num?)?.toDouble() ?? 0.0,
      rspScore: (json['rsp_score'] as num?)?.toDouble() ?? 0.0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String arabicStockTargetMode;
  final double? arabicStockCustomFairValue;

  double? get effectiveArabicStockTarget {
    switch (arabicStockTargetMode) {
      case 'manual':
        return arabicStockCustomFairValue;
      case 'analyzers':
        return arabicStockAnalyzersFairValue;
      case 'fair_value':
        return arabicStockFairValue;
      case 'max':
      default:
        final fv = arabicStockFairValue ?? 0.0;
        final afv = arabicStockAnalyzersFairValue ?? 0.0;
        final m = fv > afv ? fv : afv;
        return m > 0 ? m : null;
    }
  }

  final double bfScore;
  final double fundamentalScore;
  final double technicalScore;
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
