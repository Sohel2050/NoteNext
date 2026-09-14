import 'package:isar_community/isar.dart';

part 'settings_model.g.dart';

enum AppThemeMode { light, dark, system }

@collection
class SettingsModel {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  AppThemeMode themeMode = AppThemeMode.system;

  /// Material You dynamic color চালু কিনা
  bool useDynamicColor = true;

  /// সিড কালার (dynamic color না থাকলে ব্যবহৃত হবে)
  String seedColorHex = '#7F77DD';

  bool isPinLockEnabled = false;
  String? pinHash;

  bool isBiometricEnabled = false;

  bool isAutoBackupEnabled = false;
  DateTime? lastBackupAt;

  /// Firebase Google সাইন-ইন সিঙ্ক (AppConfig.enableFirebaseSync = true
  /// থাকলেই settings_screen.dart / sync_service.dart এগুলো ব্যবহার করে)
  bool isFirebaseSyncEnabled = false;
  String? firebaseUserId;
  DateTime? lastSyncAt;

  /// ডিফল্ট নোট ভিউ: grid বা list
  String defaultNoteView = 'grid';

  /// ডিফল্ট টাস্ক সর্ট
  String defaultTaskSort = 'dueDate';

  SettingsModel();
}
