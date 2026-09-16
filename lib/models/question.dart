import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String category;
  final int difficulty; // 1-5

  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.category,
    this.difficulty = 1,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      text: data['text'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctIndex: data['correctIndex'] ?? 0,
      category: data['category'] ?? 'General',
      difficulty: data['difficulty'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'options': options,
      'correctIndex': correctIndex,
      'category': category,
      'difficulty': difficulty,
    };
  }
}
