/// أرقام غربية بفاصل آلاف (1,500,000) كما هو شائع في أسواق اليمن.
String formatNumber(num value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final negative = parts[0].startsWith('-');
  final digits = negative ? parts[0].substring(1) : parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final whole = '${negative ? '-' : ''}$buffer';
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

const Map<String, String> _currencySymbols = {
  'YER': 'ر.ي',
  'SAR': 'ر.س',
  'USD': '\$',
};

String currencySymbol(String code) => _currencySymbols[code] ?? code;

String formatMoney(num amount, String currency) {
  final decimals = amount % 1 == 0 ? 0 : 2;
  return '${formatNumber(amount, decimals: decimals)} ${currencySymbol(currency)}';
}

/// اليمن على UTC+3 طوال العام (بلا توقيت صيفي).
DateTime toYemenTime(DateTime time) =>
    time.toUtc().add(const Duration(hours: 3));

String formatYemenDateTime(DateTime time) {
  final t = toYemenTime(time);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// شارة "جديد" لأقل من 48 ساعة.
bool isNewListing(DateTime? publishedAt, DateTime createdAt, {DateTime? now}) {
  final reference = publishedAt ?? createdAt;
  final current = now ?? DateTime.now();
  return current.difference(reference) < const Duration(hours: 48);
}
