/// অ্যাপের গ্লোবাল কনফিগারেশন ফ্ল্যাগ।
///
/// এই ফাইলের মান পরিবর্তন করে পুরো অ্যাপে একসাথে ফিচার চালু/বন্ধ করা যায়।
class AppConfig {
  AppConfig._();

  /// Firebase Sync + Google Sign-in ফিচারের মাস্টার সুইচ।
  ///
  /// **বর্তমান অবস্থা: বন্ধ (false)** — অ্যাপ সম্পূর্ণ অফলাইনে চলে।
  /// Isar লোকাল ডাটাবেস + লোকাল JSON Backup/Restore দিয়ে সব ডেটা ডিভাইসেই
  /// থাকে, কোনো ইন্টারনেট লাগে না।
  ///
  /// সব Firebase-সংক্রান্ত কোড (auth_service.dart, sync_service.dart,
  /// auth_provider.dart) ও pubspec.yaml-এর প্যাকেজগুলো **আগে থেকেই প্রজেক্টে
  /// আছে** — এই ফ্ল্যাগ দিয়েই সব জায়গায় on/off নিয়ন্ত্রিত হয় (main.dart এ
  /// Firebase.initializeApp() কল, settings_screen.dart এ অ্যাকাউন্ট/সিঙ্ক UI)।
  /// তাই ভবিষ্যতে এই ফ্ল্যাগ শুধু `true` করলেই যথেষ্ট — **কোনো Dart কোড
  /// পরিবর্তনের দরকার নেই।**
  ///
  /// চালু করার জন্য যা করতে হবে (এগুলো কোড পরিবর্তন নয়, external setup):
  ///   1. [Firebase Console](https://console.firebase.google.com) এ একটা
  ///      প্রজেক্ট তৈরি করুন, Authentication (Google প্রোভাইডার), Firestore,
  ///      Storage চালু করুন
  ///   2. `dart pub global activate flutterfire_cli` তারপর প্রজেক্ট রুটে
  ///      `flutterfire configure` চালান — এটা lib/firebase_options.dart এর
  ///      placeholder মানগুলো আসল মান দিয়ে স্বয়ংক্রিয়ভাবে প্রতিস্থাপন করবে
  ///      এবং android/ios এ google-services.json / GoogleService-Info.plist
  ///      যোগ করবে
  ///   3. এই ফ্ল্যাগটা `true` করুন
  ///
  /// এই ৩ ধাপের পর `flutter run` করলেই Google Sign-in, Firestore/Storage
  /// সিঙ্ক, এবং Settings-এ "অ্যাকাউন্ট"/"ক্লাউড সিঙ্ক" সেকশন কাজ করবে —
  /// কোনো অতিরিক্ত কোডিং ছাড়াই।
  static const bool enableFirebaseSync = false;

  // ==========================================================================
  // Ads (Unity LevelPlay mediation)
  // ==========================================================================

  /// Ads মাস্টার সুইচ। Premium (RevenueCat) ইউজারদের জন্য এটা runtime-এ
  /// AdService স্বয়ংক্রিয়ভাবে false ধরে নেয় — এখানে শুধু গ্লোবাল on/off।
  static const bool enableAds = true;

  /// LevelPlay ড্যাশবোর্ড থেকে পাওয়া App Key। প্লেসহোল্ডার — আসল কী বসাতে হবে।
  static const String levelPlayAppKey = 'YOUR_LEVELPLAY_APP_KEY';

  /// LevelPlay ড্যাশবোর্ডে তৈরি করা Ad Unit ID গুলো।
  static const String bannerAdUnitId = 'YOUR_BANNER_AD_UNIT_ID';
  static const String interstitialAdUnitId = 'YOUR_INTERSTITIAL_AD_UNIT_ID';

  /// কতগুলো নোট/টাস্ক সেভ হলে একটা ইন্টারস্টিশিয়াল ট্রিগার হবে।
  static const int interstitialSaveThreshold = 3;

  /// একটা ইন্টারস্টিশিয়াল দেখানোর পর পরেরটার আগে কমপক্ষে এই কুলডাউন
  /// (মিনিটে) পার হতে হবে।
  static const int interstitialCooldownMinutes = 60;

  // ==========================================================================
  // In-App Purchases (RevenueCat — purchases_flutter)
  // ==========================================================================

  /// Play Console-এ তৈরি করা Subscription Product ID গুলো (Base Plan সহ)।
  /// প্লেসহোল্ডার — আপনার Play Console-এ যা বসিয়েছেন সেটা এখানে দিন।
  static const String monthlySubscriptionProductId = 'premium_monthly';
  static const String yearlySubscriptionProductId = 'premium_yearly';
}
