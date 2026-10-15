num? _num(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<T> parseRows<T>(Object json, T Function(Map<String, dynamic>) from) {
  return (json as List)
      .map((e) => from(Map<String, dynamic>.from(e as Map)))
      .toList();
}

class PlatformInfo {
  const PlatformInfo({
    required this.id,
    required this.key,
    required this.nameAr,
    this.nameEn,
    this.descriptionAr,
    this.icon,
    this.bannerUrl,
    this.isAuctionPlatform = false,
  });

  final String id;
  final String key;
  final String nameAr;
  final String? nameEn;
  final String? descriptionAr;
  final String? icon;
  final String? bannerUrl;
  final bool isAuctionPlatform;

  factory PlatformInfo.fromJson(Map<String, dynamic> j) => PlatformInfo(
    id: j['id'] as String,
    key: j['key'] as String,
    nameAr: j['name_ar'] as String,
    nameEn: j['name_en'] as String?,
    descriptionAr: j['description_ar'] as String?,
    icon: j['icon'] as String?,
    bannerUrl: j['banner_url'] as String?,
    isAuctionPlatform: (j['is_auction_platform'] as bool?) ?? false,
  );
}

class Sponsor {
  const Sponsor({required this.id, required this.textAr});

  final String id;
  final String textAr;

  factory Sponsor.fromJson(Map<String, dynamic> j) =>
      Sponsor(id: j['id'] as String, textAr: j['text_ar'] as String);
}

class ExchangeRate {
  const ExchangeRate({
    required this.city,
    required this.currency,
    required this.rate,
    this.updatedAt,
  });

  final String city;
  final String currency;
  final num rate;
  final DateTime? updatedAt;

  factory ExchangeRate.fromJson(Map<String, dynamic> j) => ExchangeRate(
    city: j['city'] as String,
    currency: j['currency'] as String,
    rate: _num(j['rate_to_yer']) ?? 0,
    updatedAt: _date(j['updated_at']),
  );
}

class SocialLink {
  const SocialLink({
    required this.key,
    required this.labelAr,
    required this.value,
  });

  final String key;
  final String labelAr;
  final String value;

  factory SocialLink.fromJson(Map<String, dynamic> j) => SocialLink(
    key: j['key'] as String,
    labelAr: j['label_ar'] as String,
    value: (j['value'] as String?) ?? '',
  );
}

class LatestListing {
  const LatestListing({
    required this.id,
    required this.title,
    required this.currency,
    required this.createdAt,
    this.price,
    this.city,
    this.publishedAt,
    this.imageUrls = const [],
  });

  final String id;
  final String title;
  final num? price;
  final String currency;
  final String? city;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final List<String> imageUrls;

  factory LatestListing.fromJson(Map<String, dynamic> j) {
    final images =
        <Map<String, dynamic>>[
          for (final e in (j['listing_images'] as List?) ?? const [])
            Map<String, dynamic>.from(e as Map),
        ]..sort(
          (a, b) => (_num(a['sort_order']) ?? 0).compareTo(
            _num(b['sort_order']) ?? 0,
          ),
        );
    return LatestListing(
      id: j['id'] as String,
      title: j['title'] as String,
      price: _num(j['price']),
      currency: (j['currency'] as String?) ?? 'YER',
      city: j['city'] as String?,
      publishedAt: _date(j['published_at']),
      createdAt: DateTime.parse(j['created_at'] as String),
      imageUrls: [for (final i in images) i['url'] as String],
    );
  }
}

/// إعدادات عامة من الجدول app_config (قيم غير سرّية).
class AppConfig {
  const AppConfig(this.raw);

  final Map<String, dynamic> raw;

  bool get phoneAuthEnabled => raw['phone_auth_enabled'] == true;

  String get defaultCountryCode =>
      (raw['default_country_code'] as String?) ?? '+967';
}
