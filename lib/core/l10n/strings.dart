import 'package:flutter/widgets.dart';

const Map<String, String> _ar = {
  'app_name': 'Open Gate',
  'welcome_title': 'مرحباً بك في Open Gate',
  'welcome_sub': 'سوقك الأول في اليمن: بيع واشترِ، عقارات وسيارات ومزادات',
  'start': 'ابدأ التصفح',
  'home_placeholder': 'الرئيسية قيد البناء',
  'settings': 'الإعدادات',
  'theme': 'المظهر',
  'theme_dark': 'داكن',
  'theme_light': 'فاتح',
  'theme_system': 'حسب الجهاز',
  'grid_columns': 'عدد أعمدة الإعلانات',
  'notifications': 'تفعيل الإشعارات',
  'language': 'اللغة',
  'arabic': 'العربية',
  'english': 'English',
  'offline_banner': 'لا يوجد اتصال بالإنترنت حالياً',
  'startup_failed': 'تعذّر تشغيل التطبيق، حاول لاحقاً',
  'not_found': 'الصفحة غير موجودة',
  'back_home': 'العودة للرئيسية',
};

const Map<String, String> _en = {
  'app_name': 'Open Gate',
  'welcome_title': 'Welcome to Open Gate',
  'welcome_sub':
      'Your marketplace in Yemen: general, real estate, cars, auctions',
  'start': 'Start browsing',
  'home_placeholder': 'Home is under construction',
  'settings': 'Settings',
  'theme': 'Appearance',
  'theme_dark': 'Dark',
  'theme_light': 'Light',
  'theme_system': 'System',
  'grid_columns': 'Listing grid columns',
  'notifications': 'Enable notifications',
  'language': 'Language',
  'arabic': 'العربية',
  'english': 'English',
  'offline_banner': 'No internet connection right now',
  'startup_failed': 'Could not start the app, please try later',
  'not_found': 'Page not found',
  'back_home': 'Back to home',
};

extension TrContext on BuildContext {
  String tr(String key) {
    final code = Localizations.localeOf(this).languageCode;
    final map = code == 'en' ? _en : _ar;
    return map[key] ?? _ar[key] ?? key;
  }
}
