import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  final int totalRounds;

  const MatchPreferences({
    this.categoryId,
    this.difficulty,
    this.categoryName = 'Any',
    this.totalRounds = 5,
  });
}

class MatchPreferencesNotifier extends Notifier<MatchPreferences> {
  @override
  MatchPreferences build() => const MatchPreferences();

  void update({int? categoryId, int? difficulty, String? categoryName, int? totalRounds}) {
    state = MatchPreferences(
      categoryId: categoryId ?? state.categoryId,
      difficulty: difficulty ?? state.difficulty,
      categoryName: categoryName ?? state.categoryName,
      totalRounds: totalRounds ?? state.totalRounds,
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
// Provider: listen to a specific match by ID (used by MatchScreen)
// ---------------------------------------------------------------------------
final matchByIdProvider = StreamProvider.family<Match?, String>((ref, matchId) {
  return FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .snapshots()
      .map((doc) {
    if (doc.exists) return Match.fromFirestore(doc);
    return null;
  });
});

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

  /// Reset all transient state — call when starting a fresh session.
  void resetState() {
    _matchSubscription?.cancel();
    _matchSubscription = null;
    _currentMatch = null;
    _roundTimeout?.cancel();
    _roundTimeout = null;
    _resolving = false;
    _submittingAnswer = false;
    _statsUpdated = false;
    _timeoutRound = -1;
    _roundStartTime = null;
  }

  /// Start matchmaking: look for an existing waiting match, or create one.
  /// Returns the match ID when done.
  Future<String?> startMatchmaking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    resetState();
    await _ensurePlayerExists(user);

    final prefs = ref.read(matchPreferencesProvider);

    // Delete stale WAITING matches for this user (as player1 AND player2).
    // Only delete 'waiting' matches — never delete 'active' matches as they
    // may have an opponent already connected.
    final p1Matches = await FirebaseFirestore.instance
        .collection('matches')
        .where('player1Id', isEqualTo: user.uid)
        .get();
    for (final doc in p1Matches.docs) {
      final status = doc.data()['status'];
      if (status == 'waiting') {
        await doc.reference.delete();
      }
    }

    final p2Matches = await FirebaseFirestore.instance
        .collection('matches')
        .where('player2Id', isEqualTo: user.uid)
        .get();
    for (final doc in p2Matches.docs) {
      final status = doc.data()['status'];
      if (status == 'waiting') {
        await doc.reference.delete();
      }
    }

    // Fetch open matches and sort newest first client-side
    final waitingSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('status', isEqualTo: 'waiting')
        .get();

    final docs = waitingSnapshot.docs.toList()
      ..sort((a, b) {
        final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

    for (final doc in docs) {
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
        return doc.id;
      }
    }

    // No match found — create one and LISTEN for someone to join
    final matchId = await _createMatch(prefs);
    return matchId;
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

  Future<String> _createMatch(MatchPreferences prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final numQuestions = prefs.totalRounds;
    final questions = await _triviaService.fetchRandomQuestions(
      numQuestions,
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
      'totalRounds': numQuestions,
      'status': 'waiting',
      'isPrivate': false,
      'categoryId': prefs.categoryId,
      'categoryName': prefs.categoryName,
      'difficulty': prefs.difficulty,
      'rounds': {
        for (int i = 0; i < questions.length; i++)
          '$i': {
            'questionId': questions[i].id,
            'questionText': questions[i].text,
            'options': questions[i].options,
            'correctIndex': questions[i].correctIndex,
            'category': questions[i].category,
            'player1Answer': null,
            'player2Answer': null,
            'resolved': false,
          },
      },
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    };

    final docRef =
        await FirebaseFirestore.instance.collection('matches').add(matchData);

    _statsUpdated = false;
    _listenToMatch(docRef.id);
    return docRef.id;
  }

  Future<void> _joinMatch(String matchId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final displayName =
        user.isAnonymous ? 'Guest' : (user.displayName?.isNotEmpty == true ? user.displayName! : user.email?.split('@').first ?? 'Player');

    // Use a transaction to atomically check-and-join, preventing two
    // players from joining the same match simultaneously.
    final matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);
    String? player1Id;
    final joined = await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(matchRef);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['status'] != 'waiting' || (data['player2Id'] as String?)?.isNotEmpty == true) {
        return false; // already joined or not waiting
      }
      player1Id = data['player1Id'] as String?;
      transaction.update(matchRef, {
        'player2Id': user.uid,
        'player2Name': displayName,
        'status': 'active',
        'currentRound': 1,
      });
      return true;
    });

    if (!joined) {
      throw Exception('Match is no longer available');
    }

    // Notify the waiting player
    if (player1Id != null) {
      NotificationService.sendToPlayer(
        targetUid: player1Id!,
        title: 'Match Found!',
        body: '$displayName joined your match',
        data: {'matchId': matchId, 'type': 'match_joined'},
      );
    }

