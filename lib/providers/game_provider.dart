import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../models/match.dart';
import '../services/open_trivia_service.dart';
import '../services/notification_service.dart';

// ---------------------------------------------------------------------------
// Provider: selected category for matchmaking
// ---------------------------------------------------------------------------
class MatchPreferences {
  final int? categoryId;
  final int? difficulty;
  final String categoryName;

  const MatchPreferences({
    this.categoryId,
    this.difficulty,
    this.categoryName = 'Any',
  });
}

class MatchPreferencesNotifier extends Notifier<MatchPreferences> {
  @override
  MatchPreferences build() => const MatchPreferences();

  void update({int? categoryId, int? difficulty, String? categoryName}) {
    state = MatchPreferences(
      categoryId: categoryId ?? state.categoryId,
      difficulty: difficulty ?? state.difficulty,
      categoryName: categoryName ?? state.categoryName,
    );
  }

  void reset() {
    state = const MatchPreferences();
  }
}

final matchPreferencesProvider =
    NotifierProvider<MatchPreferencesNotifier, MatchPreferences>(
  MatchPreferencesNotifier.new,
);

// ---------------------------------------------------------------------------
// Current active match stream
// ---------------------------------------------------------------------------
final currentMatchProvider = StreamProvider<Match?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  final p1Stream = FirebaseFirestore.instance
      .collection('matches')
      .where('player1Id', isEqualTo: user.uid)
      .snapshots();

  final p2Stream = FirebaseFirestore.instance
      .collection('matches')
      .where('player2Id', isEqualTo: user.uid)
      .snapshots();

  return Rx.combineLatest2(
      p1Stream, p2Stream, (QuerySnapshot a, QuerySnapshot b) {
    final allDocs = [...a.docs, ...b.docs];

    final active = allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] != 'completed';
    }).toList();

    if (active.isEmpty) return null;

    active.sort((a, b) {
      final aTime =
          (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bTime =
          (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return Match.fromFirestore(active.first);
  });
});

// ---------------------------------------------------------------------------
// Single-match document stream (for room creator waiting for opponent)
// ---------------------------------------------------------------------------
Stream<Match?> matchDocStream(String matchId) {
  return FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .snapshots()
      .map((doc) {
    if (doc.exists) return Match.fromFirestore(doc);
    return null;
  });
}

// ---------------------------------------------------------------------------
// Game service
// ---------------------------------------------------------------------------
class GameService {
  final Ref ref;
  final OpenTriviaService _triviaService = OpenTriviaService();
  StreamSubscription? _matchSubscription;
  Match? _currentMatch;
  Timer? _roundTimeout;
  bool _resolving = false;
  bool _submittingAnswer = false;
  bool _statsUpdated = false;
  int _timeoutRound = -1;
  DateTime? _roundStartTime;

  GameService(this.ref);

  Match? get currentMatch => _currentMatch;

  /// Start matchmaking: look for an existing waiting match, or create one.
  Future<void> startMatchmaking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _ensurePlayerExists(user);

    final prefs = ref.read(matchPreferencesProvider);

    // Try to join an existing compatible waiting match (exclude private rooms)
    final waitingSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('status', isEqualTo: 'waiting')
        .limit(100)
        .get();

    for (final doc in waitingSnapshot.docs) {
      final data = doc.data();
      if (data['player1Id'] == user.uid) continue;
      if (data['isPrivate'] == true) continue; // skip private rooms

      final matchCategoryId = data['categoryId'];
      final matchDifficulty = data['difficulty'];

      final categoryCompatible = prefs.categoryId == null ||
          matchCategoryId == null ||
          prefs.categoryId == matchCategoryId;
      final difficultyCompatible = prefs.difficulty == null ||
          matchDifficulty == null ||
          prefs.difficulty == matchDifficulty;

      if (categoryCompatible && difficultyCompatible) {
        await _joinMatch(doc.id);
        return;
      }
    }

