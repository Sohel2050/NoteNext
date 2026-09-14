import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In + Firebase Auth ম্যানেজ করে। শুধুমাত্র
/// AppConfig.enableFirebaseSync = true থাকলেই UI থেকে এই সার্ভিসের
/// মেথডগুলো কল করা হয় (settings_screen.dart দেখুন)।
///
/// google_sign_in ^7.x থেকে API সম্পূর্ণ পাল্টে গেছে — এখন সিঙ্গলটন
/// (`GoogleSignIn.instance`), ব্যবহারের আগে একবার `initialize()` কল
/// বাধ্যতামূলক, এবং authentication (identity) ও authorization
/// (scopes/access token) আলাদা ধাপ।
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  bool get isSignedIn => currentUser != null;

  Future<User?> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } catch (_) {
      return null; // ব্যবহারকারী বাতিল করেছে বা authenticate সাপোর্টেড না
    }

    // identity (idToken) — সিঙ্ক্রোনাসভাবে পাওয়া যায়
    final idToken = googleUser.authentication.idToken;

    // authorization (accessToken) — আলাদা করে scope অনুমোদন নিতে হয়
    final authorization = await googleUser.authorizationClient
        .authorizeScopes(['email', 'profile']);

    final credential = GoogleAuthProvider.credential(
      accessToken: authorization.accessToken,
      idToken: idToken,
    );

    final userCredential =
        await _firebaseAuth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  /// অ্যাকাউন্ট সম্পূর্ণ ডিসকানেক্ট করা (শুধু sign-out নয়, permission-ও revoke হবে)
  Future<void> disconnect() async {
    await _googleSignIn.disconnect();
    await _firebaseAuth.signOut();
  }
}
