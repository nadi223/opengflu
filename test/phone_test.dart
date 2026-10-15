import 'package:flutter_test/flutter_test.dart';
import 'package:open_gate/core/format/phone.dart';

void main() {
  group('normalizePhone (اليمن)', () {
    test('يقبل الصيغ الشائعة', () {
      expect(normalizePhone('777123456'), '+967777123456');
      expect(normalizePhone('0777123456'), '+967777123456');
      expect(normalizePhone('+967777123456'), '+967777123456');
      expect(normalizePhone('00967777123456'), '+967777123456');
      expect(normalizePhone('967777123456'), '+967777123456');
      expect(normalizePhone('777 123 456'), '+967777123456');
    });

    test('يحوّل الأرقام العربية', () {
      expect(normalizePhone('٠٧٧٧١٢٣٤٥٦'), '+967777123456');
    });

    test('يقبل أرقاماً دولية أخرى', () {
      expect(normalizePhone('+966501234567'), '+966501234567');
    });

    test('يرفض غير الصالح', () {
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('12'), isNull);
      expect(normalizePhone('abc'), isNull);
      expect(normalizePhone('+967123'), isNull);
    });
  });
}
