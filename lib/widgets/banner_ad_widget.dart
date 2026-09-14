import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../config/app_config.dart';
import '../services/ad_service.dart';

/// Notes/Tasks হোম স্ক্রিনের নিচে সবসময় বসানোর জন্য ব্যানার widget —
/// অফিসিয়াল `LevelPlayBannerAdView` (unity_levelplay_mediation প্লাগিন)।
///
/// প্রিমিয়াম ইউজারদের জন্য কিছুই রেন্ডার করে না।
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget>
    with LevelPlayBannerAdViewListener {
  final GlobalKey<LevelPlayBannerAdViewState> _bannerKey =
      GlobalKey<LevelPlayBannerAdViewState>();

  @override
  Widget build(BuildContext context) {
    if (!AdService.instance.adsEnabled) return const SizedBox.shrink();

    return SizedBox(
      height: 60,
      width: double.infinity,
      child: LevelPlayBannerAdView(
        key: _bannerKey,
        adUnitId: AppConfig.bannerAdUnitId,
        adSize: LevelPlayAdSize.BANNER,
        listener: this,
        onPlatformViewCreated: () {
          _bannerKey.currentState?.loadAd();
        },
      ),
    );
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLoadFailed(LevelPlayAdError error) {}

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {}

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
