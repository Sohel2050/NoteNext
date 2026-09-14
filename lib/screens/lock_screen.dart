import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_model.dart';
import '../providers/settings_provider.dart';
import '../services/security_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _input = '';
  String? _error;
  bool _biometricTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_biometricTried) return;
    _biometricTried = true;

    final settings = ref.read(settingsProvider);
    if (!settings.isBiometricEnabled) return;

    final available = await SecurityService.instance.isBiometricAvailable();
    if (!available) return;

    final success = await SecurityService.instance.authenticateWithBiometrics();
    if (success) widget.onUnlocked();
  }

  void _onDigit(String digit) {
    if (_input.length >= 4) return;
    setState(() {
      _input += digit;
      _error = null;
    });
    if (_input.length == 4) _checkPin();
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _checkPin() {
    final settings = ref.read(settingsProvider);
    final storedHash = settings.pinHash;
    if (storedHash == null) {
      widget.onUnlocked();
      return;
    }
    final isValid = SecurityService.instance.verifyPin(_input, storedHash);
    if (isValid) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'ভুল PIN, আবার চেষ্টা করুন';
        _input = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Mi Notes লক করা আছে',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'আনলক করতে PIN দিন',
                style: TextStyle(color: Colors.grey),
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
              _buildKeypad(settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(SettingsModel settings) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row
                  .map(
                    (key) => SizedBox(
                      width: 64,
                      height: 64,
                      child: TextButton(
                        onPressed: () => _onDigit(key),
                        style:
                            TextButton.styleFrom(shape: const CircleBorder()),
                        child: Text(key, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: settings.isBiometricEnabled
                    ? IconButton(
                        icon: const Icon(Icons.fingerprint, size: 28),
                        onPressed: _tryBiometric,
                      )
                    : null,
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: TextButton(
                  onPressed: () => _onDigit('0'),
                  style: TextButton.styleFrom(shape: const CircleBorder()),
                  child: const Text('0', style: TextStyle(fontSize: 22)),
                ),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: _onBackspace,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
