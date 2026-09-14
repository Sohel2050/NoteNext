import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/auth_service.dart';

/// বর্তমান Firebase User এর রিয়েলটাইম স্ট্রিম (null মানে সাইন-আউট অবস্থা)
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.instance.authStateChanges;
});
