const String kDefaultCountryCode = '+967';

final RegExp _e164 = RegExp(r'^\+[1-9][0-9]{7,14}$');
final RegExp _yemen = RegExp(r'^\+967[0-9]{7,9}$');
final RegExp _separators = RegExp(
  r'[\s\-\(\)\.\u200B-\u200F\u202A-\u202E\u2060\uFEFF]',
);

String _westernDigits(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final out = StringBuffer();
  for (final ch in input.split('')) {
    var i = arabic.indexOf(ch);
    if (i < 0) i = persian.indexOf(ch);
    out.write(i >= 0 ? '$i' : ch);
  }
  return out.toString();
}

/// يحوّل مدخل المستخدم إلى صيغة دولية E.164، أو null إن كان غير صالح.
/// يقبل: 777123456 / 0777123456 / +967777123456 / 00967777123456 / 967777123456
/// وأرقاماً دولية أخرى تبدأ بـ + أو 00.
String? normalizePhone(String input, {String countryCode = kDefaultCountryCode}) {
  var s = _westernDigits(input).replaceAll(_separators, '');
  if (s.isEmpty) return null;

  if (s.startsWith('00')) {
    s = '+${s.substring(2)}';
  } else if (!s.startsWith('+')) {
    final ccDigits = countryCode.substring(1);
    if (s.startsWith(ccDigits) && s.length >= ccDigits.length + 7) {
      s = '+$s';
    } else {
      s = '$countryCode${s.replaceFirst(RegExp(r'^0+'), '')}';
    }
  }

  if (!_e164.hasMatch(s)) return null;
  if (s.startsWith('+967') && !_yemen.hasMatch(s)) return null;
  return s;
}
