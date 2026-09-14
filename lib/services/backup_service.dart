import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:isar_community/isar.dart';

import '../models/note_model.dart';
import '../models/task_model.dart';
import 'database_service.dart';

/// স্থানীয় JSON ব্যাকআপ/রিস্টোর সার্ভিস — সম্পূর্ণ অফলাইনে কাজ করে,
/// কোনো ইন্টারনেট/ক্লাউড অ্যাকাউন্ট প্রয়োজন হয় না। ব্যবহারকারী ব্যাকআপ
/// ফাইল ম্যানুয়ালি শেয়ার/সেভ করে অন্য ডিভাইসে রিস্টোর করতে পারবে।
class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  static const int backupVersion = 1;

  Map<String, dynamic> _noteToJson(NoteModel n) => {
        'uuid': n.uuid,
        'title': n.title,
        'contentDelta': n.contentDelta,
        'plainText': n.plainText,
        'type': n.type.name,
        'checklistJson': n.checklistJson,
        'drawingJson': n.drawingJson,
        'voiceNotePaths': n.voiceNotePaths,
        'imagePaths': n.imagePaths,
        'reminderTime': n.reminderTime?.toIso8601String(),
        'isPinned': n.isPinned,
        'isArchived': n.isArchived,
        'isTrashed': n.isTrashed,
        'trashedAt': n.trashedAt?.toIso8601String(),
        'colorHex': n.colorHex,
        'tags': n.tags,
        'isLocked': n.isLocked,
        'createdAt': n.createdAt.toIso8601String(),
        'updatedAt': n.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> _taskToJson(TaskModel t) => {
        'uuid': t.uuid,
        'title': t.title,
        'description': t.description,
        'isCompleted': t.isCompleted,
        'completedAt': t.completedAt?.toIso8601String(),
        'dueDate': t.dueDate?.toIso8601String(),
        'hasReminder': t.hasReminder,
        'reminderTime': t.reminderTime?.toIso8601String(),
        'priority': t.priority.name,
        'repeatType': t.repeatType.name,
        'repeatInterval': t.repeatInterval,
        'subtasks': t.subtasks
            .map((s) => {
                  'id': s.id,
                  'title': s.title,
                  'isCompleted': s.isCompleted,
                  'order': s.order,
                })
            .toList(),
        'tags': t.tags,
        'colorHex': t.colorHex,
        'isPinned': t.isPinned,
        'isArchived': t.isArchived,
        'isTrashed': t.isTrashed,
        'trashedAt': t.trashedAt?.toIso8601String(),
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
      };

  /// সম্পূর্ণ ডাটাবেস (notes + tasks) একটা JSON ফাইলে এক্সপোর্ট করে path রিটার্ন করে।
  /// দ্রষ্টব্য: ছবি/ভয়েস ফাইল নিজেরা ব্যাকআপে যুক্ত হয় না (শুধু path রেফারেন্স),
  /// তাই সম্পূর্ণ ডিভাইস মাইগ্রেশনের জন্য ব্যাকআপ ফাইলের পাশাপাশি
  /// note_images/ ও voice_notes/ ফোল্ডারও ম্যানুয়ালি কপি করতে হবে।
  Future<File> exportBackup() async {
    final isar = DatabaseService.instance.isar;
    final notes = await DatabaseService.instance.isar.noteModels.where().findAll();
    final tasks = await DatabaseService.instance.isar.taskModels.where().findAll();

    final backup = {
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': notes.map(_noteToJson).toList(),
      'tasks': tasks.map(_taskToJson).toList(),
    };

    final dir = await getTemporaryDirectory();
    final fileName =
        'mi_notes_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonEncode(backup));
    return file;
  }

  Future<void> exportAndShareBackup() async {
    final file = await exportBackup();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Mi Notes Backup'),
    );
  }

  /// ডকুমেন্টস ফোল্ডারে স্থায়ীভাবে ব্যাকআপ সেভ করে (auto-backup এর জন্য)
  Future<File> saveBackupLocally() async {
    final tempFile = await exportBackup();
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${docsDir.path}/backups');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    final destPath = '${backupDir.path}/latest_backup.json';
    return tempFile.copy(destPath);
  }

  /// একটি ব্যাকআপ JSON ফাইল থেকে ডেটা রিস্টোর করে। uuid দিয়ে ম্যাচ করে
  /// বিদ্যমান রেকর্ড থাকলে আপডেট করে, না থাকলে নতুন তৈরি করে (merge, replace নয়)।
  Future<BackupRestoreResult> restoreFromFile(File file) async {
    final content = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(content);

    final isar = DatabaseService.instance.isar;
    int notesRestored = 0;
    int tasksRestored = 0;

    await DatabaseService.instance.isar.writeTxn(() async {
      for (final raw in (data['notes'] as List? ?? [])) {
        final map = raw as Map<String, dynamic>;
        final existing = await DatabaseService.instance.isar.noteModels
            .filter()
            .uuidEqualTo(map['uuid'] as String)
            .findFirst();
        final note = existing ?? NoteModel.create(uuid: map['uuid'], title: '');
        note
          ..title = map['title'] as String? ?? ''
          ..contentDelta = map['contentDelta'] as String?
          ..plainText = map['plainText'] as String? ?? ''
          ..type = NoteType.values.firstWhere(
            (t) => t.name == map['type'],
            orElse: () => NoteType.text,
          )
          ..checklistJson = map['checklistJson'] as String?
          ..drawingJson = map['drawingJson'] as String?
          ..voiceNotePaths =
              (map['voiceNotePaths'] as List?)?.cast<String>() ?? []
          ..imagePaths = (map['imagePaths'] as List?)?.cast<String>() ?? []
          ..reminderTime = map['reminderTime'] != null
              ? DateTime.parse(map['reminderTime'] as String)
              : null
          ..isPinned = map['isPinned'] as bool? ?? false
          ..isArchived = map['isArchived'] as bool? ?? false
          ..isTrashed = map['isTrashed'] as bool? ?? false
          ..trashedAt = map['trashedAt'] != null
              ? DateTime.parse(map['trashedAt'] as String)
              : null
          ..colorHex = map['colorHex'] as String? ?? '#FFFFFF'
          ..tags = (map['tags'] as List?)?.cast<String>() ?? []
          ..isLocked = map['isLocked'] as bool? ?? false
          ..createdAt = DateTime.parse(map['createdAt'] as String)
          ..updatedAt = DateTime.parse(map['updatedAt'] as String);
        await DatabaseService.instance.isar.noteModels.put(note);
        notesRestored++;
      }

      for (final raw in (data['tasks'] as List? ?? [])) {
        final map = raw as Map<String, dynamic>;
        final existing = await DatabaseService.instance.isar.taskModels
            .filter()
            .uuidEqualTo(map['uuid'] as String)
            .findFirst();
        final task = existing ?? TaskModel.create(uuid: map['uuid'], title: '');
        task
          ..title = map['title'] as String? ?? ''
          ..description = map['description'] as String? ?? ''
          ..isCompleted = map['isCompleted'] as bool? ?? false
          ..completedAt = map['completedAt'] != null
              ? DateTime.parse(map['completedAt'] as String)
              : null
          ..dueDate = map['dueDate'] != null
              ? DateTime.parse(map['dueDate'] as String)
              : null
          ..hasReminder = map['hasReminder'] as bool? ?? false
          ..reminderTime = map['reminderTime'] != null
              ? DateTime.parse(map['reminderTime'] as String)
              : null
          ..priority = TaskPriority.values.firstWhere(
            (p) => p.name == map['priority'],
            orElse: () => TaskPriority.medium,
          )
          ..repeatType = RepeatType.values.firstWhere(
            (r) => r.name == map['repeatType'],
            orElse: () => RepeatType.none,
          )
          ..repeatInterval = map['repeatInterval'] as int? ?? 1
          ..subtasks = ((map['subtasks'] as List?) ?? [])
              .map((s) => SubTask()
                ..id = s['id'] as String
                ..title = s['title'] as String? ?? ''
                ..isCompleted = s['isCompleted'] as bool? ?? false
                ..order = s['order'] as int? ?? 0)
              .toList()
          ..tags = (map['tags'] as List?)?.cast<String>() ?? []
          ..colorHex = map['colorHex'] as String? ?? '#FFFFFF'
          ..isPinned = map['isPinned'] as bool? ?? false
          ..isArchived = map['isArchived'] as bool? ?? false
          ..isTrashed = map['isTrashed'] as bool? ?? false
          ..trashedAt = map['trashedAt'] != null
              ? DateTime.parse(map['trashedAt'] as String)
              : null
          ..createdAt = DateTime.parse(map['createdAt'] as String)
          ..updatedAt = DateTime.parse(map['updatedAt'] as String);
        await DatabaseService.instance.isar.taskModels.put(task);
        tasksRestored++;
      }
    });

    return BackupRestoreResult(
      notesRestored: notesRestored,
      tasksRestored: tasksRestored,
    );
  }
}

class BackupRestoreResult {
  final int notesRestored;
  final int tasksRestored;
  const BackupRestoreResult(
      {required this.notesRestored, required this.tasksRestored});
}
