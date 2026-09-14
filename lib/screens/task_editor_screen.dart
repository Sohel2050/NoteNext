import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/task_model.dart';
import '../providers/tasks_provider.dart';
import '../services/notification_service.dart';

const _uuid = Uuid();

class TaskEditorScreen extends ConsumerStatefulWidget {
  final TaskModel? existingTask;

  const TaskEditorScreen({super.key, this.existingTask});

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  late TaskModel _task;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _subtaskInputController;

  @override
  void initState() {
    super.initState();
    _task = widget.existingTask ?? TaskModel.create(uuid: _uuid.v4(), title: '');
    _titleController = TextEditingController(text: _task.title);
    _descController = TextEditingController(text: _task.description);
    _subtaskInputController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subtaskInputController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _task.title = _titleController.text.trim();
    _task.description = _descController.text.trim();

    final isEmpty = _task.title.isEmpty && _task.description.isEmpty;
    if (isEmpty && widget.existingTask == null) return;

    await ref.read(tasksControllerProvider).saveTask(_task);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initialDate = _task.dueDate ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) {
      setState(() => _task.dueDate =
          DateTime(date.year, date.month, date.day, 23, 59));
      return;
    }
    setState(() {
      _task.dueDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _clearDueDate() {
    setState(() {
      _task.dueDate = null;
      _task.hasReminder = false;
      _task.reminderTime = null;
    });
  }

  Future<void> _pickReminder() async {
    if (_task.dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('আগে ডিউ ডেট সেট করুন')),
      );
      return;
    }
    final options = <String, Duration>{
      'সময়মতো': Duration.zero,
      '৫ মিনিট আগে': const Duration(minutes: 5),
      '৩০ মিনিট আগে': const Duration(minutes: 30),
      '১ ঘণ্টা আগে': const Duration(hours: 1),
      '১ দিন আগে': const Duration(days: 1),
    };
    final selected = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: options.entries
              .map(
                (e) => ListTile(
                  title: Text(e.key),
                  onTap: () => Navigator.pop(context, e.value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _task.hasReminder = true;
        _task.reminderTime = _task.dueDate!.subtract(selected);
      });

      // নতুন (এখনো সেভ না হওয়া) টাস্কের id সবসময় 0 থাকে; নোটিফিকেশন id
      // কলিশন এড়াতে প্রথমে টাস্কটি সেভ করে আসল Isar id নিশ্চিত করা হচ্ছে।
      if (_task.id == 0) {
        await ref.read(tasksControllerProvider).saveTask(_task);
      }
      await NotificationService.instance.scheduleTaskReminder(
        taskId: _task.id,
        title: _task.title,
        body: _task.description.isEmpty ? 'টাস্ক রিমাইন্ডার' : _task.description,
        scheduledTime: _task.reminderTime!,
      );
    }
  }

  void _setPriority(TaskPriority p) {
    setState(() => _task.priority = p);
  }

  Future<void> _pickRepeat() async {
    final result = await showModalBottomSheet<RepeatType>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('পুনরাবৃত্তি', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final type in RepeatType.values)
              ListTile(
                leading: Icon(
                  type == _task.repeatType
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(_repeatLabel(type)),
                onTap: () => Navigator.pop(context, type),
              ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _task.repeatType = result);
    }
  }

  String _repeatLabel(RepeatType type) {
    switch (type) {
      case RepeatType.none:
        return 'একবার (কোনো পুনরাবৃত্তি নেই)';
      case RepeatType.daily:
        return 'প্রতিদিন';
      case RepeatType.weekly:
        return 'প্রতি সপ্তাহে';
      case RepeatType.monthly:
        return 'প্রতি মাসে';
      case RepeatType.yearly:
        return 'প্রতি বছর';
    }
  }

