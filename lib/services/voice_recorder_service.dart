import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// ভয়েস নোট রেকর্ডিং সার্ভিস। রেকর্ডিং অ্যাপের ডকুমেন্টস ডিরেক্টরির
/// `voice_notes/` ফোল্ডারে .m4a ফাইল হিসেবে সেভ হয়।
class VoiceRecorderService {
  VoiceRecorderService._internal();
  static final VoiceRecorderService instance = VoiceRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Directory> _voiceDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/voice_notes');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> start() async {
    final granted = await requestPermission();
    if (!granted) {
      throw Exception('মাইক্রোফোন অনুমতি প্রত্যাখ্যাত হয়েছে');
    }
    final dir = await _voiceDir();
    final path = '${dir.path}/${_uuid.v4()}.m4a';
    _currentPath = path;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    _currentPath = null;
    return path;
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    if (_currentPath != null) {
      final f = File(_currentPath!);
      if (await f.exists()) await f.delete();
    }
    _currentPath = null;
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Stream<Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 200));

  Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  void dispose() {
    _recorder.dispose();
  }
}
