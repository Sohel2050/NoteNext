import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import 'home_shell.dart';
import 'lock_screen.dart';

/// পুরো অ্যাপের রুট শেল। PIN/Biometric লক সক্রিয় থাকলে অ্যাপ শুরুতে এবং
/// ব্যাকগ্রাউন্ড থেকে ফিরে এলে [LockScreen] দেখায়। Auto-backup সক্রিয় থাকলে
/// অ্যাপ ব্যাকগ্রাউন্ডে যাওয়ার সময় স্থানীয় ব্যাকআপ নেয়।
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _hasCheckedInitialLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(settingsProvider);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // ব্যাকগ্রাউন্ডে যাওয়ার সময় লক রিসেট করা (পরেরবার আনলক করতে হবে)
      if (settings.isPinLockEnabled) {
        setState(() => _isUnlocked = false);
      }
      // Auto-backup সক্রিয় থাকলে নিঃশব্দে স্থানীয় ব্যাকআপ নেওয়া
      if (settings.isAutoBackupEnabled) {
        BackupService.instance.saveBackupLocally();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // প্রথমবার লোড হওয়ার সময় লক দরকার কিনা ঠিক করা
    if (!_hasCheckedInitialLock) {
      _hasCheckedInitialLock = true;
      _isUnlocked = !settings.isPinLockEnabled;
    }

    final needsLock = settings.isPinLockEnabled && !_isUnlocked;

    return needsLock
        ? LockScreen(onUnlocked: () => setState(() => _isUnlocked = true))
        : const HomeShell();
  }
}