    // No match found — create one and LISTEN for someone to join
    await _createMatch(prefs);
  }

  Future<void> _ensurePlayerExists(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('players')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseFirestore.instance.collection('players').doc(user.uid).set({
        'displayName': user.isAnonymous ? 'Guest' : (user.displayName?.isNotEmpty == true ? user.displayName! : user.email?.split('@').first ?? 'Player'),
        'email': user.email,
        'isAnonymous': user.isAnonymous,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'streak': 0,
        'bestStreak': 0,
        'rating': 1000,
        'totalMatches': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } else {
      if (!user.isAnonymous && user.email != null) {
        final data = doc.data();
        if (data != null && (data['displayName'] ?? '') == 'Guest') {
          await FirebaseFirestore.instance
              .collection('players')
              .doc(user.uid)
              .update({
            'displayName': user.email!.split('@').first,
            'email': user.email,
            'isAnonymous': false,
          });
        }
      }
    }
  }

  Future<void> _createMatch(MatchPreferences prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final questions = await _triviaService.fetchRandomQuestions(
      5,
      categoryId: prefs.categoryId,
      difficulty: prefs.difficulty,
    );
    if (questions.isEmpty) throw Exception('No questions available');

    final displayName =
        user.isAnonymous ? 'Guest' : (user.displayName?.isNotEmpty == true ? user.displayName! : user.email?.split('@').first ?? 'Player');

    final matchData = {
      'player1Id': user.uid,
      'player2Id': '',
      'player1Name': displayName,
      'player2Name': '',
      'player1Score': 0,
      'player2Score': 0,
      'currentRound': 0,
      'totalRounds': 5,
      'status': 'waiting',
      'isPrivate': false,
      'categoryId': prefs.categoryId,
      'categoryName': prefs.categoryName,
      'difficulty': prefs.difficulty,
      'rounds': questions
          .map((q) => {
                'questionId': q.id,
                'questionText': q.text,
                'options': q.options,
                'correctIndex': q.correctIndex,
                'category': q.category,
                'player1Answer': null,
                'player2Answer': null,
                'resolved': false,
              })
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    };

    final docRef =
        await FirebaseFirestore.instance.collection('matches').add(matchData);

    _statsUpdated = false;
    _listenToMatch(docRef.id);
  }

  Future<void> _joinMatch(String matchId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final displayName =
        user.isAnonymous ? 'Guest' : (user.displayName?.isNotEmpty == true ? user.displayName! : user.email?.split('@').first ?? 'Player');

    // Notify the waiting player
    final matchDoc = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .get();
    final player1Id = matchDoc.data()?['player1Id'] as String?;
    if (player1Id != null) {
      NotificationService.sendToPlayer(
        targetUid: player1Id,
        title: 'Match Found!',
        body: '$displayName joined your match',
        data: {'matchId': matchId, 'type': 'match_joined'},
      );
    }

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'player2Id': user.uid,
      'player2Name': displayName,
      'status': 'active',
      'currentRound': 1,
    });

    _statsUpdated = false;
    _listenToMatch(matchId);
  }

  void _listenToMatch(String matchId) {
    _matchSubscription?.cancel();
    _matchSubscription = FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _currentMatch = Match.fromFirestore(doc);

        if (_currentMatch!.currentRoundData != null &&
            !_currentMatch!.currentRoundData!.resolved) {
          _startRoundTimeout();
        }

        if (_currentMatch!.isFinished) {
          _roundTimeout?.cancel();
          if (!_statsUpdated) {
            _statsUpdated = true;
            _updatePlayerStats();

            final m = _currentMatch!;
            final isDraw = m.player1Score == m.player2Score;
            final p1Won = m.player1Score > m.player2Score;
            NotificationService.sendMatchResult(
              player1Uid: m.player1Id,
              player2Uid: m.player2Id,
              matchId: m.id,
              player1Won: p1Won,
              isDraw: isDraw,
            );
          }
        }
      }
    });
  }

  /// Listen to a specific match doc by ID (for room creator)
  void listenToMatchById(String matchId) {
    _listenToMatch(matchId);
  }

  void _startRoundTimeout() {
    _roundTimeout?.cancel();
    final match = _currentMatch;
    if (match == null || match.isFinished) return;

    final roundData = match.currentRoundData;
    if (roundData == null || roundData.resolved) return;
    if (match.currentRound == _timeoutRound) return;

    _timeoutRound = match.currentRound;
    _roundStartTime = DateTime.now();

    _roundTimeout = Timer(const Duration(seconds: 20), () {
      _resolveRoundOnTimeout();
    });
  }

  Future<void> _resolveRoundOnTimeout() async {
    final match = _currentMatch;
    if (match == null || match.isFinished) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roundIndex = match.currentRound - 1;
    if (roundIndex < 0 || roundIndex >= match.rounds.length) return;
    final roundData = match.rounds[roundIndex];
    if (roundData.resolved) return;

    final isPlayer1 = user.uid == match.player1Id;
    final myAnswer =
        isPlayer1 ? roundData.player1Answer : roundData.player2Answer;

    if (myAnswer == null) {
      final timeoutAnswer = {
        'answerIndex': -1,
        'timeMs': 20000,
        'isCorrect': false,
        'answeredAt': Timestamp.fromDate(DateTime.now()),
      };

      // Use transaction to safely write timeout answer
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .update(isPlayer1
              ? {'rounds.$roundIndex.player1Answer': timeoutAnswer}
              : {'rounds.$roundIndex.player2Answer': timeoutAnswer});
    }

    // Re-read and resolve
    final freshDoc = await FirebaseFirestore.instance
        .collection('matches')
        .doc(match.id)
        .get();
    if (freshDoc.exists) {
      _currentMatch = Match.fromFirestore(freshDoc);
      await _resolveRoundIfReady();
    }
  }

  /// Submit an answer — uses dot-path update to avoid array overwrites.
  Future<void> submitAnswer(int answerIndex) async {
    if (_submittingAnswer) return;
    _submittingAnswer = true;

    try {
      final match = _currentMatch;
      if (match == null || match.isFinished) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final isPlayer1 = user.uid == match.player1Id;
      final roundIndex = match.currentRound - 1;
      if (roundIndex < 0 || roundIndex >= match.rounds.length) return;

      final roundData = match.rounds[roundIndex];
      if (isPlayer1 && roundData.player1Answer != null) return;
      if (!isPlayer1 && roundData.player2Answer != null) return;

      final isCorrect = answerIndex == roundData.correctIndex;
      final now = DateTime.now();

      final answer = {
        'answerIndex': answerIndex,
        'timeMs': _getAnswerTimeMs(match),
        'isCorrect': isCorrect,
        'answeredAt': Timestamp.fromDate(now),
      };

      final fieldPath = isPlayer1
          ? 'rounds.$roundIndex.player1Answer'
          : 'rounds.$roundIndex.player2Answer';

      await FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .update({fieldPath: answer});

      final freshDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .get();
      if (freshDoc.exists) {
        _currentMatch = Match.fromFirestore(freshDoc);
        await _resolveRoundIfReady();
      }
    } finally {
      _submittingAnswer = false;
    }
  }

  int _getAnswerTimeMs(Match match) {
    final roundData = match.currentRoundData;
    if (roundData != null && roundData.player1Answer != null && roundData.player2Answer != null) {
      return 0;
    }
    // Compute elapsed milliseconds since the round started
    if (_roundStartTime != null) {
      return DateTime.now().difference(_roundStartTime!).inMilliseconds;
    }
    // Fallback: use elapsed since match creation
    return DateTime.now().difference(match.createdAt).inMilliseconds.clamp(0, 20000);
  }

  Future<void> _resolveRoundIfReady() async {
    if (_resolving) return;
    _resolving = true;

    try {
      final match = _currentMatch;
      if (match == null || match.isFinished) return;

      final roundIndex = match.currentRound - 1;
      if (roundIndex < 0 || roundIndex >= match.rounds.length) return;
      final roundData = match.rounds[roundIndex];
      if (roundData.resolved) return;
      if (!roundData.bothAnswered) return;

      _roundTimeout?.cancel();

      int p1Points = 0;
      int p2Points = 0;

      final p1 = roundData.player1Answer!;
      final p2 = roundData.player2Answer!;

      int p1Time = p1.timeMs;
      int p2Time = p2.timeMs;
      if (p1.answeredAt != null && p2.answeredAt != null) {
        final p1Ms = p1.answeredAt!.millisecondsSinceEpoch;
        final p2Ms = p2.answeredAt!.millisecondsSinceEpoch;
        final baseTime = p1Ms < p2Ms ? p1Ms : p2Ms;
        p1Time = p1Ms - baseTime;
        p2Time = p2Ms - baseTime;
      }

      if (p1.isCorrect && p2.isCorrect) {
        if (p1Time <= p2Time) {
          p1Points = 10;
          p2Points = 7;
        } else {
          p1Points = 7;
          p2Points = 10;
        }
      } else if (p1.isCorrect) {
        p1Points = 10;
      } else if (p2.isCorrect) {
        p2Points = 10;
      }

      // Use Firestore transaction to prevent concurrent overwrites
      final matchRef = FirebaseFirestore.instance.collection('matches').doc(match.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshDoc = await transaction.get(matchRef);
        if (!freshDoc.exists) return;

        final freshData = freshDoc.data()!;
        final freshP1Score = freshData['player1Score'] ?? 0;
        final freshP2Score = freshData['player2Score'] ?? 0;
        final freshRoundData = (freshData['rounds'] as List<dynamic>?)?[roundIndex];
        if (freshRoundData == null || freshRoundData['resolved'] == true) return;

        final isLastRound = (freshData['currentRound'] ?? 1) >= (freshData['totalRounds'] ?? 5);
        final newStatus = isLastRound ? 'completed' : 'active';
        final nextRound = isLastRound ? (freshData['currentRound'] ?? 1) : (freshData['currentRound'] ?? 1) + 1;

        final updateData = <String, dynamic>{
          'rounds.$roundIndex.resolved': true,
          'rounds.$roundIndex.player1TimeMs': p1Time,
          'rounds.$roundIndex.player2TimeMs': p2Time,
          'player1Score': freshP1Score + p1Points,
          'player2Score': freshP2Score + p2Points,
          'currentRound': nextRound,
          'status': newStatus,
        };

        if (isLastRound) {
          updateData['completedAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(matchRef, updateData);
      });
    } finally {
      _resolving = false;
    }
  }

  Future<void> _updatePlayerStats() async {
    final match = _currentMatch;
    if (match == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isPlayer1 = user.uid == match.player1Id;
    final myScore = isPlayer1 ? match.player1Score : match.player2Score;
    final oppScore = isPlayer1 ? match.player2Score : match.player1Score;

    final won = myScore > oppScore;
    final drew = myScore == oppScore;

    int ratingChange = won ? 25 : (drew ? 5 : -15);

    final doc = await FirebaseFirestore.instance
        .collection('players')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      int currentStreak = data['streak'] ?? 0;
      int bestStreak = data['bestStreak'] ?? 0;
      int newStreak = won ? currentStreak + 1 : 0;
      if (newStreak > bestStreak) bestStreak = newStreak;

      await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .update({
        'wins': (data['wins'] ?? 0) + (won ? 1 : 0),
        'losses': (data['losses'] ?? 0) + (!won && !drew ? 1 : 0),
        'draws': (data['draws'] ?? 0) + (drew ? 1 : 0),
        'streak': newStreak,
        'bestStreak': bestStreak,
        'rating': (data['rating'] ?? 1000) + ratingChange,
        'totalMatches': (data['totalMatches'] ?? 0) + 1,
      });
    }
  }

  Future<void> cancelMatchmaking() async {
    if (_currentMatch != null) {
      if (_currentMatch!.status == MatchStatus.waiting) {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(_currentMatch!.id)
            .delete();
      }
    }
    _matchSubscription?.cancel();
    _matchSubscription = null;
    _currentMatch = null;
    _statsUpdated = false;
    _roundTimeout?.cancel();
  }

  void dispose() {
    _matchSubscription?.cancel();
    _roundTimeout?.cancel();
  }
}

