import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../models/player.dart';

final currentPlayerProvider = StreamProvider<Player?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
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
});

final leaderboardProvider = StreamProvider<List<Player>>((ref) {
  return FirebaseFirestore.instance
      .collection('players')
      .orderBy('rating', descending: true)
      .limit(200)
      .snapshots()
      .map((snapshot) {
    // Filter out anonymous/guest users — only show signed-in players
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final isAnonymous = data['isAnonymous'] == true;
      final isGuest = data['displayName'] == 'Guest';
      final hasEmail = data['email'] != null && (data['email'] as String).isNotEmpty;
      // Include only if: not anonymous AND not guest AND has an email
      return !isAnonymous && !isGuest && hasEmail;
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
      displayName: user.email?.split('@').first ?? 'Guest',
      email: user.email,
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
  final user = FirebaseAuth.instance.currentUser;
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
      allMatches.add({
        'id': doc.id,
        'isPlayer1': true,
        ...doc.data() as Map<String, dynamic>,
      });
    }

    for (final doc in b.docs) {
      allMatches.add({
        'id': doc.id,
        'isPlayer1': false,
        ...doc.data() as Map<String, dynamic>,
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
});
