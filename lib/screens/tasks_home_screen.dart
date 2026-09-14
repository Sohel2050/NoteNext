import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_model.dart';
import '../providers/tasks_provider.dart';
import '../widgets/task_card.dart';
import 'task_editor_screen.dart';

class TasksHomeScreen extends ConsumerStatefulWidget {
  const TasksHomeScreen({super.key});

  @override
  ConsumerState<TasksHomeScreen> createState() => _TasksHomeScreenState();
}

class _TasksHomeScreenState extends ConsumerState<TasksHomeScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditor([TaskModel? task]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskEditorScreen(existingTask: task)),
    );
  }

  Future<void> _quickAddTask() async {
    final controller = TextEditingController();
    final title = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'দ্রুত টাস্ক যোগ করুন...'),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => Navigator.pop(context, controller.text),
            ),
          ],
        ),
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    final controllerObj = ref.read(tasksControllerProvider);
    final task = await controllerObj.createTask(title: title.trim());
    // দ্রুত-যোগ করা টাস্কে বিস্তারিত সেট করতে চাইলে এডিটর খোলার সুযোগ
    if (mounted) _openEditor(task);
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingTasksProvider);
    final completed = ref.watch(completedTasksProvider);
    final sortOption = ref.watch(taskSortOptionProvider);
    final controller = ref.read(tasksControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'টাস্ক খুঁজুন...',
            border: InputBorder.none,
          ),
          onChanged: (v) =>
          ref.read(taskSearchQueryProvider.notifier).state = v,
        )
            : const Text('Tasks'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(taskSearchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
          PopupMenuButton<TaskSortOption>(
            icon: const Icon(Icons.sort),
            initialValue: sortOption,
            onSelected: (v) =>
            ref.read(taskSortOptionProvider.notifier).state = v,
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: TaskSortOption.dueDate, child: Text('ডিউ ডেট অনুযায়ী')),
              PopupMenuItem(
                  value: TaskSortOption.priority, child: Text('প্রায়োরিটি অনুযায়ী')),
              PopupMenuItem(
                  value: TaskSortOption.created, child: Text('তৈরির সময় অনুযায়ী')),
              PopupMenuItem(
                  value: TaskSortOption.alphabetical, child: Text('নাম অনুযায়ী')),
            ],
          ),
        ],
      ),
      body: pending.isEmpty && completed.isEmpty
          ? _buildEmptyState()
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (pending.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'অসম্পন্ন (${pending.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            ...pending.map(
                  (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskCard(
                  task: t,
                  onTap: () => _openEditor(t),
                  onLongPress: () => _showActionsSheet(t, controller),
                  onToggleComplete: () => controller.toggleComplete(t),
                ),
              ),
            ),
          ],
          if (completed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'সম্পন্ন (${completed.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            ...completed.map(
                  (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Opacity(
                  opacity: 0.6,
                  child: TaskCard(
                    task: t,
                    onTap: () => _openEditor(t),
                    onLongPress: () => _showActionsSheet(t, controller),
                    onToggleComplete: () => controller.toggleComplete(t),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks_home_fab',
        onPressed: _quickAddTask,
        icon: const Icon(Icons.add),
        label: const Text('নতুন টাস্ক'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'এখনো কোনো টাস্ক নেই\n+ বাটনে চেপে শুরু করুন',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showActionsSheet(TaskModel task, TasksController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(task.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(task.isPinned ? 'আনপিন করুন' : 'পিন করুন'),
              onTap: () {
                controller.togglePin(task);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                  task.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(task.isArchived ? 'আনআর্কাইভ' : 'আর্কাইভ করুন'),
              onTap: () {
                controller.toggleArchive(task);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('ট্র্যাশে সরান', style: TextStyle(color: Colors.red)),
              onTap: () {
                controller.moveToTrash(task);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}