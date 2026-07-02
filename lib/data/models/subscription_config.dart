// ---------------------------------------------------------------------------
// SubscriptionConfig — /config/subscription doc shape.
//
// Drives the in-app Upgrade-to-Premium card: title, feature bullets, monthly
// price (BDT), and the formatted CTA copy. Admins edit /config/subscription in
// Firebase Console; clients hot-reload via remoteConfigServiceProvider.
//
// Pricing source of truth lives on Stripe (price_... in functions/.env). This
// doc only drives display — the actual checkout uses the Stripe price ID, so
// changing the number here without updating Stripe will mislead the user.
// Mirror updates in both places.
// ---------------------------------------------------------------------------

class SubscriptionConfig {
  /// Monthly price in BDT (Bangladeshi taka), as displayed on the upgrade CTA.
  final int monthlyPriceBdt;

  /// Currency symbol prefix for the price display (e.g. "৳", "$").
  final String currencySymbol;

  /// Feature bullets shown on the upgrade card.
  final List<String> features;

  /// Headline shown above the bullets.
  final String headline;

  /// Button label format. `{price}` placeholder is substituted with
  /// `{currencySymbol}{monthlyPriceBdt}`. Example: "Upgrade Now — {price}/month".
  final String ctaLabelFormat;

  const SubscriptionConfig({
    required this.monthlyPriceBdt,
    required this.currencySymbol,
    required this.features,
    required this.headline,
    required this.ctaLabelFormat,
  });

  /// Fully resolved CTA button label with the price interpolated.
  String get ctaLabel => ctaLabelFormat.replaceAll(
        '{price}',
        '$currencySymbol$monthlyPriceBdt',
      );

  factory SubscriptionConfig.fromMap(Map<String, dynamic> data) =>
      SubscriptionConfig(
        monthlyPriceBdt: (data['monthlyPriceBdt'] as num?)?.toInt() ??
            defaults.monthlyPriceBdt,
        currencySymbol:
            (data['currencySymbol'] as String?) ?? defaults.currencySymbol,
        features: data['features'] == null
            ? defaults.features
            : (data['features'] as List)
                .map((e) => e.toString())
                .toList(growable: false),
        headline: (data['headline'] as String?) ?? defaults.headline,
        ctaLabelFormat:
            (data['ctaLabelFormat'] as String?) ?? defaults.ctaLabelFormat,
      );

  Map<String, dynamic> toMap() => {
        'monthlyPriceBdt': monthlyPriceBdt,
        'currencySymbol': currencySymbol,
        'features': features,
        'headline': headline,
        'ctaLabelFormat': ctaLabelFormat,
      };

  static const SubscriptionConfig defaults = SubscriptionConfig(
    monthlyPriceBdt: 299,
    currencySymbol: '৳',
    headline: 'Upgrade to Premium 🚀',
    features: [
      'Unlimited AI tutoring',
      'Diagram upload & analysis',
      'Full chat history search',
      'Advanced analytics',
    ],
    ctaLabelFormat: 'Upgrade Now',
  );
}