final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(ref);
});

final isWaitingForOpponentProvider = Provider<bool>((ref) {
  final matchAsync = ref.watch(currentMatchProvider);
  return matchAsync.whenOrNull(
        data: (match) => match?.status == MatchStatus.waiting,
      ) ??
      false;
});

// ---------------------------------------------------------------------------
// Online / waiting players
// ---------------------------------------------------------------------------
class WaitingPlayer {
  final String uid;
  final String name;
  final String? categoryName;
  final String? difficultyName;
  final DateTime joinedAt;

  const WaitingPlayer({
    required this.uid,
    required this.name,
    this.categoryName,
    this.difficultyName,
    required this.joinedAt,
  });
}

final waitingPlayersProvider = StreamProvider<List<WaitingPlayer>>((ref) {
  final user = FirebaseAuth.instance.currentUser;

  return FirebaseFirestore.instance
      .collection('matches')
      .where('status', isEqualTo: 'waiting')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.where((doc) {
      final data = doc.data();
      return data['player1Id'] != user?.uid;
    }).map((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'];
      DateTime joinedAt = DateTime.now();
      if (createdAt is Timestamp) {
        joinedAt = createdAt.toDate();
      }
      return WaitingPlayer(
        uid: data['player1Id'] ?? '',
        name: data['player1Name'] ?? 'Player',
        categoryName: data['categoryName'] ?? 'Any',
        difficultyName: _difficultyLabel(data['difficulty']),
        joinedAt: joinedAt,
      );
    }).toList();
  });
});

