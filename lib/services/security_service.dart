import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

/// PIN হ্যাশিং ও বায়োমেট্রিক অথেন্টিকেশন ম্যানেজ করে।
/// PIN কখনো প্লেইন টেক্সটে সংরক্ষিত হয় না — শুধু SHA-256 হ্যাশ
/// (settings_model.dart এর pinHash ফিল্ডে) সেভ থাকে।
class SecurityService {
  SecurityService._internal();
  static final SecurityService instance = SecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// অ্যাপ-নির্দিষ্ট সল্ট — শুধু ডিকশনারি/রেইনবো-টেবিল অ্যাটাক কিছুটা কঠিন করার জন্য।
  /// (সত্যিকারের প্রোডাকশন সিকিউরিটির জন্য per-install random salt ভালো,
  /// কিন্তু ৪-৬ ডিজিটের PIN-এর জন্য এটি যথেষ্ট সরল ও কার্যকর।)
  static const String _salt = 'mi_notes_app_salt_v1';

  String hashPin(String pin) {
    final bytes = utf8.encode('$_salt::$pin');
    return sha256.convert(bytes).toString();
  }

  bool verifyPin(String pin, String storedHash) {
    return hashPin(pin) == storedHash;
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'অ্যাপ আনলক করতে যাচাই করুন',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } catch (_) {
      return false;
    }
  }
}
