/// يبني رابطاً آمناً (http/https فقط) من قيمة حساب التواصل.
final RegExp _handleChars = RegExp(r'^[A-Za-z0-9._\-]+$');

Uri? socialUri(String key, String rawValue) {
  final v = rawValue.trim();
  if (v.isEmpty) return null;

  final lower = v.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return _safe(Uri.tryParse(v));
  }

  if (key == 'whatsapp') {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : Uri.https('wa.me', '/$digits');
  }

  if (key == 'website') {
    final uri = Uri.tryParse('https://$v');
    final ok = uri != null && uri.host.contains('.');
    return ok ? _safe(uri) : null;
  }

  // بقية المنصات: اسم حساب فقط (حروف وأرقام ونقطة وشرطة).
  final handle = v.replaceFirst(RegExp(r'^@'), '');
  if (!_handleChars.hasMatch(handle)) return null;

  switch (key) {
    case 'instagram':
      return Uri.https('instagram.com', '/$handle');
    case 'x':
      return Uri.https('x.com', '/$handle');
    case 'snapchat':
      return Uri.https('snapchat.com', '/add/$handle');
    case 'tiktok':
      return Uri.https('tiktok.com', '/@$handle');
    default:
      return null;
  }
}

Uri? _safe(Uri? uri) {
  if (uri == null) return null;
  final ok =
      (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  return ok ? uri : null;
}
