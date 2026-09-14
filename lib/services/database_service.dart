import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/note_model.dart';
import '../models/task_model.dart';
import '../models/settings_model.dart';

/// Isar ডাটাবেসের সিঙ্গলটন সার্ভিস।
/// অ্যাপ শুরুতে [DatabaseService.init] একবার কল করতে হবে (main.dart এ)।
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  late Isar _isar;
  Isar get isar => _isar;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [
        NoteModelSchema,
        TaskModelSchema,
        SettingsModelSchema,
      ],
      directory: dir.path,
      inspector: true,
    );

    // প্রথমবার চালু হলে ডিফল্ট সেটিংস তৈরি করা
    final settingsCount = await _isar.settingsModels.count();
    if (settingsCount == 0) {
      await _isar.writeTxn(() async {
        await _isar.settingsModels.put(SettingsModel());
      });
    }

    _initialized = true;
  }

  /// সেটিংস দ্রুত পাওয়ার হেল্পার (সবসময় একটাই রেকর্ড থাকবে, id=1)
  Future<SettingsModel> getSettings() async {
    final settings = await _isar.settingsModels.where().findFirst();
    return settings ?? SettingsModel();
  }

  Future<void> saveSettings(SettingsModel settings) async {
    await _isar.writeTxn(() async {
      await _isar.settingsModels.put(settings);
    });
  }

  Future<void> close() async {
    await _isar.close();
    _initialized = false;
  }
}
