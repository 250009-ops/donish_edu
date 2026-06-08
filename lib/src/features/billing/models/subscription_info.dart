class SubscriptionLimits {
  const SubscriptionLimits({
    required this.maxDevices,
    required this.freeMaxMaterials,
    required this.freeMaxTranslateTotal,
    required this.premiumFairUseTranslatePerDay,
  });

  final int maxDevices;
  final int freeMaxMaterials;
  final int freeMaxTranslateTotal;
  final int premiumFairUseTranslatePerDay;

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) {
    return SubscriptionLimits(
      maxDevices: _int(json['max_devices'], fallback: 3),
      freeMaxMaterials: _int(json['free_max_materials'], fallback: 1),
      freeMaxTranslateTotal: _int(json['free_max_translate_total'], fallback: 5),
      premiumFairUseTranslatePerDay:
          _int(json['premium_fair_use_translate_per_day'], fallback: 500),
    );
  }
}

class SubscriptionUsage {
  const SubscriptionUsage({
    required this.materialsCount,
    required this.devicesCount,
    required this.translateTotal,
  });

  final int materialsCount;
  final int devicesCount;
  final int translateTotal;

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) {
    return SubscriptionUsage(
      materialsCount: _int(json['materials_count']),
      devicesCount: _int(json['devices_count']),
      translateTotal: _int(json['translate_total']),
    );
  }
}

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.plan,
    required this.isPremium,
    required this.billingEnabled,
    required this.priceUzs,
    required this.limits,
    required this.usage,
    this.renewsAt,
    this.premiumUntil,
    this.subscriptionStatus,
  });

  final String plan;
  final bool isPremium;
  final bool billingEnabled;
  final int priceUzs;
  final SubscriptionLimits limits;
  final SubscriptionUsage usage;
  final String? renewsAt;
  final String? premiumUntil;
  final String? subscriptionStatus;

  bool get isFree => !isPremium;

  int get materialsRemainingOnFree =>
      (limits.freeMaxMaterials - usage.materialsCount)
          .clamp(0, limits.freeMaxMaterials);

  int get translateRemainingOnFree =>
      (limits.freeMaxTranslateTotal - usage.translateTotal)
          .clamp(0, limits.freeMaxTranslateTotal);

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      plan: json['plan'] as String? ?? 'free',
      isPremium: json['is_premium'] == true,
      billingEnabled: json['billing_enabled'] == true,
      priceUzs: _int(json['price_uzs'], fallback: 56000),
      limits: SubscriptionLimits.fromJson(
        json['limits'] as Map<String, dynamic>? ?? const {},
      ),
      usage: SubscriptionUsage.fromJson(
        json['usage'] as Map<String, dynamic>? ?? const {},
      ),
      renewsAt: json['renews_at'] as String?,
      premiumUntil: json['premium_until'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
    );
  }

  static SubscriptionInfo freeDefaults() {
    return SubscriptionInfo.fromJson(const {
      'plan': 'free',
      'is_premium': false,
      'billing_enabled': false,
      'price_uzs': 56000,
      'limits': {
        'max_devices': 3,
        'free_max_materials': 1,
        'free_max_translate_total': 5,
        'premium_fair_use_translate_per_day': 500,
      },
      'usage': {
        'materials_count': 0,
        'devices_count': 0,
        'translate_total': 0,
      },
    });
  }
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