    _statsUpdated = false;
    _listenToMatch(matchId);
  }

  void _listenToMatch(String matchId) {
    _matchSubscription?.cancel();
    _matchSubscription = FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists) {
        _currentMatch = Match.fromFirestore(doc);

        final m = _currentMatch!;
        final roundData = m.currentRoundData;

        if (roundData != null && !roundData.resolved) {
          // Record the round start time on the first update for this round
          if (_roundStartTime == null || _timeoutRound != m.currentRound) {
            _roundStartTime = DateTime.now();
          }
          _startRoundTimeout();
          // Trigger resolution automatically if both players have submitted answers
          if (roundData.bothAnswered) {
            await _resolveRoundIfReady();
          }
        }

        if (m.isFinished) {
          _roundTimeout?.cancel();
          if (!_statsUpdated) {
            _statsUpdated = true;
            _updatePlayerStats();

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
    }, onError: (error) {
      debugPrint('[GameService] Stream error for match $matchId: $error');
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
    // Record the round start time when the timeout begins for a new round.
    // This is used by _getAnswerTimeMs to compute how fast the player answered.
    _roundStartTime = DateTime.now();

    _roundTimeout = Timer(const Duration(seconds: 20), () {
      _resolveRoundOnTimeout().catchError((e) {
        debugPrint('[GameService] Timeout resolution error: $e');
      });
    });
  }

  Future<void> _resolveRoundOnTimeout() async {
    try {
      final match = _currentMatch;
      if (match == null || match.isFinished) return;

      final roundIndex = match.currentRound - 1;
      if (roundIndex < 0 || roundIndex >= match.rounds.length) return;
      final roundData = match.rounds[roundIndex];
      if (roundData.resolved) return;

      // Submit timeout answers for BOTH players who haven't answered yet.
      // This prevents a deadlock where one player's timeout fires but the
      // other player is offline/disconnected and never submits.
      final timeoutAnswer = {
        'answerIndex': -1,
        'timeMs': 20000,
        'isCorrect': false,
        'answeredAt': Timestamp.fromDate(DateTime.now()),
      };

      final updates = <String, dynamic>{};
      if (roundData.player1Answer == null) {
        updates['rounds.$roundIndex.player1Answer'] = timeoutAnswer;
      }
      if (roundData.player2Answer == null) {
        updates['rounds.$roundIndex.player2Answer'] = timeoutAnswer;
      }

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(match.id)
            .update(updates);
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
    } catch (e) {
      debugPrint('[GameService] _resolveRoundOnTimeout error: $e');
    }
  }

  /// Submit an answer — uses a transaction to prevent double-submits
  /// and dot-path updates to avoid array overwrites.
  Future<void> submitAnswer(int answerIndex) async {
    if (_submittingAnswer) return;
    _submittingAnswer = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final match = _currentMatch;
      if (match == null || match.isFinished) return;

      final matchRef = FirebaseFirestore.instance.collection('matches').doc(match.id);
      final isPlayer1 = user.uid == match.player1Id;

      // Use a transaction to atomically check freshness and submit
      final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshDoc = await transaction.get(matchRef);
        if (!freshDoc.exists) return false;
        final freshData = freshDoc.data()!;
        if (freshData['status'] == 'completed') return false;

        final currentRound = freshData['currentRound'] ?? 0;
        final roundIndex = currentRound - 1;
        if (roundIndex < 0) return false;

        final roundsData = freshData['rounds'];
        dynamic roundMap;
        if (roundsData is Map<String, dynamic>) {
          roundMap = roundsData['$roundIndex'];
        } else if (roundsData is List && roundIndex < roundsData.length) {
          roundMap = roundsData[roundIndex];
        }
        if (roundMap == null) return false;

        // Check not already answered
        final existingAnswer = isPlayer1 ? roundMap['player1Answer'] : roundMap['player2Answer'];
        if (existingAnswer != null) return false;

        final correctIndex = roundMap['correctIndex'] ?? 0;
        final isCorrect = answerIndex == correctIndex;
        final now = DateTime.now();

        // Compute answer time
        int timeMs = 0;
        if (_roundStartTime != null) {
          timeMs = DateTime.now().difference(_roundStartTime!).inMilliseconds.clamp(0, 20000);
        } else {
          final createdAt = (freshData['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null) {
            timeMs = DateTime.now().difference(createdAt).inMilliseconds.clamp(0, 20000);
          }
        }

        final answer = {
          'answerIndex': answerIndex,
          'timeMs': timeMs,
          'isCorrect': isCorrect,
          'answeredAt': Timestamp.fromDate(now),
        };

        final fieldPath = isPlayer1
            ? 'rounds.$roundIndex.player1Answer'
            : 'rounds.$roundIndex.player2Answer';

        transaction.update(matchRef, {fieldPath: answer});
        return true;
      });

      if (result == true) {
        // Re-read after write to get updated state
        final afterDoc = await matchRef.get();
        if (afterDoc.exists) {
          _currentMatch = Match.fromFirestore(afterDoc);
          await _resolveRoundIfReady();
        }
      }
    } catch (e) {
      debugPrint('[GameService] submitAnswer error: $e');
    } finally {
      _submittingAnswer = false;
    }
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
        final freshRoundsData = freshData['rounds'];
        dynamic freshRoundData;
        if (freshRoundsData is List<dynamic>) {
          freshRoundData = freshRoundsData[roundIndex];
        } else if (freshRoundsData is Map<String, dynamic>) {
          freshRoundData = freshRoundsData['$roundIndex'];
        }
        if (freshRoundData == null || freshRoundData['resolved'] == true) {
          return;
        }

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
    } catch (e) {
      debugPrint('[GameService] _resolveRoundIfReady error: $e');
    } finally {
      _resolving = false;
    }
  }

  /// Calculate ELO rating change based on opponent difference.
  /// K-factor of 32 is standard for online games.
  int _calculateRatingChange({
    required int myRating,
    required int oppRating,
    required bool won,
    required bool drew,
    required int streak,
  }) {
    const int kFactor = 32;

    // Expected score using ELO formula
    final double expectedScore =
        1.0 / (1.0 + pow(10, (oppRating - myRating) / 400.0));

    // Actual score: 1.0 = win, 0.5 = draw, 0.0 = loss
    final double actualScore = won ? 1.0 : (drew ? 0.5 : 0.0);

    // Base ELO change
    int change = (kFactor * (actualScore - expectedScore)).round();

    // Streak bonus: +2 per consecutive win (max +10), -2 per consecutive loss (max -10)
    if (won && streak > 0) {
      change += (streak * 2).clamp(0, 10);
    } else if (!won && !drew && streak > 0) {
      // Loss after streak — no extra penalty beyond ELO
    }

    // Minimum change of 1 for wins, maximum loss of -50
    if (won) {
      change = change.clamp(1, 50);
    } else if (drew) {
      change = change.clamp(-10, 10);
    } else {
      change = change.clamp(-50, -1);
    }

    return change;
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

    // Fetch my player doc for current rating and streak
    final myDoc = await FirebaseFirestore.instance
        .collection('players')
        .doc(user.uid)
        .get();
    if (!myDoc.exists) return;
    final myData = myDoc.data()!;
    final myRating = myData['rating'] ?? 1000;
    final currentStreak = myData['streak'] ?? 0;

    // Fetch opponent's rating for ELO calculation
    final oppId = isPlayer1 ? match.player2Id : match.player1Id;
    int oppRating = 1000; // default
    if (oppId.isNotEmpty) {
      final oppDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(oppId)
          .get();
      if (oppDoc.exists) {
        oppRating = (oppDoc.data()?['rating'] ?? 1000) as int;
      }
    }

    final int newStreak = won ? currentStreak + 1 : 0;
    int bestStreak = myData['bestStreak'] ?? 0;
    if (newStreak > bestStreak) bestStreak = newStreak;

    final int ratingChange = _calculateRatingChange(
      myRating: myRating,
      oppRating: oppRating,
      won: won,
      drew: drew,
      streak: currentStreak,
    );

    final int newRating = (myRating + ratingChange).clamp(100, 9999);

    await FirebaseFirestore.instance
        .collection('players')
        .doc(user.uid)
        .update({
      'wins': (myData['wins'] ?? 0) + (won ? 1 : 0),
      'losses': (myData['losses'] ?? 0) + (!won && !drew ? 1 : 0),
      'draws': (myData['draws'] ?? 0) + (drew ? 1 : 0),
      'streak': newStreak,
      'bestStreak': bestStreak,
      'rating': newRating,
      'totalMatches': (myData['totalMatches'] ?? 0) + 1,
    });
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
  final service = GameService(ref);
  ref.onDispose(() => service.dispose());
  return service;
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

    final numQuestions = prefs.totalRounds;
    final questions = await _triviaService.fetchRandomQuestions(
      numQuestions,
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
      'totalRounds': numQuestions,
      'status': 'waiting',
      'roomCode': code,
      'isPrivate': true,
      'categoryId': prefs.categoryId,
      'categoryName': prefs.categoryName,
      'difficulty': prefs.difficulty,
      'rounds': {
        for (int i = 0; i < questions.length; i++)
          '$i': {
            'questionId': questions[i].id,
            'questionText': questions[i].text,
            'options': questions[i].options,
            'correctIndex': questions[i].correctIndex,
            'category': questions[i].category,
            'player1Answer': null,
            'player2Answer': null,
            'resolved': false,
          },
      },
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
