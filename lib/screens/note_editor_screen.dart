import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:uuid/uuid.dart';

import '../models/checklist_item.dart';
import '../models/note_model.dart';
import '../providers/notes_provider.dart';
import '../services/export_service.dart';
import '../services/image_service.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';
import '../services/voice_recorder_service.dart';
import '../utils/color_utils.dart';
import '../widgets/color_picker_sheet.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/note_share_preview.dart';
import '../widgets/voice_note_player.dart';
import '../widgets/voice_recorder_sheet.dart';
import '../models/drawing_stroke.dart';
import 'drawing_screen.dart';

const _uuid = Uuid();

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteModel? existingNote;

  const NoteEditorScreen({super.key, this.existingNote});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late NoteModel _note;
  late TextEditingController _titleController;
  late quill.QuillController _quillController;
  late FocusNode _editorFocusNode;
  final ScreenshotController _screenshotController = ScreenshotController();

  List<ChecklistItem> _checklistItems = [];

  bool get _isChecklistMode => _note.type == NoteType.checklist;

  @override
  void initState() {
    super.initState();
    _note = widget.existingNote ??
        NoteModel.create(uuid: _uuid.v4(), title: '');
    _titleController = TextEditingController(text: _note.title);
    _editorFocusNode = FocusNode();
    _quillController = _buildQuillController();
    _checklistItems = ChecklistItem.decodeList(_note.checklistJson);
  }

  /// সেভ করা contentDelta (JSON স্ট্রিং) থেকে QuillController তৈরি করে,
  /// কিছু না থাকলে খালি ডকুমেন্ট দিয়ে শুরু করে।
  quill.QuillController _buildQuillController() {
    final raw = _note.contentDelta;
    if (raw == null || raw.isEmpty) {
      return quill.QuillController.basic();
    }
    try {
      final decodedJson = jsonDecode(raw) as List<dynamic>;
      final doc = quill.Document.fromJson(decodedJson);
      return quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      return quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  /// টাইটেল/কন্টেন্ট/checklist ফিল্ড থেকে বর্তমান UI state _note-এ সিংক করে
  /// (সেভ করার আগে, অথবা শেয়ার/এক্সপোর্টের আগে সর্বশেষ কন্টেন্ট নিশ্চিত করতে)
  void _syncContentToNote() {
    _note.title = _titleController.text.trim();

    if (_isChecklistMode) {
      _checklistItems.removeWhere((e) => e.text.trim().isEmpty);
      _note.checklistJson = ChecklistItem.encodeList(_checklistItems);
      _note.plainText = _checklistItems.map((e) => e.text).join(' ');
    } else {
      final plain = _quillController.document.toPlainText().trim();
      _note.plainText = plain;
      _note.contentDelta =
          jsonEncode(_quillController.document.toDelta().toJson());
    }
  }

  Future<void> _save() async {
    _syncContentToNote();

    final isEmpty = _note.title.isEmpty &&
        _note.plainText.trim().isEmpty &&
        _checklistItems.isEmpty;
    if (isEmpty) {
      // খালি নোট হলে (নতুন হলে) কিছু সেভ না করে বাতিল
      if (widget.existingNote == null) return;
    }

    await ref.read(notesControllerProvider).saveNote(_note);
  }

  Future<void> _shareAsText() async {
    _syncContentToNote();
    await ShareService.instance.shareNoteAsText(_note);
  }

  Future<void> _shareAsImage() async {
    _syncContentToNote();
    try {
      final bytes = await _screenshotController.captureFromWidget(
        Material(child: NoteSharePreview(note: _note)),
        pixelRatio: 2.5,
      );
      await ShareService.instance.shareImageBytes(bytes, subject: _note.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ছবি হিসেবে শেয়ার করা যায়নি: $e')),
        );
      }
    }
  }

  Future<void> _shareAsMarkdown() async {
    _syncContentToNote();
    await ShareService.instance.shareNoteAsMarkdown(_note);
  }

  Future<void> _shareAsPdf() async {
    _syncContentToNote();
    await ShareService.instance.shareNoteAsPdf(_note);
  }

  Future<void> _showShareSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('শেয়ার / এক্সপোর্ট',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('টেক্সট হিসেবে শেয়ার'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('ছবি হিসেবে শেয়ার'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Markdown হিসেবে এক্সপোর্ট'),
              onTap: () => Navigator.pop(context, 'markdown'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF হিসেবে এক্সপোর্ট'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'text':
        await _shareAsText();
        break;
      case 'image':
        await _shareAsImage();
        break;
      case 'markdown':
        await _shareAsMarkdown();
        break;
      case 'pdf':
        await _shareAsPdf();
        break;
    }
  }

  void _switchToChecklist() {
    setState(() {
      _note.type = NoteType.checklist;
      if (_checklistItems.isEmpty) {
        _checklistItems.add(ChecklistItem(id: _uuid.v4(), text: ''));
      }
    });
  }

  void _switchToText() {
    setState(() => _note.type = NoteType.text);
  }

  void _addChecklistItem() {
    setState(() {
      _checklistItems.add(
        ChecklistItem(id: _uuid.v4(), text: '', order: _checklistItems.length),
      );
    });
  }

  void _removeChecklistItem(ChecklistItem item) {
    setState(() => _checklistItems.remove(item));
  }

  Future<void> _openDrawing() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            DrawingScreen(initialDrawingJson: _note.drawingJson),
      ),
    );
    if (result != null) {
      setState(() {
        _note.drawingJson = result;
        if (_note.type == NoteType.text &&
            _titleController.text.trim().isEmpty &&
            _quillController.document.toPlainText().trim().isEmpty) {
          _note.type = NoteType.drawing;
        } else {
          _note.type = NoteType.mixed;
        }
      });
    }
  }

  Future<void> _addImage() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('গ্যালারি থেকে বেছে নিন'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ছবি তুলুন'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    String? path;
    if (source == 'gallery') {
      path = await ImageService.instance.pickFromGallery();
    } else {
      path = await ImageService.instance.pickFromCamera();
    }
    if (path != null) {
      setState(() {
        _note.imagePaths = [..._note.imagePaths, path!];
        if (_note.type == NoteType.text &&
            _titleController.text.trim().isEmpty &&
            _quillController.document.toPlainText().trim().isEmpty) {
          _note.type = NoteType.image;
        } else if (_note.type != NoteType.image) {
          _note.type = NoteType.mixed;
        }
      });
    }
  }

  void _removeImage(String path) {
    setState(() {
      _note.imagePaths = _note.imagePaths.where((p) => p != path).toList();
    });
    ImageService.instance.deleteImage(path);
  }

  Future<void> _addVoiceNote() async {
    final path = await showVoiceRecorderSheet(context);
    if (path != null) {
      setState(() {
        _note.voiceNotePaths = [..._note.voiceNotePaths, path];
        if (_note.type == NoteType.text &&
            _titleController.text.trim().isEmpty &&
            _quillController.document.toPlainText().trim().isEmpty) {
          _note.type = NoteType.voice;
        } else if (_note.type != NoteType.voice) {
          _note.type = NoteType.mixed;
        }
      });
    }
  }

  void _removeVoiceNote(String path) {
    setState(() {
      _note.voiceNotePaths =
          _note.voiceNotePaths.where((p) => p != path).toList();
    });
    VoiceRecorderService.instance.deleteFile(path);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _note.reminderTime ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_note.reminderTime ?? now),
    );
    if (time == null) return;

    final scheduled =
    DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _note.reminderTime = scheduled);

    // নতুন (এখনো সেভ না হওয়া) নোটের id সবসময় 0 থাকে; নোটিফিকেশন id
    // কলিশন এড়াতে প্রথমে নোটটি সেভ করে আসল Isar id নিশ্চিত করা হচ্ছে।
    if (_note.id == 0) {
      await ref.read(notesControllerProvider).saveNote(_note);
    }

    await NotificationService.instance.scheduleNoteReminder(
      noteId: _note.id,
      title: _note.title,
      body: _note.plainText.isEmpty ? 'রিমাইন্ডার' : _note.plainText,
      scheduledTime: scheduled,
    );
  }

  Future<void> _clearReminder() async {
    setState(() => _note.reminderTime = null);
    await NotificationService.instance.cancelNoteReminder(_note.id);
  }

  Future<void> _pickColor() async {
    final hex = await showColorPickerSheet(context, currentHex: _note.colorHex);
    if (hex != null) setState(() => _note.colorHex = hex);
  }

  Future<void> _editTags() async {
    final controller = TextEditingController(text: _note.tags.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ট্যাগ (কমা দিয়ে আলাদা করুন)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'কাজ, ব্যক্তিগত, জরুরি'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _note.tags = result
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ট্র্যাশে সরাবেন?'),
        content: const Text('নোটটি ৭ দিন পর স্থায়ীভাবে মুছে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ট্র্যাশে সরান'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notesControllerProvider).moveToTrash(_note);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
    _note.colorHex == '#FFFFFF' ? null : hexToColor(_note.colorHex);

    return PopScope(
      onPopInvoked: (didPop) async {
        if (didPop) await _save();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          actions: [
            IconButton(
              icon: Icon(
                  _note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              tooltip: 'পিন করুন',
              onPressed: () => setState(() => _note.isPinned = !_note.isPinned),
            ),
            IconButton(
              icon: Icon(_note.reminderTime != null
                  ? Icons.notifications_active
                  : Icons.notifications_outlined),
              tooltip: 'রিমাইন্ডার',
              onPressed: _note.reminderTime != null
                  ? () async {
                final action = await showModalBottomSheet<String>(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(
                            'রিমাইন্ডার: ${DateFormat('d MMM, h:mm a').format(_note.reminderTime!)}',
                          ),
                          onTap: () => Navigator.pop(context, 'edit'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.close),
                          title: const Text('রিমাইন্ডার সরান'),
                          onTap: () => Navigator.pop(context, 'clear'),
                        ),
                      ],
                    ),
                  ),
                );
                if (action == 'edit') await _pickReminder();
                if (action == 'clear') await _clearReminder();
              }
                  : _pickReminder,
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'archive':
                    setState(() => _note.isArchived = !_note.isArchived);
                    break;
                  case 'delete':
                    await _confirmDelete();
                    break;
                  case 'tags':
                    await _editTags();
                    break;
                  case 'checklist':
                    _isChecklistMode ? _switchToText() : _switchToChecklist();
                    break;
                  case 'share':
                    await _showShareSheet();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'checklist',
                  child: Text(
                      _isChecklistMode ? 'টেক্সট মোডে যান' : 'চেকলিস্টে রূপান্তর'),
                ),
                const PopupMenuItem(value: 'tags', child: Text('ট্যাগ যোগ করুন')),
                const PopupMenuItem(
                    value: 'share', child: Text('শেয়ার / এক্সপোর্ট')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(_note.isArchived ? 'আনআর্কাইভ' : 'আর্কাইভ'),
                ),
                const PopupMenuItem(
                    value: 'delete', child: Text('ট্র্যাশে সরান')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: Theme.of(context).textTheme.headlineSmall,
                      decoration:
                      const InputDecoration(hintText: 'শিরোনাম', border: InputBorder.none),
                      maxLines: null,
                    ),
                    if (_note.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          children:
                          _note.tags.map((t) => Chip(label: Text(t))).toList(),
                        ),
                      ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    if (_note.imagePaths.isNotEmpty) _buildImageGallery(),
                    if (_note.voiceNotePaths.isNotEmpty)
                      _buildVoiceNotesList(),
                    if (_note.drawingJson != null &&
                        _note.drawingJson!.isNotEmpty)
                      _buildDrawingPreview(),
                    if (_isChecklistMode)
                      _buildChecklistEditor()
                    else
                      _buildRichTextEditor(),
                  ],
                ),
              ),
            ),
            if (!_isChecklistMode) _buildQuillToolbar(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _note.imagePaths.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final path = _note.imagePaths[i];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(path),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeImage(path),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoiceNotesList() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _note.voiceNotePaths
            .map(
              (path) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: VoiceNotePlayer(
              filePath: path,
              onDelete: () => _removeVoiceNote(path),
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildDrawingPreview() {
    final strokes = DrawStroke.decodeList(_note.drawingJson);
    return GestureDetector(
      onTap: _openDrawing,
      child: Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IgnorePointer(
          child: DrawingCanvas(
            strokes: strokes,
            currentStroke: null,
            onPanStart: (_) {},
            onPanUpdate: (_) {},
            onPanEnd: () {},
          ),
        ),
      ),
    );
  }

  Widget _buildRichTextEditor() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: quill.QuillEditor.basic(
        controller: _quillController,
        focusNode: _editorFocusNode,
      ),
    );
  }

  Widget _buildQuillToolbar() {
    return SizedBox(
      width: double.infinity,
      child: quill.QuillSimpleToolbar(
        controller: _quillController,
        config: const quill.QuillSimpleToolbarConfig(
          showAlignmentButtons: false,
          showBackgroundColorButton: false,
          showCenterAlignment: false,
          showColorButton: true,
          showCodeBlock: false,
          showDividers: false,
          showFontFamily: false,
          showFontSize: false,
          showHeaderStyle: true,
          showIndent: false,
          showInlineCode: false,
          showJustifyAlignment: false,
          showLeftAlignment: false,
          showLink: true,
          showListBullets: true,
          showListCheck: true,
          showListNumbers: true,
          showQuote: false,
          showRightAlignment: false,
          showSearchButton: false,
          showSmallButton: false,
          showStrikeThrough: true,
          showSubscript: false,
          showSuperscript: false,
          showUnderLineButton: true,
          showRedo: true,
          showUndo: true,
          showBoldButton: true,
          showItalicButton: true,
          multiRowsDisplay: false,
        ),
      ),
    );
  }

  Widget _buildChecklistEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _checklistItems.removeAt(oldIndex);
              _checklistItems.insert(newIndex, item);
              for (var i = 0; i < _checklistItems.length; i++) {
                _checklistItems[i].order = i;
              }
            });
          },
          children: [
            for (final item in _checklistItems)
              Padding(
                key: ValueKey(item.id),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Checkbox(
                      value: item.checked,
                      onChanged: (v) => setState(() => item.checked = v ?? false),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.text,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'তালিকার আইটেম',
                        ),
                        style: TextStyle(
                          decoration:
                          item.checked ? TextDecoration.lineThrough : null,
                          color: item.checked ? Colors.grey : null,
                        ),
                        onChanged: (v) => item.text = v,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeChecklistItem(item),
                    ),
                    ReorderableDragStartListener(
                      index: _checklistItems.indexOf(item),
                      child: const Icon(Icons.drag_handle,
                          size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
        TextButton.icon(
          onPressed: _addChecklistItem,
          icon: const Icon(Icons.add),
          label: const Text('আইটেম যোগ করুন'),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'রঙ',
              onPressed: _pickColor,
            ),
            IconButton(
              icon: const Icon(Icons.image_outlined),
              tooltip: 'ছবি',
              onPressed: _addImage,
            ),
            IconButton(
              icon: const Icon(Icons.mic_none_outlined),
              tooltip: 'ভয়েস নোট',
              onPressed: _addVoiceNote,
            ),
            IconButton(
              icon: const Icon(Icons.brush_outlined),
              tooltip: 'আঁকুন',
              onPressed: _openDrawing,
            ),
            const Spacer(),
            Text(
              _note.updatedAt.toString().substring(0, 16),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}