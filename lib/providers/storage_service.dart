import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _boxName = 'auth_storage';
  static const String _rememberMeKey = 'remember_me';
  static const String _emailKey = 'saved_email';
  static const String _passwordKey = 'saved_password';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  bool get rememberMe => _box.get(_rememberMeKey, defaultValue: false);
  String get savedEmail => _box.get(_emailKey, defaultValue: '');
  String get savedPassword => _box.get(_passwordKey, defaultValue: '');

  Future<void> setRememberMe(bool value) async {
    await _box.put(_rememberMeKey, value);
  }

  Future<void> saveCredentials(String email, String password) async {
    await _box.put(_emailKey, email);
    await _box.put(_passwordKey, password);
  }

  Future<void> clearCredentials() async {
    await _box.put(_emailKey, '');
    await _box.put(_passwordKey, '');
    await _box.put(_rememberMeKey, false);
  }
}