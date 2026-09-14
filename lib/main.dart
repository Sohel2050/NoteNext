import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'models/settings_model.dart';
import 'providers/settings_provider.dart';
import 'screens/app_lock_gate.dart';
import 'services/ad_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Isar ডাটাবেস ইনিশিয়ালাইজ করা
  await DatabaseService.instance.init();

  // রিমাইন্ডার নোটিফিকেশন ইনিশিয়ালাইজ করা
  await NotificationService.instance.init();

  // Firebase Sync — শুধু AppConfig.enableFirebaseSync = true থাকলেই
  // ইনিশিয়ালাইজ করার চেষ্টা হয়। false থাকলে এই ব্লক সম্পূর্ণ স্কিপ হয়ে যায়
  // এবং অ্যাপ সম্পূর্ণ অফলাইন মোডে চলে। true করার আগে অবশ্যই
  // `flutterfire configure` চালিয়ে lib/firebase_options.dart এ আসল মান
  // বসাতে হবে (lib/config/app_config.dart এ বিস্তারিত নির্দেশনা আছে) —
  // এটা করা হয়ে গেলে flag flip করার পর আর কোনো কোড পরিবর্তন লাগবে না।
  if (AppConfig.enableFirebaseSync) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init failed (firebase_options.dart placeholder?): $e');
    }
  }

  // Purchase status আগে ইনিশিয়ালাইজ করা হয় যাতে premium স্ট্যাটাস জানা
  // থাকে — তারপর AdService সেই অনুযায়ী Ads দেখাবে/লুকাবে।
  await PurchaseService.instance.initialize();
  await AdService.instance.initialize();

  runApp(const ProviderScope(child: MiNotesApp()));
}

class MiNotesApp extends ConsumerWidget {
  const MiNotesApp({super.key});

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final seedColor = _hexToColor(settings.seedColorHex);

    ThemeMode themeMode;
    switch (settings.themeMode) {
      case AppThemeMode.light:
        themeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        themeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        themeMode = ThemeMode.system;
        break;
    }

    return MaterialApp(
      title: 'Mi Notes',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(seedColor: seedColor),
      darkTheme: AppTheme.dark(seedColor: seedColor),
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('bn'),
      ],
      home: const AppLockGate(),
    );
  }
}
