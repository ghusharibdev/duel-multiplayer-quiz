import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus {
  waiting,
  active,
  completed,
}

class PlayerAnswer {
  final int answerIndex;
  final int timeMs; // milliseconds to answer
  final bool isCorrect;
  final Timestamp? answeredAt; // server timestamp for the live race

  const PlayerAnswer({
    required this.answerIndex,
    required this.timeMs,
    required this.isCorrect,
    this.answeredAt,
  });

  factory PlayerAnswer.fromMap(Map<String, dynamic> map) {
    return PlayerAnswer(
      answerIndex: map['answerIndex'] ?? -1,
      timeMs: map['timeMs'] ?? 0,
      isCorrect: map['isCorrect'] ?? false,
      answeredAt: map['answeredAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'answerIndex': answerIndex,
      'timeMs': timeMs,
      'isCorrect': isCorrect,
      'answeredAt': answeredAt,
    };
  }
}

class RoundData {
  final String questionId;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final PlayerAnswer? player1Answer;
  final PlayerAnswer? player2Answer;
  final bool resolved;

  const RoundData({
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    this.player1Answer,
    this.player2Answer,
    this.resolved = false,
  });

  factory RoundData.fromMap(Map<String, dynamic> map) {
    return RoundData(
      questionId: map['questionId'] ?? '',
      questionText: map['questionText'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctIndex: map['correctIndex'] ?? 0,
      player1Answer: map['player1Answer'] != null
          ? PlayerAnswer.fromMap(map['player1Answer'])
          : null,
      player2Answer: map['player2Answer'] != null
          ? PlayerAnswer.fromMap(map['player2Answer'])
          : null,
      resolved: map['resolved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'questionText': questionText,
      'options': options,
      'correctIndex': correctIndex,
      'player1Answer': player1Answer?.toMap(),
      'player2Answer': player2Answer?.toMap(),
      'resolved': resolved,
    };
  }

  bool get bothAnswered =>
      player1Answer != null && player2Answer != null;
}

class Match {
  final String id;
  final String player1Id;
  final String player2Id;
  final String player1Name;
  final String player2Name;
  final int player1Score;
  final int player2Score;
  final int currentRound;
  final int totalRounds;
  final MatchStatus status;
  final List<RoundData> rounds;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Match({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    this.player1Name = '',
    this.player2Name = '',
    this.player1Score = 0,
    this.player2Score = 0,
    this.currentRound = 0,
    this.totalRounds = 5,
    this.status = MatchStatus.waiting,
    this.rounds = const [],
    required this.createdAt,
    this.completedAt,
  });

  factory Match.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Match(
      id: doc.id,
      player1Id: data['player1Id'] ?? '',
      player2Id: data['player2Id'] ?? '',
      player1Name: data['player1Name'] ?? '',
      player2Name: data['player2Name'] ?? '',
      player1Score: data['player1Score'] ?? 0,
      player2Score: data['player2Score'] ?? 0,
      currentRound: data['currentRound'] ?? 0,
      totalRounds: data['totalRounds'] ?? 5,
      status: MatchStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => MatchStatus.waiting,
      ),
      rounds: _decodeRounds(data['rounds']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'player1Id': player1Id,
      'player2Id': player2Id,
      'player1Name': player1Name,
      'player2Name': player2Name,
      'player1Score': player1Score,
      'player2Score': player2Score,
      'currentRound': currentRound,
      'totalRounds': totalRounds,
      'status': status.name,
      'rounds': rounds.map((r) => r.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  static List<RoundData> _decodeRounds(dynamic roundsData) {
    if (roundsData is List<dynamic>) {
      return roundsData.map((r) => RoundData.fromMap(r)).toList();
    } else if (roundsData is Map<String, dynamic>) {
      // Firestore dot-notation updates on arrays can convert them to maps
      // with numeric string keys. Recover by sorting keys and converting.
      final sortedKeys = roundsData.keys.toList()..sort();
      return sortedKeys
          .where((k) => roundsData[k] is Map<String, dynamic>)
          .map((k) => RoundData.fromMap(roundsData[k]))
          .toList();
    }
    return [];
  }

  bool get isFinished => status == MatchStatus.completed;
  bool get isDraw => player1Score == player2Score;

  bool isPlayer1(String uid) => player1Id == uid;

  String opponentNameOf(String uid) => isPlayer1(uid) ? player2Name : player1Name;

  int opponentScoreOf(String uid) => isPlayer1(uid) ? player2Score : player1Score;

  PlayerAnswer? opponentAnswerOf(String uid, RoundData round) =>
      isPlayer1(uid) ? round.player2Answer : round.player1Answer;

  RoundData? get currentRoundData =>
      currentRound > 0 && currentRound <= rounds.length
          ? rounds[currentRound - 1]
          : null;
}
