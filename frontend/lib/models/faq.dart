class FAQ {
  final String id;
  final String question;
  final String? questionAr;
  final String answer;
  final String? answerAr;
  final int displayOrder;

  FAQ({
    required this.id,
    required this.question,
    this.questionAr,
    required this.answer,
    this.answerAr,
    required this.displayOrder,
  });

  factory FAQ.fromJson(Map<String, dynamic> json) {
    return FAQ(
      id:           json['_id'] ?? json['id'] ?? '',
      question:     json['question'] ?? '',
      questionAr:   json['questionAr'],
      answer:       json['answer'] ?? '',
      answerAr:     json['answerAr'],
      displayOrder: json['displayOrder'] ?? 0,
    );
  }

  String localizedQuestion(String lang) {
    if (lang == 'ar' && questionAr != null && questionAr!.isNotEmpty) {
      return questionAr!;
    }
    return question;
  }

  String localizedAnswer(String lang) {
    if (lang == 'ar' && answerAr != null && answerAr!.isNotEmpty) {
      return answerAr!;
    }
    return answer;
  }
}
