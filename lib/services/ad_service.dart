import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../config/app_config.dart';

/// Unity LevelPlay মিডিয়েশন — অফিসিয়াল `unity_levelplay_mediation`
/// Flutter প্লাগিন দিয়ে (কোনো কাস্টম নেটিভ Kotlin কোড নেই, pure Dart API)।
///
/// Capping লজিক (কখন Interstitial দেখানো হবে) এখানেই — Notes/Tasks
/// প্রোভাইডার থেকে প্রতিটা সেভের পর [registerSave] কল হয়:
///  - প্রতি ৩টা সেভে একবার Interstitial
///  - দেখানোর পর পরের ৬০ মিনিট আর দেখাবে না
class AdService with LevelPlayInitListener, LevelPlayInterstitialAdListener {
  AdService._();
  static final AdService instance = AdService._();

  late final LevelPlayInterstitialAd _interstitialAd = LevelPlayInterstitialAd(
    adUnitId: AppConfig.interstitialAdUnitId,
  );

  bool _initialized = false;
  bool _isPremium = false;
  bool _interstitialReady = false;

  int _saveCounter = 0;
  DateTime? _lastInterstitialShownAt;

  void setPremium(bool isPremium) {
    _isPremium = isPremium;
  }

  bool get isPremium => _isPremium;
  bool get adsEnabled => AppConfig.enableAds && !_isPremium;

  /// অ্যাপ শুরুতে একবার কল করতে হবে (main.dart এ)।
  Future<void> initialize() async {
    if (_initialized || !adsEnabled) return;
    try {
      final initRequest = LevelPlayInitRequest.builder(AppConfig.levelPlayAppKey).build();
      await LevelPlay.init(initRequest: initRequest, initListener: this);

      _interstitialAd.setListener(this);
      _initialized = true;
    } on PlatformException catch (e) {
      debugPrint('AdService.initialize failed: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------
  // LevelPlayInitListener
  // ---------------------------------------------------------------------

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    // ইনিশিয়ালাইজেশন সফল হলে প্রথম ইন্টারস্টিশিয়াল আগে থেকেই লোড করে রাখি।
    _interstitialAd.loadAd();
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    debugPrint('AdService: LevelPlay init failed — ${error.errorMessage}');
  }

  // ---------------------------------------------------------------------
  // LevelPlayInterstitialAdListener
  // ---------------------------------------------------------------------

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _interstitialReady = true;

  @override
  void onAdLoadFailed(LevelPlayAdError error) => _interstitialReady = false;

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {}

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    // পরের বারের জন্য আবার প্রিলোড — capping লজিক অনুযায়ী পরের শো কবে হবে
    // সেটা registerSave() ঠিক করে, এখানে শুধু ready রাখা।
    _interstitialAd.loadAd();
  }

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  // ---------------------------------------------------------------------
  // Interstitial capping (৩ সেভ → Ad → ৬০ মিনিট কুলডাউন)
  // ---------------------------------------------------------------------

  Future<void> registerSave() async {
    if (!adsEnabled || !_initialized) return;

    _saveCounter++;
    if (_saveCounter < AppConfig.interstitialSaveThreshold) return;

    _saveCounter = 0; // থ্রেশহোল্ডে পৌঁছালেই রিসেট, শো হোক বা না হোক

    final cooldownPassed = _lastInterstitialShownAt == null ||
        DateTime.now().difference(_lastInterstitialShownAt!).inMinutes >=
            AppConfig.interstitialCooldownMinutes;

    if (!cooldownPassed) {
      debugPrint('AdService: interstitial skipped (cooldown active)');
      return;
    }

    if (_interstitialReady && await _interstitialAd.isAdReady()) {
      _interstitialAd.showAd();
      _lastInterstitialShownAt = DateTime.now();
    } else {
      debugPrint('AdService: interstitial not ready, skipping this cycle');
      _interstitialAd.loadAd();
    }
  }

  @visibleForTesting
  void resetCappingState() {
    _saveCounter = 0;
    _lastInterstitialShownAt = null;
  }
}
