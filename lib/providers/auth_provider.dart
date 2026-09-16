import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authProvider = Provider<AuthService>((ref) {
  final storageService = ref.read(storageServiceProvider);
  return AuthService(storageService);
});

class AuthService {
  final _auth = FirebaseAuth.instance;
  final StorageService _storageService;

  AuthService(this._storageService);

  User? get currentUser => _auth.currentUser;

  bool get rememberMe => _storageService.rememberMe;
  String get savedEmail => _storageService.savedEmail;
  String get savedPassword => _storageService.savedPassword;

  Future<UserCredential> signInWithEmail(String email, String password, {bool rememberMe = false}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (rememberMe) {
      await _storageService.setRememberMe(true);
      await _storageService.saveCredentials(email, password);
    } else {
      await _storageService.clearCredentials();
    }
    return credential;
  }

  Future<UserCredential> signUpWithEmail(String email, String password, {String? displayName}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Update display name on Firebase Auth
    if (displayName != null && displayName.isNotEmpty) {
      await credential.user?.updateDisplayName(displayName);
    }
    return credential;
  }

  Future<void> signOut() async {
    await _storageService.clearCredentials();
    await _auth.signOut();
    // Re-sign in anonymously after sign out
    await _auth.signInAnonymously();
  }

  Future<void> deleteAccount() async {
    await _storageService.clearCredentials();
    await _auth.currentUser?.delete();
    await _auth.signInAnonymously();
  }

  Future<void> linkWithCredentials(String email, String password) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await _auth.currentUser?.linkWithCredential(credential);
  }
}
