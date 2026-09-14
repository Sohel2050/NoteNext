import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar_community/isar.dart';

import '../models/note_model.dart';
import '../models/task_model.dart';
import 'auth_service.dart';
import 'database_service.dart';

typedef SyncProgressCallback = void Function(String message);

/// Firestore-ভিত্তিক দ্বিমুখী (push + pull) সিঙ্ক। কনফ্লিক্ট রেজোলিউশন
/// last-write-wins (updatedAt এর ভিত্তিতে)। ছবি/ভয়েস ফাইল Firebase
/// Storage এ আপলোড হয় এবং অন্য ডিভাইসে ডাউনলোড করে লোকাল পাথে নামানো হয়।
class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _notesCollection {
    if (_uid == null) throw Exception('সাইন-ইন করা নেই');
    return _firestore.collection('users').doc(_uid).collection('notes');
  }

  CollectionReference<Map<String, dynamic>> get _tasksCollection {
    if (_uid == null) throw Exception('সাইন-ইন করা নেই');
    return _firestore.collection('users').doc(_uid).collection('tasks');
  }

  Map<String, dynamic> _noteToMap(NoteModel n) => {
        'uuid': n.uuid,
        'title': n.title,
        'contentDelta': n.contentDelta,
        'plainText': n.plainText,
        'type': n.type.name,
        'checklistJson': n.checklistJson,
        'drawingJson': n.drawingJson,
        'imageStorageUrls': <String>[],
        'voiceStorageUrls': <String>[],
        'reminderTime': n.reminderTime?.toIso8601String(),
        'isPinned': n.isPinned,
        'isArchived': n.isArchived,
        'isTrashed': n.isTrashed,
        'trashedAt': n.trashedAt?.toIso8601String(),
        'colorHex': n.colorHex,
        'tags': n.tags,
        'createdAt': n.createdAt.toIso8601String(),
        'updatedAt': n.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> _taskToMap(TaskModel t) => {
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

  /// লোকাল Isar থেকে সব notes/tasks Firestore এ পুশ করে (আপডেট হওয়াগুলোই)
  Future<void> pushAll({SyncProgressCallback? onProgress}) async {
    final isar = DatabaseService.instance.isar;
    final notes =
        await DatabaseService.instance.isar.noteModels.filter().isSyncedEqualTo(false).findAll();
    final tasks =
        await DatabaseService.instance.isar.taskModels.filter().isSyncedEqualTo(false).findAll();

    onProgress?.call('${notes.length} টি নোট আপলোড হচ্ছে...');
    for (final note in notes) {
      final imageUrls = await _uploadFiles(note.imagePaths, 'images');
      final voiceUrls = await _uploadFiles(note.voiceNotePaths, 'voice');
      final map = _noteToMap(note)
        ..['imageStorageUrls'] = imageUrls
        ..['voiceStorageUrls'] = voiceUrls;
      await _notesCollection.doc(note.uuid).set(map);

      note.isSynced = true;
      await DatabaseService.instance.isar.writeTxn(() async => DatabaseService.instance.isar.noteModels.put(note));
    }

    onProgress?.call('${tasks.length} টি টাস্ক আপলোড হচ্ছে...');
    for (final task in tasks) {
      await _tasksCollection.doc(task.uuid).set(_taskToMap(task));
      task.isSynced = true;
      await DatabaseService.instance.isar.writeTxn(() async => DatabaseService.instance.isar.taskModels.put(task));
    }
  }

  /// Firestore থেকে সব notes/tasks টেনে এনে লোকাল Isar এ merge করে
  /// (last-write-wins: remote.updatedAt > local.updatedAt হলে remote জেতে)
  Future<void> pullAll({SyncProgressCallback? onProgress}) async {
    final isar = DatabaseService.instance.isar;

    onProgress?.call('রিমোট নোট ডাউনলোড হচ্ছে...');
    final remoteNotes = await _notesCollection.get();
    for (final doc in remoteNotes.docs) {
      final map = doc.data();
      final remoteUpdatedAt = DateTime.parse(map['updatedAt'] as String);

      final existing = await DatabaseService.instance.isar.noteModels
          .filter()
          .uuidEqualTo(map['uuid'] as String)
          .findFirst();
      if (existing != null && existing.updatedAt.isAfter(remoteUpdatedAt)) {
        continue; // লোকাল ভার্সন নতুন, রিমোট বাদ
      }

      final imagePaths = await _downloadFiles(
        (map['imageStorageUrls'] as List?)?.cast<String>() ?? [],
        'images',
      );
      final voicePaths = await _downloadFiles(
        (map['voiceStorageUrls'] as List?)?.cast<String>() ?? [],
        'voice',
      );

      final note = existing ?? NoteModel.create(uuid: map['uuid'], title: '');
      note
        ..title = map['title'] as String? ?? ''
        ..contentDelta = map['contentDelta'] as String?
        ..plainText = map['plainText'] as String? ?? ''
        ..type = NoteType.values.firstWhere((t) => t.name == map['type'],
            orElse: () => NoteType.text)
        ..checklistJson = map['checklistJson'] as String?
        ..drawingJson = map['drawingJson'] as String?
        ..imagePaths = imagePaths.isNotEmpty ? imagePaths : note.imagePaths
        ..voiceNotePaths =
            voicePaths.isNotEmpty ? voicePaths : note.voiceNotePaths
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
        ..createdAt = DateTime.parse(map['createdAt'] as String)
        ..updatedAt = remoteUpdatedAt
        ..isSynced = true;

      await DatabaseService.instance.isar.writeTxn(() async => DatabaseService.instance.isar.noteModels.put(note));
    }

    onProgress?.call('রিমোট টাস্ক ডাউনলোড হচ্ছে...');
    final remoteTasks = await _tasksCollection.get();
    for (final doc in remoteTasks.docs) {
      final map = doc.data();
      final remoteUpdatedAt = DateTime.parse(map['updatedAt'] as String);

      final existing = await DatabaseService.instance.isar.taskModels
          .filter()
          .uuidEqualTo(map['uuid'] as String)
          .findFirst();
      if (existing != null && existing.updatedAt.isAfter(remoteUpdatedAt)) {
        continue;
      }

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
            orElse: () => TaskPriority.medium)
        ..repeatType = RepeatType.values.firstWhere(
            (r) => r.name == map['repeatType'],
            orElse: () => RepeatType.none)
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
        ..updatedAt = remoteUpdatedAt
        ..isSynced = true;

      await DatabaseService.instance.isar.writeTxn(() async => DatabaseService.instance.isar.taskModels.put(task));
    }
  }

  Future<void> fullSync({SyncProgressCallback? onProgress}) async {
    if (_uid == null) throw Exception('সাইন-ইন করা নেই');
    await pushAll(onProgress: onProgress);
    await pullAll(onProgress: onProgress);
    onProgress?.call('সিঙ্ক সম্পন্ন');
  }

  Future<List<String>> _uploadFiles(
      List<String> localPaths, String folder) async {
    if (_uid == null || localPaths.isEmpty) return [];
    final urls = <String>[];
    for (final path in localPaths) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final fileName = path.split('/').last;
        final ref = _storage.ref('users/$_uid/$folder/$fileName');
        await ref.putFile(file);
        urls.add(await ref.getDownloadURL());
      } catch (_) {
        continue; // একটা ফাইল আপলোড ব্যর্থ হলেও বাকিগুলো চালিয়ে যাওয়া
      }
    }
    return urls;
  }

  Future<List<String>> _downloadFiles(
      List<String> urls, String folder) async {
    if (urls.isEmpty) return [];
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/$folder');
    if (!await dir.exists()) await dir.create(recursive: true);

    final localPaths = <String>[];
    for (final url in urls) {
      try {
        final ref = _storage.refFromURL(url);
        final fileName = ref.name;
        final localPath = '${dir.path}/$fileName';
        final file = File(localPath);
        if (!await file.exists()) {
          await ref.writeToFile(file);
        }
        localPaths.add(localPath);
      } catch (_) {
        continue;
      }
    }
    return localPaths;
  }
}
