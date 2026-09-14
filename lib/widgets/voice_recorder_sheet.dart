import 'dart:async';

import 'package:flutter/material.dart';

import '../services/voice_recorder_service.dart';

/// রেকর্ডিং শুরু করে একটি bottom sheet দেখায়; বন্ধ করলে রেকর্ড করা
/// ফাইলের path রিটার্ন করে (বাতিল করলে null)।
Future<String?> showVoiceRecorderSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _VoiceRecorderSheet(),
  );
}

class _VoiceRecorderSheet extends StatefulWidget {
  const _VoiceRecorderSheet();

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> {
  final _service = VoiceRecorderService.instance;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isRecording = false;
  bool _isStarting = true;
  double _amplitude = 0;
  StreamSubscription? _ampSub;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _service.start();
      _ampSub = _service.amplitudeStream.listen((amp) {
        // amp.current সাধারণত -160 (নীরব) থেকে 0 (জোরে) dB রেঞ্জে থাকে
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        if (mounted) setState(() => _amplitude = normalized);
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed += const Duration(seconds: 1));
        }
      });
      setState(() {
        _isRecording = true;
        _isStarting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('রেকর্ড শুরু করা যায়নি: $e')),
        );
      }
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    _ampSub?.cancel();
    final path = await _service.stop();
    if (mounted) Navigator.pop(context, path);
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _ampSub?.cancel();
    await _service.cancel();
    if (mounted) Navigator.pop(context, null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isStarting ? 'শুরু হচ্ছে...' : 'রেকর্ড হচ্ছে',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // সাধারণ amplitude bar ইন্ডিকেটর
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 80 + (_amplitude * 60),
              height: 80 + (_amplitude * 60),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic,
                size: 36,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _formatDuration(_elapsed),
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.close),
                  label: const Text('বাতিল'),
                ),
                FilledButton.icon(
                  onPressed: _isRecording ? _stopAndSave : null,
                  icon: const Icon(Icons.check),
                  label: const Text('সম্পন্ন'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
