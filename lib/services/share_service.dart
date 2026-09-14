import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/checklist_item.dart';
import '../models/note_model.dart';
import 'export_service.dart';

const _uuid = Uuid();

class ShareService {
  ShareService._internal();
  static final ShareService instance = ShareService._internal();

  /// নোটকে প্লেইন টেক্সট হিসেবে শেয়ার করে (WhatsApp/SMS/ইত্যাদি)
  Future<void> shareNoteAsText(NoteModel note) async {
    final buffer = StringBuffer();
    if (note.title.isNotEmpty) buffer.writeln(note.title);

    if (note.type == NoteType.checklist) {
      final items = ChecklistItem.decodeList(note.checklistJson);
      for (final item in items) {
        buffer.writeln('${item.checked ? '✅' : '⬜'} ${item.text}');
      }
    } else if (note.plainText.isNotEmpty) {
      buffer.writeln(note.plainText);
    }

    if (note.tags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(note.tags.map((t) => '#$t').join(' '));
    }

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString().trim(), subject: note.title),
    );
  }

  /// একটি widget কে ইমেজ (PNG bytes) থেকে ফাইলে সেভ করে শেয়ার করে।
  /// [imageBytes] সাধারণত Screenshot controller দিয়ে ক্যাপচার করা হয় (UI থেকে)।
  Future<void> shareImageBytes(Uint8List imageBytes, {String? subject}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_uuid.v4()}.png');
    await file.writeAsBytes(imageBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
      ),
    );
  }

  /// নোটের Markdown এক্সপোর্ট ফাইল শেয়ার করে
  Future<void> shareNoteAsMarkdown(NoteModel note) async {
    final markdown = ExportService.instance.noteToMarkdown(note);
    final fileName = (note.title.isEmpty ? 'note' : note.title)
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    final file =
        await ExportService.instance.saveMarkdownToFile(markdown, fileName);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: note.title),
    );
  }

  /// নোটের PDF এক্সপোর্ট ফাইল শেয়ার করে
  Future<void> shareNoteAsPdf(NoteModel note) async {
    final file = await ExportService.instance.noteToPdf(note);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: note.title),
    );
  }
}
