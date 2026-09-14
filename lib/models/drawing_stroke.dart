import 'dart:convert';
import 'dart:ui';

enum DrawTool { pen, highlighter, eraser }

class DrawPoint {
  final double x;
  final double y;
  const DrawPoint(this.x, this.y);

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory DrawPoint.fromJson(Map<String, dynamic> json) => DrawPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );
}

class DrawStroke {
  final String id;
  final List<DrawPoint> points;
  final String colorHex;
  final double width;
  final DrawTool tool;

  /// Highlighter এর জন্য স্বচ্ছতা (0.0 - 1.0)
  final double opacity;

  DrawStroke({
    required this.id,
    required this.points,
    required this.colorHex,
    required this.width,
    required this.tool,
    this.opacity = 1.0,
  });

  Color get color {
    final cleaned = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16)).withOpacity(opacity);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'colorHex': colorHex,
        'width': width,
        'tool': tool.name,
        'opacity': opacity,
      };

  factory DrawStroke.fromJson(Map<String, dynamic> json) => DrawStroke(
        id: json['id'] as String,
        points: (json['points'] as List)
            .map((p) => DrawPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        colorHex: json['colorHex'] as String? ?? '#000000',
        width: (json['width'] as num?)?.toDouble() ?? 4.0,
        tool: DrawTool.values.firstWhere(
          (t) => t.name == json['tool'],
          orElse: () => DrawTool.pen,
        ),
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      );

  static String encodeList(List<DrawStroke> strokes) {
    return jsonEncode(strokes.map((s) => s.toJson()).toList());
  }

  static List<DrawStroke> decodeList(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr) as List;
      return decoded
          .map((e) => DrawStroke.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
