import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../models/player.dart';
import 'auth_provider.dart';

final currentPlayerProvider = StreamProvider<Player?>((ref) {
  // Watch auth state so this provider rebuilds when the user changes
  final authState = ref.watch(authStateProvider);
  return authState.when(
    loading: () => Stream.value(null),
    error: (_, e) => Stream.value(null),
    data: (user) {
      if (user == null) return Stream.value(null);

      return FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        if (doc.exists) {
          return Player.fromFirestore(doc);
        }
        return null;
      });
    },
  );
});

final leaderboardProvider = StreamProvider<List<Player>>((ref) {
  return FirebaseFirestore.instance
      .collection('players')
      .orderBy('rating', descending: true)
      .limit(500)
      .snapshots()
      .map((snapshot) {
    // Only show signed-in players with at least 1 match
    // Exclude anonymous/guest accounts AND any player without
    // an explicit isAnonymous:false (safety catch for legacy docs)
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final totalMatches = data['totalMatches'] ?? 0;
      final isAnonymous = data['isAnonymous'] == true;
      final hasEmail = data['email'] != null &&
          (data['email'] as String).isNotEmpty;
      // Must have: played a game, NOT anonymous, AND has a real email
      return totalMatches > 0 && !isAnonymous && hasEmail;
    }).map((doc) => Player.fromFirestore(doc)).toList();
  });
});

final playerStatsProvider = FutureProvider<PlayerStats?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('players')
      .doc(user.uid)
      .get();

  if (doc.exists) {
    return PlayerStats.fromFirestore(doc);
  }
  return null;
});

class PlayerService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<Player> getOrCreatePlayer() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final doc = await _firestore.collection('players').doc(user.uid).get();
    if (doc.exists) {
      return Player.fromFirestore(doc);
    }

    final player = Player(
      uid: user.uid,
      displayName: user.isAnonymous
          ? 'Guest'
          : (user.displayName?.isNotEmpty == true
              ? user.displayName!
              : user.email?.split('@').first ?? 'Player'),
      email: user.email,
      isAnonymous: user.isAnonymous,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
    );

    await _firestore.collection('players').doc(user.uid).set(player.toFirestore());
    return player;
  }

  Future<void> updateLastSeen() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('players').doc(user.uid).update({
      'lastSeen': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateStats({
    required bool won,
    required bool drew,
    required int ratingChange,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('players').doc(user.uid).get();
    if (!doc.exists) return;

    final stats = PlayerStats.fromFirestore(doc);
    int newStreak = won ? stats.streak + 1 : 0;
    int newBestStreak = newStreak > stats.bestStreak ? newStreak : stats.bestStreak;

    await _firestore.collection('players').doc(user.uid).update({
      'wins': won ? stats.wins + 1 : stats.wins,
      'losses': (!won && !drew) ? stats.losses + 1 : stats.losses,
      'draws': drew ? stats.draws + 1 : stats.draws,
      'streak': newStreak,
      'bestStreak': newBestStreak,
      'rating': stats.rating + ratingChange,
      'totalMatches': stats.totalMatches + 1,
    });
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('players').doc(user.uid).update({
      'displayName': name,
    });
  }
}

final playerServiceProvider = Provider<PlayerService>((ref) {
  return PlayerService();
});

final matchHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  // Watch auth state so this provider rebuilds when the user changes
  final authState = ref.watch(authStateProvider);
  return authState.when(
    loading: () => Stream.value([]),
    error: (_, e) => Stream.value([]),
    data: (user) {
      if (user == null) return Stream.value([]);

      // Query matches where user is player1 (no orderBy to avoid composite index)
      final p1Stream = FirebaseFirestore.instance
          .collection('matches')
          .where('player1Id', isEqualTo: user.uid)
          .snapshots();

      // Query matches where user is player2 (no orderBy to avoid composite index)
      final p2Stream = FirebaseFirestore.instance
          .collection('matches')
          .where('player2Id', isEqualTo: user.uid)
          .snapshots();

  return Rx.combineLatest2(p1Stream, p2Stream, (QuerySnapshot a, QuerySnapshot b) {
    final allMatches = <Map<String, dynamic>>[];

    for (final doc in a.docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Only include completed matches in history
      if (data['status'] != 'completed') continue;
      allMatches.add({
        'id': doc.id,
        'isPlayer1': true,
        ...data,
      });
    }

    for (final doc in b.docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Only include completed matches in history
      if (data['status'] != 'completed') continue;
      allMatches.add({
        'id': doc.id,
        'isPlayer1': false,
        ...data,
      });
    }

    // Sort client-side by createdAt descending
    allMatches.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return allMatches.take(20).toList();
      });
    },
  );
});
