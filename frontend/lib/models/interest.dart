class Interest {
  final String id;
  final String name;
  final String nameAr;
  final int displayOrder;

  Interest({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.displayOrder,
  });

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id:           json['_id'] ?? json['id'] ?? '',
      name:         json['name'] ?? '',
      nameAr:       json['nameAr'] ?? '',
      displayOrder: json['displayOrder'] ?? 0,
    );
  }

  String localizedName(String lang) => lang == 'ar' && nameAr.isNotEmpty ? nameAr : name;
}
