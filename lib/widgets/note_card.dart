import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/checklist_item.dart';
import '../models/note_model.dart';
import '../utils/color_utils.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // note.colorHex এখন পুরো কার্ড না ভরে শুধু বাম পাশের অ্যাকসেন্ট বারে ব্যবহৃত হয়।
    // ধূসর/সাদা মানে "নিরপেক্ষ" — তখন থিমের primary রঙ accent হিসেবে ব্যবহৃত হয়।
    final isNeutral = note.colorHex == '#FFFFFF' ||
        note.colorHex.toUpperCase() == '#9AA0A6' ||
        note.colorHex.isEmpty;
    final accentColor =
        isNeutral ? theme.colorScheme.primary : hexToColor(note.colorHex);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accentColor),
            Expanded(
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              note.title.isEmpty ? '(শিরোনামহীন)' : note.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (note.isPinned)
                            Icon(Icons.push_pin, size: 14, color: accentColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildPreview(context),
                      if (note.imagePaths.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.file(
                              File(note.imagePaths.first),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image, size: 28),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (note.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: note.tags.take(2).map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(fontSize: 10, color: accentColor),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (note.voiceNotePaths.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Icon(Icons.mic,
                                  size: 13, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          if (note.type == NoteType.drawing ||
                              (note.drawingJson?.isNotEmpty ?? false))
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Icon(Icons.brush,
                                  size: 13, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          if (note.reminderTime != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Icon(Icons.alarm,
                                  size: 13, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          const Spacer(),
                          Text(
                            DateFormat('d MMM').format(note.updatedAt),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final subColor = theme.colorScheme.onSurfaceVariant;

    if (note.type == NoteType.checklist) {
      final items = ChecklistItem.decodeList(note.checklistJson);
      final visible = items.take(4).toList();
      if (visible.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: visible.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.checked ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 15,
                  color: subColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: item.checked ? subColor : theme.colorScheme.onSurface,
                      decoration:
                          item.checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (note.plainText.isEmpty) return const SizedBox.shrink();
    return Text(
      note.plainText,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.5,
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    );
  }
}
