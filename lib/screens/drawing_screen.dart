import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/drawing_stroke.dart';
import '../utils/color_utils.dart';
import '../widgets/drawing_canvas.dart';

const _uuid = Uuid();

class DrawingScreen extends StatefulWidget {
  /// আগে থেকে সেভ করা ড্রয়িং থাকলে তার JSON (note.drawingJson)
  final String? initialDrawingJson;

  const DrawingScreen({super.key, this.initialDrawingJson});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<DrawStroke> _strokes = [];
  final List<List<DrawStroke>> _undoStack = [];
  final List<List<DrawStroke>> _redoStack = [];

  DrawStroke? _currentStroke;
  final List<DrawPoint> _currentPoints = [];

  DrawTool _tool = DrawTool.pen;
  String _colorHex = '#000000';
  double _brushSize = 4.0;
  bool _isPanZoomMode = false;

  final TransformationController _transformController =
      TransformationController();

  static const List<String> _palette = [
    '#000000', // কালো
    '#FFFFFF', // সাদা
    '#F28B82', // লাল
    '#FBBC04', // কমলা
    '#34A853', // সবুজ
    '#4285F4', // নীল
    '#A142F4', // বেগুনি
    '#FF66C4', // গোলাপি
    '#795548', // ব্রাউন
    '#9AA0A6', // ধূসর
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDrawingJson != null) {
      _strokes.addAll(DrawStroke.decodeList(widget.initialDrawingJson));
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _pushUndoSnapshot() {
    _undoStack.add(List.of(_strokes));
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(List.of(_strokes));
      _strokes
        ..clear()
        ..addAll(_undoStack.removeLast());
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(List.of(_strokes));
      _strokes
        ..clear()
        ..addAll(_redoStack.removeLast());
    });
  }

  void _onPanStart(Offset pos) {
    if (_isPanZoomMode) return;

    if (_tool == DrawTool.eraser) {
      _eraseAt(pos);
      return;
    }

    _currentPoints.clear();
    _currentPoints.add(DrawPoint(pos.dx, pos.dy));
    setState(() {
      _currentStroke = DrawStroke(
        id: _uuid.v4(),
        points: List.of(_currentPoints),
        colorHex: _colorHex,
        width: _brushSize,
        tool: _tool,
        opacity: _tool == DrawTool.highlighter ? 0.4 : 1.0,
      );
    });
  }

  void _onPanUpdate(Offset pos) {
    if (_isPanZoomMode) return;

    if (_tool == DrawTool.eraser) {
      _eraseAt(pos);
      return;
    }

    _currentPoints.add(DrawPoint(pos.dx, pos.dy));
    setState(() {
      _currentStroke = DrawStroke(
        id: _currentStroke!.id,
        points: List.of(_currentPoints),
        colorHex: _colorHex,
        width: _brushSize,
        tool: _tool,
        opacity: _tool == DrawTool.highlighter ? 0.4 : 1.0,
      );
    });
  }

  void _onPanEnd() {
    if (_isPanZoomMode || _tool == DrawTool.eraser) return;
    if (_currentStroke == null || _currentStroke!.points.isEmpty) return;

    _pushUndoSnapshot();
    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
      _currentPoints.clear();
    });
  }

  /// Whole-stroke eraser: eraser পয়েন্টের নির্দিষ্ট ব্যাসার্ধের মধ্যে থাকা
  /// যেকোনো স্ট্রোকের যেকোনো পয়েন্ট পেলে সম্পূর্ণ স্ট্রোকটা মুছে দেয়।
  void _eraseAt(Offset pos) {
    const eraseRadius = 18.0;
    DrawStroke? hit;
    for (final s in _strokes) {
      for (final p in s.points) {
        if ((p.offset - pos).distance <= eraseRadius) {
          hit = s;
          break;
        }
      }
      if (hit != null) break;
    }
    if (hit != null) {
      _pushUndoSnapshot();
      setState(() => _strokes.remove(hit));
    }
  }

  void _clearAll() {
    if (_strokes.isEmpty) return;
    _pushUndoSnapshot();
    setState(() => _strokes.clear());
  }

  void _save() {
    Navigator.pop(context, DrawStroke.encodeList(_strokes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('আঁকুন'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'সব মুছুন',
            onPressed: _clearAll,
          ),
          TextButton(
            onPressed: _save,
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformController,
              panEnabled: _isPanZoomMode,
              scaleEnabled: _isPanZoomMode,
              minScale: 0.5,
              maxScale: 4,
              child: DrawingCanvas(
                strokes: _strokes,
                currentStroke: _currentStroke,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
              ),
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tool selector
            Row(
              children: [
                _ToolButton(
                  icon: Icons.edit,
                  label: 'পেন',
                  selected: _tool == DrawTool.pen && !_isPanZoomMode,
                  onTap: () => setState(() {
                    _tool = DrawTool.pen;
                    _isPanZoomMode = false;
                  }),
                ),
                _ToolButton(
                  icon: Icons.brush,
                  label: 'হাইলাইটার',
                  selected: _tool == DrawTool.highlighter && !_isPanZoomMode,
                  onTap: () => setState(() {
                    _tool = DrawTool.highlighter;
                    _isPanZoomMode = false;
                  }),
                ),
                _ToolButton(
                  icon: Icons.auto_fix_off,
                  label: 'ইরেজার',
                  selected: _tool == DrawTool.eraser && !_isPanZoomMode,
                  onTap: () => setState(() {
                    _tool = DrawTool.eraser;
                    _isPanZoomMode = false;
                  }),
                ),
                _ToolButton(
                  icon: Icons.pan_tool_outlined,
                  label: 'জুম/প্যান',
                  selected: _isPanZoomMode,
                  onTap: () => setState(() => _isPanZoomMode = true),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Color palette
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _palette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final hex = _palette[i];
                  final selected = hex == _colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: hexToColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withOpacity(0.4),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            // Brush size slider
            Row(
              children: [
                const Icon(Icons.line_weight, size: 18),
                Expanded(
                  child: Slider(
                    value: _brushSize,
                    min: 1,
                    max: 30,
                    onChanged: (v) => setState(() => _brushSize = v),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    _brushSize.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
