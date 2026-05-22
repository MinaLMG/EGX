import 'stock.dart';

class BFValue {
  final String id;
  final Stock stock;
  final double value;

  BFValue({required this.id, required this.stock, required this.value});

  factory BFValue.fromJson(Map<String, dynamic> json) {
    return BFValue(
      id: json['_id'],
      stock: Stock.fromJson(json['stock']),
      value: (json['value'] as num).toDouble(),
    );
  }
}

class Recommendation {
  final String id;
  final Stock stock;
  final double? target;
  final double? score;
  final String? notes;

  Recommendation({
    required this.id,
    required this.stock,
    this.target,
    this.score,
    this.notes,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['_id'],
      stock: Stock.fromJson(json['stock']),
      target: json['target'] != null ? (json['target'] as num).toDouble() : null,
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      notes: json['notes'],
    );
  }
}

class AllRecommendations {
  final List<BFValue> bfValues;
  final List<Recommendation> rfp;
  final List<Recommendation> rsp;
  final List<Recommendation> fundamental;
  final List<Recommendation> technical;

  AllRecommendations({
    required this.bfValues,
    required this.rfp,
    required this.rsp,
    required this.fundamental,
    required this.technical,
  });

  factory AllRecommendations.fromJson(Map<String, dynamic> json) {
    return AllRecommendations(
      bfValues: (json['bfValues'] as List).map((i) => BFValue.fromJson(i)).toList(),
      rfp: (json['rfp'] as List).map((i) => Recommendation.fromJson(i)).toList(),
      rsp: (json['rsp'] as List).map((i) => Recommendation.fromJson(i)).toList(),
      fundamental: (json['fundamental'] as List).map((i) => Recommendation.fromJson(i)).toList(),
      technical: (json['technical'] as List).map((i) => Recommendation.fromJson(i)).toList(),
    );
  }
}
