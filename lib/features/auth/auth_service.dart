import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  static const String _boxName = "userBox";
  static const String _keyIsLoggedIn = "isLoggedIn";
  static const String _keyCurrentUser = "currentUser";
  static const String _keyUserMap = "registeredUsers";

  /// Generates a salted HMAC-SHA256 hash for the given password.
  static String _hashPassword(String password, List<int> salt) {
    final hmac = Hmac(sha256, salt);
    final digest = hmac.convert(utf8.encode(password));
    return base64.encode(digest.bytes);
  }

  static Future<void> registerUser(String email, String password) async {
    final box = Hive.box(_boxName);
    final raw = box.get(_keyUserMap, defaultValue: {});
    final users = Map<String, String>.from(raw);

    if (users.containsKey(email)) {
      throw "User already exists.";
    }

    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final hash = _hashPassword(password, salt);
    // Store as base64(salt):base64(hash)
    users[email] = "${base64.encode(salt)}:$hash";
    await box.put(_keyUserMap, users);
  }

  /// Verifies credentials (new HMAC format or legacy plaintext).
  /// Auto-upgrades legacy entries on successful match.
  static Future<bool> verifyCredentials(String email, String password) async {
    final box = Hive.box(_boxName);
    final raw = box.get(_keyUserMap, defaultValue: {});
    final users = Map<String, String>.from(raw);

    if (!users.containsKey(email)) return false;

    final stored = users[email]!;
    final parts = stored.split(':');

    // New format: base64salt:base64hash
    if (parts.length == 2) {
      try {
        final salt = base64.decode(parts[0]);
        return parts[1] == _hashPassword(password, salt);
      } catch (_) {
        return false;
      }
    }

    // Legacy plaintext — compare directly and upgrade
    if (stored == password) {
      final rng = Random.secure();
      final salt = List<int>.generate(16, (_) => rng.nextInt(256));
      final hash = _hashPassword(password, salt);
      users[email] = "${base64.encode(salt)}:$hash";
      await box.put(_keyUserMap, users);
      return true;
    }

    return false;
  }

  static Future<void> saveSession(String email) async {
    final box = Hive.box(_boxName);
    await box.put(_keyCurrentUser, email);
    await box.put(_keyIsLoggedIn, true);
  }

  // ─── Fingerprint helpers ───

  static const String _keyFingerprintUser = "fingerprintUser";

  static Future<void> enableFingerprint(String email) async {
    final box = Hive.box(_boxName);
    await box.put(_keyFingerprintUser, email);
  }

  static Future<String?> getFingerprintUser() async {
    final box = Hive.box(_boxName);
    return box.get(_keyFingerprintUser) as String?;
  }

  static Future<void> disableFingerprint() async {
    final box = Hive.box(_boxName);
    await box.delete(_keyFingerprintUser);
  }
}
