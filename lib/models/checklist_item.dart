import 'dart:convert';

/// NoteModel.checklistJson এ স্টোর হওয়া একটি চেকলিস্ট আইটেম
class ChecklistItem {
  String id;
  String text;
  bool checked;
  int order;

  ChecklistItem({
    required this.id,
    required this.text,
    this.checked = false,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'checked': checked,
        'order': order,
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        checked: json['checked'] as bool? ?? false,
        order: json['order'] as int? ?? 0,
      );

  static String encodeList(List<ChecklistItem> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  static List<ChecklistItem> decodeList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json) as List;
      return decoded
          .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } catch (_) {
      return [];
    }
  }
}
