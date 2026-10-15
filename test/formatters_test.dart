import 'package:flutter_test/flutter_test.dart';
import 'package:open_gate/core/format/formatters.dart';

void main() {
  test('formatNumber يضع فاصل الآلاف بأرقام غربية', () {
    expect(formatNumber(0), '0');
    expect(formatNumber(999), '999');
    expect(formatNumber(1500000), '1,500,000');
    expect(formatNumber(1234.5, decimals: 2), '1,234.50');
    expect(formatNumber(-12345), '-12,345');
  });

  test('formatMoney للريال اليمني والدولار', () {
    expect(formatMoney(250000, 'YER'), '250,000 ر.ي');
    expect(formatMoney(12.5, 'USD'), '12.50 \$');
    expect(formatMoney(100, 'SAR'), '100 ر.س');
  });

  test('توقيت اليمن UTC+3', () {
    final utc = DateTime.utc(2026, 10, 16, 21, 5);
    expect(formatYemenDateTime(utc), '2026/10/17 00:05');
  });

  test('شارة جديد لأقل من 48 ساعة', () {
    final now = DateTime.utc(2026, 10, 16, 12);
    expect(isNewListing(now.subtract(const Duration(hours: 47)), now, now: now), true);
    expect(isNewListing(now.subtract(const Duration(hours: 49)), now, now: now), false);
    expect(isNewListing(null, now.subtract(const Duration(hours: 1)), now: now), true);
  });
}
