import 'package:flutter_test/flutter_test.dart';
import 'package:open_gate/features/home/data/social_url.dart';

void main() {
  test('يبني روابط المنصات من اسم الحساب', () {
    expect(socialUri('instagram', '@opengate').toString(), 'https://instagram.com/opengate');
    expect(socialUri('tiktok', 'opengate').toString(), 'https://tiktok.com/@opengate');
    expect(socialUri('whatsapp', '+967 777 123 456').toString(), 'https://wa.me/967777123456');
    expect(socialUri('website', 'example.com').toString(), 'https://example.com');
  });

  test('يرفض المخططات الخطرة والقيم الفارغة', () {
    expect(socialUri('website', 'javascript:alert(1)'), isNull);
    expect(socialUri('instagram', ''), isNull);
    expect(socialUri('x', 'ftp://example.com'), isNull);
  });

  test('يقبل الروابط الكاملة http/https', () {
    expect(socialUri('x', 'https://x.com/opengate').toString(), 'https://x.com/opengate');
  });
}
