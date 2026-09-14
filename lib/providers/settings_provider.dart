import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/settings_model.dart';
import '../services/database_service.dart';

/// অ্যাপের বর্তমান সেটিংস ধরে রাখে এবং পরিবর্তন হলে ডাটাবেসে সেভ করে।
class SettingsNotifier extends StateNotifier<SettingsModel> {
  SettingsNotifier() : super(SettingsModel()) {
    _load();
  }

  Future<void> _load() async {
    final settings = await DatabaseService.instance.getSettings();
    state = settings;
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    state = _copyWith(themeMode: mode);
    await DatabaseService.instance.saveSettings(state);
  }

  Future<void> updateSeedColor(String hex) async {
    state = _copyWith(seedColorHex: hex);
    await DatabaseService.instance.saveSettings(state);
  }

  Future<void> updatePinLock(bool enabled, {String? pinHash}) async {
    state = _copyWith(isPinLockEnabled: enabled, pinHash: pinHash);
    await DatabaseService.instance.saveSettings(state);
  }

  /// PIN বন্ধ করার সময় pinHash স্থায়ীভাবে মুছে দেয় (_copyWith এর ??
  /// প্যাটার্নে null পাঠালে পুরনো হ্যাশ থেকে যেত বলে এই আলাদা মেথড)
  Future<void> clearPin() async {
    final updated = SettingsModel()
      ..id = state.id
      ..themeMode = state.themeMode
      ..useDynamicColor = state.useDynamicColor
      ..seedColorHex = state.seedColorHex
      ..isPinLockEnabled = false
      ..pinHash = null
      ..isBiometricEnabled = false
      ..isAutoBackupEnabled = state.isAutoBackupEnabled
      ..lastBackupAt = state.lastBackupAt
      ..isFirebaseSyncEnabled = state.isFirebaseSyncEnabled
      ..firebaseUserId = state.firebaseUserId
      ..lastSyncAt = state.lastSyncAt
      ..defaultNoteView = state.defaultNoteView
      ..defaultTaskSort = state.defaultTaskSort;
    state = updated;
    await DatabaseService.instance.saveSettings(state);
  }

  Future<void> updateBiometric(bool enabled) async {
    state = _copyWith(isBiometricEnabled: enabled);
    await DatabaseService.instance.saveSettings(state);
  }

  Future<void> updateDefaultNoteView(String view) async {
    state = _copyWith(defaultNoteView: view);
    await DatabaseService.instance.saveSettings(state);
  }

  Future<void> updateAutoBackup(bool enabled) async {
    state = _copyWith(isAutoBackupEnabled: enabled);
    await DatabaseService.instance.saveSettings(state);
  }

  Future<void> markSyncCompleted() async {
    state = _copyWith(
      isFirebaseSyncEnabled: true,
      lastSyncAt: DateTime.now(),
    );
    await DatabaseService.instance.saveSettings(state);
  }

  SettingsModel _copyWith({
    AppThemeMode? themeMode,
    bool? useDynamicColor,
    String? seedColorHex,
    bool? isPinLockEnabled,
    String? pinHash,
    bool? isBiometricEnabled,
    bool? isAutoBackupEnabled,
    bool? isFirebaseSyncEnabled,
    DateTime? lastSyncAt,
    String? defaultNoteView,
    String? defaultTaskSort,
  }) {
    return SettingsModel()
      ..id = state.id
      ..themeMode = themeMode ?? state.themeMode
      ..useDynamicColor = useDynamicColor ?? state.useDynamicColor
      ..seedColorHex = seedColorHex ?? state.seedColorHex
      ..isPinLockEnabled = isPinLockEnabled ?? state.isPinLockEnabled
      ..pinHash = pinHash ?? state.pinHash
      ..isBiometricEnabled = isBiometricEnabled ?? state.isBiometricEnabled
      ..isAutoBackupEnabled = isAutoBackupEnabled ?? state.isAutoBackupEnabled
      ..lastBackupAt = state.lastBackupAt
      ..isFirebaseSyncEnabled =
          isFirebaseSyncEnabled ?? state.isFirebaseSyncEnabled
      ..firebaseUserId = state.firebaseUserId
      ..lastSyncAt = lastSyncAt ?? state.lastSyncAt
      ..defaultNoteView = defaultNoteView ?? state.defaultNoteView
      ..defaultTaskSort = defaultTaskSort ?? state.defaultTaskSort;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>(
  (ref) => SettingsNotifier(),
);
