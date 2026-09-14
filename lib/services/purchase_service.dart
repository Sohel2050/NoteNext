import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'ad_service.dart';

/// Google Play (এবং App Store)-এর সব in-app purchase হ্যান্ডেল করে
/// RevenueCat-এর `purchases_flutter` SDK দিয়ে — এটা Android-এ ভেতরে
/// Google Play Billing Library 8.3.0 ব্যবহার করে, Google-এর Aug 31,
/// 2026 রিকোয়ারমেন্ট (সব অ্যাপে Billing Library 8+ থাকতে হবে) মেটাতে।
///
/// (অফিসিয়াল Flutter `in_app_purchase` প্লাগিন এখনো Billing Library 8
/// সাপোর্ট করে না, তাই RevenueCat ব্যবহার করা হয়েছে।)
///
/// এটা আপনার কাজ-করা "scanner" অ্যাপের `PurchaseService`-এর প্যাটার্ন
/// হুবহু অনুসরণ করে লেখা।
///
/// বিক্রি হওয়া প্রোডাক্ট:
///  - Pro Monthly (auto-renewing subscription)
///  - Pro Yearly (auto-renewing subscription)
class PurchaseService {
  PurchaseService._internal();
  static final PurchaseService instance = PurchaseService._internal();

  // ========== 🔑 REVENUECAT API KEY — এখানে আপনার RevenueCat public SDK key বসান ==========
  // (RevenueCat ড্যাশবোর্ডে Project settings > API Keys — Google/Android
  // আর Apple/iOS কী আলাদা)
  static const String _revenueCatAndroidApiKey = 'YOUR_REVENUECAT_ANDROID_API_KEY'; // <-- এখানে আপনার Android RevenueCat key দিন
  static const String _revenueCatIosApiKey = 'YOUR_REVENUECAT_IOS_API_KEY';         // <-- এখানে আপনার iOS RevenueCat key দিন

  // ========== 🛒 PRODUCT IDS — Google Play Console > Monetize > Products এ ==========
  // ========== যা তৈরি করেছেন তার সাথে মিলতে হবে, তারপর RevenueCat-এ    ==========
  // ========== Offerings/Entitlements-এ অ্যাটাচ করতে হবে                ==========
  static const String proMonthlyId = AppConfig.monthlySubscriptionProductId;
  static const String proYearlyId = AppConfig.yearlySubscriptionProductId;

  // ========== 🏷️ ENTITLEMENT ID — RevenueCat ড্যাশবোর্ডে (Entitlements ==========
  // ========== ট্যাব) যা তৈরি করেছেন তার সাথে মিলতে হবে                 ==========
  static const String _proEntitlement = 'go_pro';

  static const String _prefsProActive = 'purchased_pro_active';

  List<Package> _packages = [];
  bool isAvailable = false;
  bool isLoading = true;

  bool _proActive = false;

  bool get isProActive => _proActive;
  /// অ্যাপের যেকোনো জায়গায় Ads বন্ধ করা উচিত কিনা।
  bool get shouldHideAds => _proActive;

  final StreamController<void> _stateController =
      StreamController<void>.broadcast();
  Stream<void> get onChange => _stateController.stream;