  void _addSubtask() {
    final text = _subtaskInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _task.subtasks = [
        ..._task.subtasks,
        SubTask()
          ..id = _uuid.v4()
          ..title = text
          ..order = _task.subtasks.length,
      ];
      _subtaskInputController.clear();
    });
  }

  void _removeSubtask(SubTask s) {
    setState(() {
      _task.subtasks = _task.subtasks.where((e) => e.id != s.id).toList();
    });
  }

  void _toggleSubtaskLocal(SubTask s) {
    setState(() {
      s.isCompleted = !s.isCompleted;
    });
  }

  Future<void> _editTags() async {
    final controller = TextEditingController(text: _task.tags.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ট্যাগ (কমা দিয়ে আলাদা করুন)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'কাজ, বাসা, জরুরি'),
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
        _task.tags = result
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
        content: const Text('টাস্কটি ৭ দিন পর স্থায়ীভাবে মুছে যাবে।'),
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
      await ref.read(tasksControllerProvider).moveToTrash(_task);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) async {
        if (didPop) await _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existingTask == null ? 'নতুন টাস্ক' : 'টাস্ক এডিট'),
          actions: [
            IconButton(
              icon: Icon(
                  _task.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(() => _task.isPinned = !_task.isPinned),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'archive':
                    setState(() => _task.isArchived = !_task.isArchived);
                    break;
                  case 'tags':
                    await _editTags();
                    break;
                  case 'delete':
                    await _confirmDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'tags', child: Text('ট্যাগ যোগ করুন')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(_task.isArchived ? 'আনআর্কাইভ' : 'আর্কাইভ'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('ট্র্যাশে সরান')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _titleController,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                hintText: 'টাস্কের নাম',
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                hintText: 'বিস্তারিত লিখুন...',
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
            if (_task.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: _task.tags.map((t) => Chip(label: Text(t))).toList(),
                ),
              ),
            const Divider(height: 32),

            // ---------- Due Date & Reminder ----------
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(
                _task.dueDate == null
                    ? 'ডিউ ডেট সেট করুন'
                    : DateFormat('EEEE, d MMMM yyyy — h:mm a')
                        .format(_task.dueDate!),
              ),
              trailing: _task.dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearDueDate,
                    )
                  : null,
              onTap: _pickDueDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined),
              title: Text(
                _task.hasReminder && _task.reminderTime != null
                    ? 'রিমাইন্ডার: ${DateFormat('d MMM, h:mm a').format(_task.reminderTime!)}'
                    : 'রিমাইন্ডার যোগ করুন',
              ),
              trailing: _task.hasReminder
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        setState(() {
                          _task.hasReminder = false;
                          _task.reminderTime = null;
                        });
                        await NotificationService.instance
                            .cancelTaskReminder(_task.id);
                      },
                    )
                  : null,
              onTap: _pickReminder,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: Text('পুনরাবৃত্তি: ${_repeatLabel(_task.repeatType)}'),
              onTap: _pickRepeat,
            ),

            const Divider(height: 32),

            // ---------- Priority ----------
            const Text('প্রায়োরিটি', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: TaskPriority.values.map((p) {
                final selected = _task.priority == p;
                return ChoiceChip(
                  label: Text(_priorityLabel(p)),
                  selected: selected,
                  onSelected: (_) => _setPriority(p),
                  avatar: Icon(Icons.flag, size: 16, color: _priorityColor(p)),
                );
              }).toList(),
            ),

            const Divider(height: 32),

            // ---------- Subtasks ----------
            Row(
              children: const [
                Text('সাবটাস্ক', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final list = [..._task.subtasks];
                  final item = list.removeAt(oldIndex);
                  list.insert(newIndex, item);
                  for (var i = 0; i < list.length; i++) {
                    list[i].order = i;
                  }
                  _task.subtasks = list;
                });
              },
              children: [
                for (final s in _task.subtasks)
                  Padding(
                    key: ValueKey(s.id),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Checkbox(
                          value: s.isCompleted,
                          onChanged: (_) => _toggleSubtaskLocal(s),
                        ),
                        Expanded(
                          child: Text(
                            s.title,
                            style: TextStyle(
                              decoration: s.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: s.isCompleted ? Colors.grey : null,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeSubtask(s),
                        ),
                        const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskInputController,
                    decoration: const InputDecoration(
                      hintText: 'নতুন সাবটাস্ক যোগ করুন',
                    ),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _addSubtask,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _priorityLabel(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent:
        return 'জরুরি';
      case TaskPriority.high:
        return 'উচ্চ';
      case TaskPriority.medium:
        return 'মাঝারি';
      case TaskPriority.low:
        return 'নিম্ন';
    }
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent:
        return Colors.red;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.low:
        return Colors.grey;
    }
  }
}
