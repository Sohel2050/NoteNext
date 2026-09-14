import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/color_utils.dart';

Future<String?> showColorPickerSheet(
  BuildContext context, {
  required String currentHex,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('রঙ নির্বাচন করুন',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: AppTheme.noteColors.map((color) {
                final hex = colorToHex(color);
                final isSelected =
                    hex.toUpperCase() == currentHex.toUpperCase();
                return GestureDetector(
                  onTap: () => Navigator.pop(context, hex),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withOpacity(0.4),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                            size: 18, color: contrastingTextColor(color))
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    },
  );
}