  /// একবার কল করতে হবে, যেমন main.dart-এ অ্যাপ শুরুর সময়।
  Future<void> initialize() async {
    await _loadCachedEntitlements();

    try {
      await Purchases.setLogLevel(LogLevel.warn);

      final apiKey =
          defaultTargetPlatform == TargetPlatform.iOS
              ? _revenueCatIosApiKey
              : _revenueCatAndroidApiKey;

      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      isAvailable = true;

      // Purchase/entitlement আপডেট শোনে (restore, renewal, cross-device
      // sync সহ)
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      await _loadOfferings();

      // এখনই কারেন্ট স্টেট সিঙ্ক করে নেয়, যদি ইতিমধ্যে entitlement থাকে
      final customerInfo = await Purchases.getCustomerInfo();
      await _applyCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('RevenueCat initialization failed: $e');
      isAvailable = false;
    }

    isLoading = false;
    _stateController.add(null);
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();

      // এই প্রজেক্টে আসল প্রোডাক্ট সবসময় "current" offering-এ নাও থাকতে
      // পারে (কিছু offering-এ শুধু Test Store placeholder প্রোডাক্ট থাকে)।
      // নিরাপদ থাকতে সব offering থেকেই package সংগ্রহ করা হয়, যাতে
      // packageFor() যে offering-এই আসল Play Store প্রোডাক্ট থাক না কেন
      // সেটা খুঁজে পায়।
      final allPackages = <Package>[];
      for (final offering in offerings.all.values) {
        allPackages.addAll(offering.availablePackages);
      }
      _packages = allPackages;

      if (offerings.current == null) {
        debugPrint('No current RevenueCat offering configured');
      }
    } catch (e) {
      debugPrint('Failed to load RevenueCat offerings: $e');
    }
  }

  /// একটা Play Console প্রোডাক্ট আইডি মোড়ানো RevenueCat package খুঁজে বের
  /// করে। এক্স্যাক্ট identifier ম্যাচ, বা Play Billing-এর base plan সহ
  /// সাবস্ক্রিপশনের "subscriptionId:basePlanId" ফরম্যাট — দুটোই মেলাতে পারে।
  Package? packageFor(String productId) {
    for (final pkg in _packages) {
      final identifier = pkg.storeProduct.identifier;
      if (identifier == productId || identifier.startsWith('$productId:')) {
        return pkg;
      }
    }
    return null;
  }

  /// paywall স্ক্রিনের সাথে API সামঞ্জস্য রাখতে — একটা প্রোডাক্ট আইডির
  /// জন্য আন্ডারলাইং StoreProduct (price, title, description) রিটার্ন করে।
  StoreProduct? productFor(String productId) {
    return packageFor(productId)?.storeProduct;
  }

  // ========== Purchase actions ==========

  Future<void> buySubscription(String subscriptionId) async {
    final pkg = packageFor(subscriptionId);
    if (pkg == null) {
      debugPrint('Subscription package not loaded yet');
      return;
    }
    await _purchasePackage(pkg);
  }

  Future<void> _purchasePackage(Package pkg) async {
    try {
      final result = await Purchases.purchasePackage(pkg);
      await _applyCustomerInfo(result.customerInfo);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Purchase failed: $errorCode');
      }
    }
  }

  /// আগের কেনা রিস্টোর করে (যেমন reinstall বা নতুন ডিভাইসের পর)।
  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      await _applyCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('Restore purchases failed: $e');
    }
  }

  // ========== Customer info / entitlement handling ==========

  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    _applyCustomerInfo(customerInfo);
  }

  Future<void> _applyCustomerInfo(CustomerInfo customerInfo) async {
    final prefs = await SharedPreferences.getInstance();

    final proActive =
        customerInfo.entitlements.active.containsKey(_proEntitlement);

    _proActive = proActive;

    await prefs.setBool(_prefsProActive, proActive);

    // notenext-এ AdService-কে প্রিমিয়াম স্ট্যাটাস জানিয়ে দেয়, যাতে Ads
    // সাথে সাথে বন্ধ হয়ে যায়।
    AdService.instance.setPremium(proActive);

    _stateController.add(null);
  }

  Future<void> _loadCachedEntitlements() async {
    final prefs = await SharedPreferences.getInstance();
    _proActive = prefs.getBool(_prefsProActive) ?? false;
    AdService.instance.setPremium(_proActive);
  }

  /// শুধু ডিবাগ/টেস্টিং-এর জন্য — প্রোডাকশনে ইউজারকে ফ্রিতে entitlement
  /// নেওয়ার উপায় দেবেন না। প্রোডাকশনে এটা সরিয়ে ফেলুন বা গার্ড করুন।
  @visibleForTesting
  Future<void> debugResetEntitlements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsProActive);
    _proActive = false;
    AdService.instance.setPremium(false);
    _stateController.add(null);
  }

  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
    _stateController.close();
  }
}
