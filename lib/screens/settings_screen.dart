import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/settings_model.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/security_service.dart';
import '../services/sync_service.dart';
import 'paywall_screen.dart';
import '../utils/app_theme.dart';
import '../utils/color_utils.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isBackingUp = false;
  bool _isSyncing = false;
  String? _syncMessage;

  Future<void> _signIn() async {
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('সাইন-ইন ব্যর্থ হয়েছে: $e')));
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
  }

  Future<void> _runSync() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });
    try {
      await SyncService.instance.fullSync(
        onProgress: (msg) {
          if (mounted) setState(() => _syncMessage = msg);
        },
      );
      await ref.read(settingsProvider.notifier).markSyncCompleted();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('সিঙ্ক সম্পন্ন হয়েছে ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('সিঙ্ক ব্যর্থ হয়েছে: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _togglePinLock(bool enable, SettingsModel settings) async {
    if (enable) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PIN লক বন্ধ করবেন?'),
          content: const Text('অ্যাপ খোলার সময় আর PIN চাওয়া হবে না।'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('বাতিল'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('বন্ধ করুন'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(settingsProvider.notifier).clearPin();
      }
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      final available = await SecurityService.instance.isBiometricAvailable();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('এই ডিভাইসে বায়োমেট্রিক পাওয়া যায়নি')),
          );
        }
        return;
      }
      final ok = await SecurityService.instance.authenticateWithBiometrics(
        reason: 'বায়োমেট্রিক আনলক চালু করতে যাচাই করুন',
      );
      if (!ok) return;
    }
    await ref.read(settingsProvider.notifier).updateBiometric(enable);
  }

  Future<void> _toggleAutoBackup(bool enable) async {
    await ref.read(settingsProvider.notifier).updateAutoBackup(enable);
    if (enable) {
      await BackupService.instance.saveBackupLocally();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('স্বয়ংক্রিয় ব্যাকআপ চালু হয়েছে')),
        );
      }
    }
  }

  Future<void> _pickSeedColor(SettingsModel settings) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppTheme.noteColors
                .where((c) => c.value != 0xFFFFFFFF) // সাদা বাদে
                .map((c) {
              final hex = colorToHex(c);
              return GestureDetector(
                onTap: () => Navigator.pop(context, hex),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hex == settings.seedColorHex
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (result != null) {
      await ref.read(settingsProvider.notifier).updateSeedColor(result);
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isBackingUp = true);
    try {
      await BackupService.instance.exportAndShareBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ব্যাকআপ ব্যর্থ হয়েছে: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null || result.isEmpty || result.single.path == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ব্যাকআপ রিস্টোর করবেন?'),
        content: const Text(
            'ব্যাকআপ ফাইলের নোট/টাস্ক বর্তমান ডেটার সাথে মার্জ হবে (uuid মিললে আপডেট হবে)।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('রিস্টোর করুন'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final file = File(result.single.path!);
      final res = await BackupService.instance.restoreFromFile(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${res.notesRestored} টি নোট ও ${res.tasksRestored} টি টাস্ক রিস্টোর হয়েছে'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('রিস্টোর ব্যর্থ হয়েছে: $e')));
      }
    }
  }

  /// Firebase Sync চালু থাকলে "অ্যাকাউন্ট" ও "ক্লাউড সিঙ্ক" সেকশন।
  /// (ConsumerState এর `ref` সরাসরি ব্যবহার করা হচ্ছে — এই মেথড build()
  /// থেকেই কল হয়, তাই watch() ঠিকভাবে rebuild ট্রিগার করবে)
  List<Widget> _buildSyncSections(SettingsModel settings) {
    final authAsync = ref.watch(authStateProvider);

    return [
      const _SectionHeader('অ্যাকাউন্ট'),
      authAsync.when(
        data: (user) {
          if (user == null) {
            return ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Google দিয়ে সাইন-ইন করুন'),
              subtitle:
                  const Text('ডিভাইস জুড়ে সিঙ্ক করতে সাইন-ইন প্রয়োজন'),
              onTap: _signIn,
            );
          }
          return ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null ? const Icon(Icons.person) : null,
            ),
            title: Text(user.displayName ?? user.email ?? 'ব্যবহারকারী'),
            subtitle: Text(user.email ?? ''),
            trailing: TextButton(
              onPressed: _signOut,
              child: const Text('সাইন-আউট'),
            ),
          );
        },
        loading: () => const ListTile(
          leading: SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator()),
          title: Text('লোড হচ্ছে...'),
        ),
        error: (_, __) => const ListTile(
          leading: Icon(Icons.error_outline),
          title: Text('অথেন্টিকেশন এরর'),
        ),
      ),
      const _SectionHeader('ক্লাউড সিঙ্ক'),
      ListTile(
        leading: _isSyncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.cloud_sync_outlined),
        title: Text(
            _isSyncing ? (_syncMessage ?? 'সিঙ্ক হচ্ছে...') : 'এখনই সিঙ্ক করুন'),
        subtitle: settings.lastSyncAt != null
            ? Text(
                'সর্বশেষ সিঙ্ক: ${DateFormat('d MMM, h:mm a').format(settings.lastSyncAt!)}')
            : const Text('এখনো সিঙ্ক করা হয়নি'),
        onTap: _isSyncing || authAsync.value == null ? null : _runSync,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: ListView(
        children: [
          // ---------------- Premium (RevenueCat — Monthly/Yearly) ----------------
          const _SectionHeader('প্রিমিয়াম'),
          ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Text('Premium নিন — Ads বন্ধ করুন'),
            subtitle: const Text('Monthly অথবা Yearly সাবস্ক্রিপশন'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
          ),

          // ---------------- Account / Sync (শুধু AppConfig.enableFirebaseSync
          // = true থাকলে দেখানো হয়; false থাকলে অ্যাপ সম্পূর্ণ অফলাইন) ----------------
          if (AppConfig.enableFirebaseSync) ..._buildSyncSections(settings),

          // ---------------- Backup / Restore (সম্পূর্ণ লোকাল, ইন্টারনেট লাগে না) ----------------
          const _SectionHeader('ব্যাকআপ ও রিস্টোর'),
          ListTile(
            leading: _isBackingUp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined),
            title: const Text('ব্যাকআপ এক্সপোর্ট করুন (.json)'),
            subtitle: const Text('সব নোট ও টাস্ক একটা ফাইলে শেয়ার করুন'),
            onTap: _isBackingUp ? null : _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('ব্যাকআপ রিস্টোর করুন'),
            subtitle: const Text('.json ব্যাকআপ ফাইল থেকে ডেটা আনুন'),
            onTap: _restoreBackup,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.backup_outlined),
            title: const Text('স্বয়ংক্রিয় ব্যাকআপ'),
            subtitle: const Text('অ্যাপ ব্যাকগ্রাউন্ডে গেলে স্বয়ংক্রিয়ভাবে লোকাল ব্যাকআপ নেবে'),
            value: settings.isAutoBackupEnabled,
            onChanged: _toggleAutoBackup,
          ),

          // ---------------- Security ----------------
          const _SectionHeader('নিরাপত্তা'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('PIN লক'),
            subtitle: const Text('অ্যাপ খোলার সময় ৪-সংখ্যার PIN চাইবে'),
            value: settings.isPinLockEnabled,
            onChanged: (v) => _togglePinLock(v, settings),
          ),
          if (settings.isPinLockEnabled) ...[
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('PIN পরিবর্তন করুন'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PinSetupScreen()),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('ফিঙ্গারপ্রিন্ট / ফেস আনলক'),
              subtitle: const Text('PIN এর পাশাপাশি বায়োমেট্রিক দিয়েও আনলক করা যাবে'),
              value: settings.isBiometricEnabled,
              onChanged: _toggleBiometric,
            ),
          ],

          // ---------------- Appearance ----------------
          const _SectionHeader('থিম'),
          RadioListTile<AppThemeMode>(
            title: const Text('সিস্টেম অনুযায়ী'),
            value: AppThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateThemeMode(v!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('লাইট'),
            value: AppThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateThemeMode(v!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('ডার্ক'),
            value: AppThemeMode.dark,
            groupValue: settings.themeMode,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateThemeMode(v!),
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: hexToColor(settings.seedColorHex),
              radius: 12,
            ),
            title: const Text('অ্যাক্সেন্ট কালার'),
            subtitle: const Text('অ্যাপের মূল থিম রঙ পরিবর্তন করুন'),
            onTap: () => _pickSeedColor(settings),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
