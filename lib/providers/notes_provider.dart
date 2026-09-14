import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:isar_community/isar.dart';

import '../models/note_model.dart';
import '../services/database_service.dart';

// ========== রেয়ার/প্রাইভেট স্ট্রিম প্রোভাইডার (Isar থেকে সরাসরি) ==========

final _activeNotesStreamProvider =
    StreamProvider.autoDispose<List<NoteModel>>((ref) {
  return DatabaseService.instance.isar.noteModels
      .filter()
      .isTrashedEqualTo(false)
      .and()
      .isArchivedEqualTo(false)
      .build()
      .watch(fireImmediately: true);
});

final _archivedNotesStreamProvider =
    StreamProvider.autoDispose<List<NoteModel>>((ref) {
  return DatabaseService.instance.isar.noteModels
      .filter()
      .isArchivedEqualTo(true)
      .and()
      .isTrashedEqualTo(false)
      .build()
      .watch(fireImmediately: true);
});

/// ট্র্যাশে থাকা নোটের স্ট্রিম — স্ক্রিন সরাসরি `.when()` দিয়ে ব্যবহার করে
final trashedNotesStreamProvider =
    StreamProvider.autoDispose<List<NoteModel>>((ref) {
  return DatabaseService.instance.isar.noteModels
      .filter()
      .isTrashedEqualTo(true)
      .build()
      .watch(fireImmediately: true);
});

// ========== ফিল্টার/সার্চ স্টেট ==========

final searchQueryProvider = StateProvider<String>((ref) => '');
final tagFilterProvider = StateProvider<String?>((ref) => null);

/// সক্রিয় নোটগুলোতে ব্যবহৃত সব ইউনিক ট্যাগ
final allNoteTagsProvider = Provider<List<String>>((ref) {
  final notes = ref.watch(_activeNotesStreamProvider).value ?? [];
  final tags = <String>{};
  for (final n in notes) {
    tags.addAll(n.tags);
  }
  final list = tags.toList()..sort();
  return list;
});

/// ট্যাগ + সার্চ ফিল্টার প্রয়োগ করা, পিন করা নোট আগে দেখানো তালিকা
final filteredNotesProvider = Provider<List<NoteModel>>((ref) {
  var notes = ref.watch(_activeNotesStreamProvider).value ?? [];
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final tag = ref.watch(tagFilterProvider);

  if (tag != null) {
    notes = notes.where((n) => n.tags.contains(tag)).toList();
  }
  if (query.isNotEmpty) {
    notes = notes
        .where((n) =>
            n.title.toLowerCase().contains(query) ||
            n.plainText.toLowerCase().contains(query))
        .toList();
  }

  notes = [...notes]
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  return notes;
});

/// আর্কাইভ করা নোটের তালিকা (নতুন আগে)
final archivedNotesProvider = Provider<List<NoteModel>>((ref) {
  final notes = ref.watch(_archivedNotesStreamProvider).value ?? [];
  return [...notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

// ========== CRUD কন্ট্রোলার ==========

/// নোট-সংক্রান্ত সব একশন (সেভ, ট্র্যাশ, রিস্টোর, পিন, আর্কাইভ) এক জায়গায়।
/// এটা একটা প্লেইন ক্লাস (StateNotifier/Notifier না) — কারণ এর নিজস্ব কোনো
/// state নেই, শুধু Isar-এ read/write করে; UI রিয়েল-টাইম আপডেট পায়
/// উপরের StreamProvider গুলো থেকে (Isar-এর নিজস্ব .watch() এর মাধ্যমে)।
class NotesController {
  Isar get _isar => DatabaseService.instance.isar;

  /// নতুন হোক বা বিদ্যমান — দুটোই কভার করে (id না থাকলে auto-increment হয়)
  Future<void> saveNote(NoteModel note) async {
    note.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.noteModels.put(note);
    });
  }

  Future<void> moveToTrash(NoteModel note) async {
    note.isTrashed = true;
    note.trashedAt = DateTime.now();
    note.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.noteModels.put(note);
    });
  }

  Future<void> restoreFromTrash(NoteModel note) async {
    note.isTrashed = false;
    note.trashedAt = null;
    note.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.noteModels.put(note);
    });
  }

  Future<void> deleteForever(NoteModel note) async {
    await _isar.writeTxn(() async {
      await _isar.noteModels.delete(note.id);
    });
  }

  Future<void> togglePin(NoteModel note) async {
    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.noteModels.put(note);
    });
  }

  Future<void> toggleArchive(NoteModel note) async {
    note.isArchived = !note.isArchived;
    note.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.noteModels.put(note);
    });
  }
}

final notesControllerProvider =
    Provider<NotesController>((ref) => NotesController());
