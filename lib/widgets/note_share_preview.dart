import 'package:flutter/material.dart';

import '../models/checklist_item.dart';
import '../models/note_model.dart';
import '../utils/color_utils.dart';

/// শেয়ার-ইমেজ ক্যাপচারের জন্য ব্যবহৃত নোটের ভিজ্যুয়াল প্রতিনিধিত্ব।
/// এটি Screenshot widget এর ভেতরে র‍্যাপ করে RenderRepaintBoundary থেকে
/// ছবি ক্যাপচার করা হবে (note_editor_screen এ)।
class NoteSharePreview extends StatelessWidget {
  final NoteModel note;

  const NoteSharePreview({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final bgColor =
        note.colorHex == '#FFFFFF' ? Colors.white : hexToColor(note.colorHex);
    final textColor = contrastingTextColor(bgColor);

    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bgColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note.title.isNotEmpty)
            Text(
              note.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          const SizedBox(height: 12),
          if (note.type == NoteType.checklist)
            ..._checklistWidgets(textColor)
          else
            Text(
              note.plainText,
              style: TextStyle(fontSize: 14, height: 1.5, color: textColor),
            ),
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: note.tags
                  .map(
                    (t) => Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('#$t',
                          style: TextStyle(fontSize: 11, color: textColor)),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.lightbulb, size: 14, color: textColor.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text(
                'Mi Notes',
                style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _checklistWidgets(Color textColor) {
    final items = ChecklistItem.decodeList(note.checklistJson);
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.checked ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: textColor.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      decoration:
                          item.checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
