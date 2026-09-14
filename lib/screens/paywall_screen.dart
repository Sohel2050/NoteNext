import 'package:flutter/material.dart';

import '../services/purchase_service.dart';

/// Monthly/Yearly সাবস্ক্রিপশন কেনার পেওয়াল স্ক্রিন — RevenueCat
/// (`purchases_flutter`) ব্যবহার করে (scanner অ্যাপের কাজ-করা
/// PaywallScreen-এর প্যাটার্ন অনুসরণ করে বাংলায় অ্যাডাপ্ট করা)।
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final PurchaseService _purchases = PurchaseService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _purchases.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _buy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthlyProduct = _purchases.productFor(PurchaseService.proMonthlyId);
    final yearlyProduct = _purchases.productFor(PurchaseService.proYearlyId);

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: _purchases.isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_purchases.isAvailable
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'এই মুহূর্তে এই ডিভাইসে In-app purchase উপলব্ধ নেই।',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_purchases.shouldHideAds)
                        Card(
                          color: Colors.green.withValues(alpha: 0.1),
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'আপনার Premium সক্রিয় — এই অ্যাকাউন্টে Ads বন্ধ আছে।',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Icon(Icons.workspace_premium,
                          size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Premium নিন',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ads বন্ধ করুন — Monthly অথবা Yearly প্ল্যান বেছে নিন।',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),

                      if (yearlyProduct != null)
                        _PlanCard(
                          title: 'Yearly',
                          price: yearlyProduct.priceString,
                          badge: 'Best Value',
                          highlighted: true,
                          busy: _busy,
                          onTap: () => _buy(() =>
                              _purchases.buySubscription(PurchaseService.proYearlyId)),
                        ),
                      if (monthlyProduct != null) ...[
                        const SizedBox(height: 12),
                        _PlanCard(
                          title: 'Monthly',
                          price: monthlyProduct.priceString,
                          busy: _busy,
                          onTap: () => _buy(() => _purchases
                              .buySubscription(PurchaseService.proMonthlyId)),
                        ),
                      ],
                      if (monthlyProduct == null && yearlyProduct == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'এখনো কোনো প্ল্যান লোড হয়নি — Play Console-এ Subscription '
                            'Product ID (app_config.dart এ যা বসানো তার সাথে মেলে '
                            'কিনা) ঠিক আছে কিনা দেখুন।',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed:
                            _busy ? null : () => _buy(_purchases.restorePurchases),
                        child: const Text('আগের কেনা সাবস্ক্রিপশন ফিরিয়ে আনুন'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String price;
  final String? badge;
  final bool highlighted;
  final bool busy;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    this.subtitle,
    this.badge,
    this.highlighted = false,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: highlighted ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlighted
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
