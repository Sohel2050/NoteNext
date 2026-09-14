import 'package:isar_community/isar.dart';

part 'task_model.g.dart';

enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}

enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

@collection
class TaskModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  late String title;
  String description = '';

  bool isCompleted = false;
  DateTime? completedAt;

  DateTime? dueDate;

  /// আলাদাভাবে সময় রাখা হলো যাতে শুধু ডেট বা শুধু টাইম আপডেট করা সহজ হয়
  bool hasReminder = false;
  DateTime? reminderTime;

  @Enumerated(EnumType.name)
  TaskPriority priority = TaskPriority.medium;

  @Enumerated(EnumType.name)
  RepeatType repeatType = RepeatType.none;

  /// প্রতি কত ইন্টারভালে রিপিট হবে (e.g. every 2 weeks)
  int repeatInterval = 1;

  /// Subtasks (embedded object list)
  List<SubTask> subtasks = [];

  List<String> tags = [];

  String colorHex = '#FFFFFF';

  bool isPinned = false;
  bool isArchived = false;
  bool isTrashed = false;
  DateTime? trashedAt;

  /// Firebase Cloud Firestore-এ সিঙ্ক হয়েছে কিনা (শুধু sync_service.dart
  /// ব্যবহার করে, AppConfig.enableFirebaseSync = true থাকলেই কার্যকর)
  bool isSynced = false;

  late DateTime createdAt;
  late DateTime updatedAt;

  /// Progress percentage (subtasks সম্পন্ন হওয়ার হার থেকে হিসাব হবে)
  double get progress {
    if (subtasks.isEmpty) return isCompleted ? 1.0 : 0.0;
    final done = subtasks.where((s) => s.isCompleted).length;
    return done / subtasks.length;
  }

  TaskModel();

  factory TaskModel.create({
    required String uuid,
    required String title,
  }) {
    final now = DateTime.now();
    return TaskModel()
      ..uuid = uuid
      ..title = title
      ..createdAt = now
      ..updatedAt = now;
  }
}

@embedded // এখানে @ চিহ্নটি যুক্ত করা হয়েছে
class SubTask {
  String id = '';
  String title = '';
  bool isCompleted = false;
  int order = 0;
}