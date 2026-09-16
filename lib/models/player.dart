import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerStats {
  final int wins;
  final int losses;
  final int draws;
  final int streak;
  final int bestStreak;
  final int rating;
  final int totalMatches;

  const PlayerStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.rating = 1000,
    this.totalMatches = 0,
  });

  factory PlayerStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerStats(
      wins: data['wins'] ?? 0,
      losses: data['losses'] ?? 0,
      draws: data['draws'] ?? 0,
      streak: data['streak'] ?? 0,
      bestStreak: data['bestStreak'] ?? 0,
      rating: data['rating'] ?? 1000,
      totalMatches: data['totalMatches'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'streak': streak,
      'bestStreak': bestStreak,
      'rating': rating,
      'totalMatches': totalMatches,
    };
  }

  PlayerStats copyWith({
    int? wins,
    int? losses,
    int? draws,
    int? streak,
    int? bestStreak,
    int? rating,
    int? totalMatches,
  }) {
    return PlayerStats(
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      rating: rating ?? this.rating,
      totalMatches: totalMatches ?? this.totalMatches,
    );
  }
}

class Player {
  final String uid;
  final String displayName;
  final String? email;
  final bool isAnonymous;
  final PlayerStats stats;
  final DateTime createdAt;
  final DateTime lastSeen;

  const Player({
    required this.uid,
    required this.displayName,
    this.email,
    this.isAnonymous = true,
    this.stats = const PlayerStats(),
    required this.createdAt,
    required this.lastSeen,
  });

  factory Player.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Player(
      uid: doc.id,
      displayName: data['displayName'] ?? 'Guest',
      email: data['email'],
      isAnonymous: data['isAnonymous'] ?? true,
      stats: PlayerStats.fromFirestore(doc),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'wins': stats.wins,
      'losses': stats.losses,
      'draws': stats.draws,
      'streak': stats.streak,
      'bestStreak': stats.bestStreak,
      'rating': stats.rating,
      'totalMatches': stats.totalMatches,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
    };
  }
}
