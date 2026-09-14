import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../services/security_service.dart';

enum _PinStep { enter, confirm }

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  _PinStep _step = _PinStep.enter;
  String _firstPin = '';
  String _input = '';
  String? _error;

  void _onDigit(String digit) {
    if (_input.length >= 4) return;
    setState(() {
      _input += digit;
      _error = null;
    });
    if (_input.length == 4) _onComplete();
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _onComplete() async {
    if (_step == _PinStep.enter) {
      setState(() {
        _firstPin = _input;
        _input = '';
        _step = _PinStep.confirm;
      });
      return;
    }

    // Confirm ধাপ
    if (_input == _firstPin) {
      final hash = SecurityService.instance.hashPin(_input);
      await ref
          .read(settingsProvider.notifier)
          .updatePinLock(true, pinHash: hash);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN সেট করা হয়েছে ✅')),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _error = 'PIN মিলছে না, আবার চেষ্টা করুন';
        _input = '';
        _firstPin = '';
        _step = _PinStep.enter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN সেট করুন')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _step == _PinStep.enter
                  ? 'নতুন ৪-সংখ্যার PIN দিন'
                  : 'PIN আবার লিখে নিশ্চিত করুন',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _input.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 32),
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((key) {
                  if (key.isEmpty) return const SizedBox(width: 64, height: 64);
                  return SizedBox(
                    width: 64,
                    height: 64,
                    child: key == '⌫'
                        ? IconButton(
                            icon: const Icon(Icons.backspace_outlined),
                            onPressed: _onBackspace,
                          )
                        : TextButton(
                            onPressed: () => _onDigit(key),
                            style: TextButton.styleFrom(
                              shape: const CircleBorder(),
                            ),
                            child: Text(
                              key,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                  );
                }).toList(),
              ),
            ),
          )
          .toList(),
    );
  }
}
