// ⚠️ এটি একটি PLACEHOLDER ফাইল।
//
// AppConfig.enableFirebaseSync = true করার আগে অবশ্যই এই ফাইলটা আসল মান
// দিয়ে regenerate করতে হবে, নাহলে সাইন-ইন/সিঙ্ক কাজ করবে না (তবে অ্যাপ
// ক্র্যাশ করবে না — নিচের placeholder মান দিয়েও কম্পাইল হয়)।
//
// আসল Firebase প্রজেক্টের সাথে কানেক্ট করতে:
//   1. https://console.firebase.google.com এ একটা প্রজেক্ট তৈরি করুন
//   2. `dart pub global activate flutterfire_cli` চালান
//   3. প্রজেক্ট রুটে `flutterfire configure` চালান
//   4. এটি এই ফাইলটি (lib/firebase_options.dart) সঠিক মান দিয়ে
//      স্বয়ংক্রিয়ভাবে regenerate করবে, এবং android/ios এ প্রয়োজনীয়
//      google-services.json / GoogleService-Info.plist ফাইলও যোগ করবে
//   5. lib/config/app_config.dart এ enableFirebaseSync = true করুন
//
// এই ৫টা ধাপের বাইরে আর কোনো Dart কোড পরিবর্তনের দরকার নেই — বাকি সব
// (auth_service.dart, sync_service.dart, settings UI) আগে থেকেই লেখা আছে
// এবং AppConfig ফ্ল্যাগ দেখেই on/off হয়।

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions যেভাবে সেট আছে তাতে ওয়েব সাপোর্ট নেই। '
        '`flutterfire configure` চালিয়ে regenerate করুন।',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions এই প্ল্যাটফর্মের জন্য কনফিগার করা হয়নি।',
        );
    }
  }

  // ⚠️ নিচের সব মান placeholder — `flutterfire configure` চালানোর পর
  // এগুলো আসল প্রজেক্টের মান দিয়ে প্রতিস্থাপিত হবে।
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_API_KEY',
    appId: 'REPLACE_WITH_YOUR_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_API_KEY',
    appId: 'REPLACE_WITH_YOUR_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.miNotesApp',
  );
}
