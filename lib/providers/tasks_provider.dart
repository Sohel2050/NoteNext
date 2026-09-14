import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:isar_community/isar.dart';

import '../models/task_model.dart';
import '../services/database_service.dart';

enum TaskSortOption { dueDate, priority, created, alphabetical }

// ========== রেয়ার/প্রাইভেট স্ট্রিম প্রোভাইডার (Isar থেকে সরাসরি) ==========

final _activeTasksStreamProvider =
    StreamProvider.autoDispose<List<TaskModel>>((ref) {
  return DatabaseService.instance.isar.taskModels
      .filter()
      .isTrashedEqualTo(false)
      .and()
      .isArchivedEqualTo(false)
      .build()
      .watch(fireImmediately: true);
});

/// ট্র্যাশড টাস্ক স্ট্রিম (ভবিষ্যতে ট্র্যাশ স্ক্রিন যোগ করলে ব্যবহার হবে)
final trashedTasksProvider =
    StreamProvider.autoDispose<List<TaskModel>>((ref) {
  return DatabaseService.instance.isar.taskModels
      .filter()
      .isTrashedEqualTo(true)
      .build()
      .watch(fireImmediately: true);
});

/// আর্কাইভড টাস্ক স্ট্রিম (ভবিষ্যতে আর্কাইভ স্ক্রিন যোগ করলে ব্যবহার হবে)
final archivedTasksProvider =
    StreamProvider.autoDispose<List<TaskModel>>((ref) {
  return DatabaseService.instance.isar.taskModels
      .filter()
      .isArchivedEqualTo(true)
      .and()
      .isTrashedEqualTo(false)
      .build()
      .watch(fireImmediately: true);
});

// ========== ফিল্টার/সর্ট স্টেট ==========

final taskSearchQueryProvider = StateProvider<String>((ref) => '');
final taskSortOptionProvider =
    StateProvider<TaskSortOption>((ref) => TaskSortOption.dueDate);

List<TaskModel> _applySearch(List<TaskModel> tasks, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return tasks;
  return tasks
      .where((t) =>
          t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q))
      .toList();
}

List<TaskModel> _applySort(List<TaskModel> tasks, TaskSortOption option) {
  final sorted = [...tasks];
  switch (option) {
    case TaskSortOption.dueDate:
      sorted.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
      break;
    case TaskSortOption.priority:
      sorted.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      break;
    case TaskSortOption.created:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case TaskSortOption.alphabetical:
      sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      break;
  }
  // পিন করা টাস্ক সবার আগে (স্থিতিশীল সর্ট, তাই বাকি অর্ডার বজায় থাকে)
  sorted.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    return 0;
  });
  return sorted;
}

final pendingTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(_activeTasksStreamProvider).value ?? [];
  final query = ref.watch(taskSearchQueryProvider);
  final sortOption = ref.watch(taskSortOptionProvider);
  final pending = tasks.where((t) => !t.isCompleted).toList();
  return _applySort(_applySearch(pending, query), sortOption);
});

final completedTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(_activeTasksStreamProvider).value ?? [];
  final query = ref.watch(taskSearchQueryProvider);
  final completed = tasks.where((t) => t.isCompleted).toList();
  final result = _applySearch(completed, query);
  result.sort((a, b) =>
      (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));
  return result;
});

// ========== CRUD কন্ট্রোলার ==========

/// টাস্ক-সংক্রান্ত সব একশন (তৈরি, সেভ, কমপ্লিট টগল, পিন, আর্কাইভ, ট্র্যাশ)
/// এক জায়গায়। প্লেইন ক্লাস — UI রিয়েল-টাইম আপডেট পায় উপরের
/// StreamProvider গুলো থেকে (Isar-এর .watch() এর মাধ্যমে)।
class TasksController {
  Isar get _isar => DatabaseService.instance.isar;

  Future<TaskModel> createTask({required String title}) async {
    final task = TaskModel.create(
      uuid: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
    );
    await _isar.writeTxn(() async {
      await _isar.taskModels.put(task);
    });
    return task;
  }

  Future<void> saveTask(TaskModel task) async {
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.taskModels.put(task);
    });
  }

  Future<void> toggleComplete(TaskModel task) async {
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.taskModels.put(task);
    });
  }

  Future<void> togglePin(TaskModel task) async {
    task.isPinned = !task.isPinned;
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.taskModels.put(task);
    });
  }

  Future<void> toggleArchive(TaskModel task) async {
    task.isArchived = !task.isArchived;
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.taskModels.put(task);
    });
  }

  Future<void> moveToTrash(TaskModel task) async {
    task.isTrashed = true;
    task.trashedAt = DateTime.now();
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.taskModels.put(task);
    });
  }
}

final tasksControllerProvider =
    Provider<TasksController>((ref) => TasksController());
