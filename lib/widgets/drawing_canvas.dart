import 'package:flutter/material.dart';

import '../models/drawing_stroke.dart';

/// আঁকার জন্য মূল ক্যানভাস। এটি শুধু রেন্ডারিং + ইনপুট ক্যাপচার করে;
/// undo/redo/tool state প্যারেন্ট (DrawingScreen) এ ম্যানেজ হয়।
class DrawingCanvas extends StatelessWidget {
  final List<DrawStroke> strokes;
  final DrawStroke? currentStroke;
  final void Function(Offset localPosition) onPanStart;
  final void Function(Offset localPosition) onPanUpdate;
  final VoidCallback onPanEnd;
  final Color backgroundColor;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.currentStroke,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => onPanStart(details.localPosition),
      onPanUpdate: (details) => onPanUpdate(details.localPosition),
      onPanEnd: (_) => onPanEnd(),
      child: CustomPaint(
        painter: _DrawingPainter(
          strokes: strokes,
          currentStroke: currentStroke,
          backgroundColor: backgroundColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  final DrawStroke? currentStroke;
  final Color backgroundColor;

  _DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.backgroundColor,
  });

  void _paintStroke(Canvas canvas, DrawStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.tool == DrawTool.highlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    if (stroke.points.length == 1) {
      // একক ট্যাপ - একটা বিন্দু আঁকা
      canvas.drawCircle(
        stroke.points.first.offset,
        stroke.width / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].x, stroke.points[i].y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (currentStroke != null) {
      _paintStroke(canvas, currentStroke!);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}
