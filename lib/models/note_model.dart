import 'package:isar_community/isar.dart';

part 'note_model.g.dart';

/// নোটের ধরন
enum NoteType {
  text,       // Rich text note
  checklist,  // Checklist note
  drawing,    // Drawing/handwriting note
  voice,      // Voice note
  image,      // Image note
  mixed,      // একাধিক টাইপ একসাথে
}

@collection
class NoteModel {
  Id id = Isar.autoIncrement;

  /// ইউনিক আইডেন্টিফায়ার (ব্যাকআপ ফাইলে রেকর্ড ম্যাচ করতে ব্যবহৃত হয়)
  @Index(unique: true, replace: true)
  late String uuid;

  late String title;

  /// Rich text (Quill Delta JSON হিসেবে স্টোর হবে)
  String? contentDelta;

  /// Plain text fallback - search এর জন্য
  String plainText = '';

  @Enumerated(EnumType.name)
  NoteType type = NoteType.text;

  /// Checklist items (JSON encoded list of {text, checked})
  String? checklistJson;

  /// Drawing paths (JSON encoded stroke data)
  String? drawingJson;

  /// Voice note ফাইল পাথ (local) list
  List<String> voiceNotePaths = [];

  /// Image ফাইল পাথ (local) list
  List<String> imagePaths = [];

  /// রিমাইন্ডার সময়
  DateTime? reminderTime;

  bool isPinned = false;
  bool isArchived = false;
  bool isTrashed = false;

  /// Firebase Cloud Firestore-এ সিঙ্ক হয়েছে কিনা (শুধু sync_service.dart
  /// ব্যবহার করে, AppConfig.enableFirebaseSync = true থাকলেই কার্যকর)
  bool isSynced = false;
  DateTime? trashedAt;

  /// Note color (hex string, e.g. "#FFF59D")
  String colorHex = '#FFFFFF';

  /// Tags/Categories
  List<String> tags = [];

  bool isLocked = false;

  late DateTime createdAt;
  late DateTime updatedAt;

  NoteModel();

  factory NoteModel.create({
    required String uuid,
    required String title,
  }) {
    final now = DateTime.now();
    return NoteModel()
      ..uuid = uuid
      ..title = title
      ..createdAt = now
      ..updatedAt = now;
  }
}
