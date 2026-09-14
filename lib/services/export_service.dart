import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/checklist_item.dart';
import '../models/note_model.dart';
import '../models/task_model.dart';

class ExportService {
  ExportService._internal();
  static final ExportService instance = ExportService._internal();

  // ⚠️ সীমাবদ্ধতা: pdf প্যাকেজের ডিফল্ট ফন্টে বাংলা গ্লিফ নেই, তাই বাংলা
  // টেক্সট PDF-এ box/ফাঁকা হিসেবে দেখাতে পারে। সমাধানের জন্য assets/fonts/
  // এ NotoSansBengali.ttf যোগ করে pw.Font.ttf(await rootBundle.load(...))
  // দিয়ে pw.TextStyle(font: bengaliFont) ব্যবহার করতে হবে (pubspec.yaml এ
  // asset হিসেবে রেজিস্টার করে)। এখানে ইংরেজি/লাতিন কন্টেন্টের জন্য এটি
  // যথাযথভাবে কাজ করবে।

  /// নোটকে Markdown ফরম্যাটে রূপান্তর করে
  String noteToMarkdown(NoteModel note) {
    final buffer = StringBuffer();
    if (note.title.isNotEmpty) {
      buffer.writeln('# ${note.title}');
      buffer.writeln();
    }

    if (note.type == NoteType.checklist) {
      final items = ChecklistItem.decodeList(note.checklistJson);
      for (final item in items) {
        buffer.writeln('- [${item.checked ? 'x' : ' '}] ${item.text}');
      }
    } else {
      buffer.writeln(note.plainText);
    }

    if (note.tags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(note.tags.map((t) => '#$t').join(' '));
    }

    buffer.writeln();
    buffer.writeln(
        '_সর্বশেষ আপডেট: ${DateFormat('d MMMM yyyy, h:mm a').format(note.updatedAt)}_');

    return buffer.toString();
  }

  /// টাস্ককে Markdown ফরম্যাটে রূপান্তর করে (সাবটাস্ক সহ)
  String taskToMarkdown(TaskModel task) {
    final buffer = StringBuffer();
    buffer.writeln('# ${task.title}');
    buffer.writeln();
    if (task.description.isNotEmpty) {
      buffer.writeln(task.description);
      buffer.writeln();
    }
    buffer.writeln('- [${task.isCompleted ? 'x' : ' '}] ${task.title}');
    for (final s in task.subtasks) {
      buffer.writeln('  - [${s.isCompleted ? 'x' : ' '}] ${s.title}');
    }
    if (task.dueDate != null) {
      buffer.writeln();
      buffer.writeln(
          '**ডিউ ডেট:** ${DateFormat('d MMMM yyyy, h:mm a').format(task.dueDate!)}');
    }
    if (task.tags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(task.tags.map((t) => '#$t').join(' '));
    }
    return buffer.toString();
  }

  /// Markdown স্ট্রিং একটি .md ফাইলে সেভ করে path রিটার্ন করে
  Future<File> saveMarkdownToFile(String markdown, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.md');
    return file.writeAsString(markdown);
  }

  /// নোটকে PDF ফাইলে রূপান্তর করে path রিটার্ন করে
  Future<File> noteToPdf(NoteModel note) async {
    final pdf = pw.Document();

    List<pw.Widget> contentWidgets = [];

    if (note.type == NoteType.checklist) {
      final items = ChecklistItem.decodeList(note.checklistJson);
      contentWidgets = items
          .map(
            (item) => pw.Row(
              children: [
                pw.Text(item.checked ? '[x] ' : '[ ] '),
                pw.Expanded(child: pw.Text(item.text)),
              ],
            ),
          )
          .toList();
    } else {
      contentWidgets = [
        pw.Text(note.plainText, style: const pw.TextStyle(fontSize: 12)),
      ];
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (note.title.isNotEmpty)
              pw.Text(
                note.title,
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
            pw.SizedBox(height: 12),
            ...contentWidgets,
            pw.SizedBox(height: 16),
            if (note.tags.isNotEmpty)
              pw.Wrap(
                spacing: 6,
                children: note.tags
                    .map((t) => pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Text('#$t',
                              style: const pw.TextStyle(fontSize: 10)),
                        ))
                    .toList(),
              ),
            pw.SizedBox(height: 8),
            pw.Text(
              'সর্বশেষ আপডেট: ${DateFormat('d MMMM yyyy, h:mm a').format(note.updatedAt)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileName = (note.title.isEmpty ? 'note' : note.title)
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