// ---------------------------------------------------------------------------
// Room creation with invite code
// ---------------------------------------------------------------------------
class RoomService {
  final OpenTriviaService _triviaService = OpenTriviaService();

  Future<String> createRoom(MatchPreferences prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final code = _generateCode();

    final questions = await _triviaService.fetchRandomQuestions(
      5,
      categoryId: prefs.categoryId,
      difficulty: prefs.difficulty,
    );
    if (questions.isEmpty) throw Exception('No questions available');

    final displayName =
        user.isAnonymous ? 'Guest' : (user.displayName?.isNotEmpty == true ? user.displayName! : user.email?.split('@').first ?? 'Player');

    final matchData = {
      'player1Id': user.uid,
      'player2Id': '',
      'player1Name': displayName,
      'player2Name': '',
      'player1Score': 0,
      'player2Score': 0,
      'currentRound': 0,
      'totalRounds': 5,
      'status': 'waiting',
      'roomCode': code,
      'isPrivate': true,
      'categoryId': prefs.categoryId,
      'categoryName': prefs.categoryName,
      'difficulty': prefs.difficulty,
      'rounds': questions
          .map((q) => {
                'questionId': q.id,
                'questionText': q.text,
                'options': q.options,
                'correctIndex': q.correctIndex,
                'category': q.category,
                'player1Answer': null,
                'player2Answer': null,
                'resolved': false,
              })
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    };

    await FirebaseFirestore.instance.collection('matches').add(matchData);
    return code;
  }

  Future<String?> joinRoom(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('roomCode', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();

    if (data['player1Id'] == user.uid) return null;

    final displayName =
        user.isAnonymous ? 'Guest' : (user.displayName?.isNotEmpty == true ? user.displayName! : user.email?.split('@').first ?? 'Player');

    await FirebaseFirestore.instance
        .collection('matches')
        .doc(doc.id)
        .update({
      'player2Id': user.uid,
      'player2Name': displayName,
      'status': 'active',
      'currentRound': 1,
    });

    return doc.id;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = DateTime.now().microsecondsSinceEpoch;
    var code = '';
    var n = rng;
    for (int i = 0; i < 6; i++) {
      code += chars[n % chars.length];
      n ~/= chars.length;
    }
    return code;
  }
}

final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

String _difficultyLabel(int? difficulty) {
  switch (difficulty) {
    case 1:
      return 'Easy';
    case 2:
      return 'Medium';
    case 3:
      return 'Hard';
    default:
      return 'Any';
  }
}
