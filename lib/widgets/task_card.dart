import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleComplete,
  });

  Color _priorityColor(BuildContext context) {
    switch (task.priority) {
      case TaskPriority.urgent:
        return Colors.red;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.medium:
        return Theme.of(context).colorScheme.primary;
      case TaskPriority.low:
        return Colors.grey;
    }
  }

  String _priorityLabel() {
    switch (task.priority) {
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

  bool get _isOverdue =>
      task.dueDate != null &&
      !task.isCompleted &&
      task.dueDate!.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = _priorityColor(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority রঙের ছোট বার
              Container(
                width: 4,
                height: 44,
                margin: const EdgeInsets.only(top: 2, right: 10),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) => onToggleComplete(),
                shape: const CircleBorder(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title.isEmpty ? '(শিরোনামহীন)' : task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted ? Colors.grey : null,
                            ),
                          ),
                        ),
                        if (task.isPinned)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.push_pin,
                                size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                    if (task.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ),
                    if (task.subtasks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: task.progress,
                                  minHeight: 5,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (task.dueDate != null)
                          _MetaChip(
                            icon: Icons.calendar_today,
                            label: DateFormat('d MMM, h:mm a')
                                .format(task.dueDate!),
                            color: _isOverdue ? Colors.red : Colors.grey,
                          ),
                        if (task.hasReminder)
                          const _MetaChip(
                              icon: Icons.notifications_active_outlined,
                              label: 'রিমাইন্ডার',
                              color: Colors.grey),
                        if (task.repeatType != RepeatType.none)
                          _MetaChip(
                              icon: Icons.repeat,
                              label: _repeatLabel(task.repeatType),
                              color: Colors.grey),
                        _MetaChip(
                          icon: Icons.flag,
                          label: _priorityLabel(),
                          color: priorityColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _repeatLabel(RepeatType type) {
    switch (type) {
      case RepeatType.daily:
        return 'দৈনিক';
      case RepeatType.weekly:
        return 'সাপ্তাহিক';
      case RepeatType.monthly:
        return 'মাসিক';
      case RepeatType.yearly:
        return 'বার্ষিক';
      case RepeatType.none:
        return '';
    }
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
