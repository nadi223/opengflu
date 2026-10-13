# Open Gate

سوق اليمن: عام، عقارات، سيارات، مزادات. Flutter + Supabase، يُبنى عبر GitHub Actions.

> الحالة: **المرحلة 0** (هيكل + CI). لم يُشغَّل أي أمر Flutter أثناء كتابة هذا الكود،
> فالتحقق الأول يحدث في GitHub Actions.

## 1) إعداد القاعدة (مرة واحدة)

1. في Supabase: SQL Editor، شغّل `open_gate_schema.sql` (إن لم تكن شغّلته).
2. ثم شغّل `db_patches.sql` (على مشروع تجريبي أولاً). إن ظهر خطأ ألصقه لي.
3. Storage: تأكد من وجود bucket باسم `listing-images` (عام).
4. Authentication ← Providers ← Email: فعّله. وفي Password: اجعل الحد الأدنى 8 أحرف.
5. لا تضع مفتاح `service_role` في التطبيق أو GitHub أبداً. المفتاح العام `anon` فقط.

## 2) رفع المشروع إلى GitHub (من الهاتف يكفي)

1. أنشئ مستودعاً **خاصاً** جديداً.
2. من الموقع: Add file ← Upload files، وارفع كل محتويات هذا المجلد (ملفات `.github` مهمة).
3. Settings ← Secrets and variables ← Actions ← New repository secret:
   - `SUPABASE_URL` = رابط المشروع
   - `SUPABASE_ANON_KEY` = المفتاح العام (anon / publishable)
4. Settings ← Actions ← General ← Workflow permissions: اختر **Read and write permissions**.

## 3) أول بناء

1. تبويب Actions ← **Bootstrap Android** ← Run workflow (ينشئ مجلد android).
2. ثم **Format** ← Run workflow (ينسّق الكود ويثبّت pubspec.lock).
3. ثم **CI** ← Run workflow. عند الفشل ألصق لي سطور الخطأ الحمراء من الخطوة الفاشلة.
4. عند النجاح: افتح تشغيل CI ← Artifacts ← `open-gate-debug-apk` ← نزّله وثبّته على هاتفك.

> التشغيلات التي تبدأها workflows (Bootstrap/Format) لا تُشغّل CI تلقائياً (قيد GitHub)،
> لذلك شغّل CI يدوياً كما في الخطوة 3.

## 4) الخطوط (Cairo)

الخطوط تُضمَّن في الحزمة ولا تُحمَّل وقت التشغيل. نزّل Cairo من fonts.google.com
(ترخيص OFL) وضع `Cairo-Regular.ttf` و`Cairo-Bold.ttf` في `assets/fonts/`
ثم أزل التعليق عن قسم `fonts` في `pubspec.yaml`. حتى ذلك الحين يستخدم التطبيق خط النظام.

## 5) المراحل

| # | المرحلة | الحالة |
|---|---|---|
| 0 | الهيكل + CI | هذا التسليم |
| 1 | المصادقة (بريد أو هاتف) + الرئيسية الحية | قادمة |
| 2 | الإعلانات والنشر | قادمة |
| 3 | الدردشة والمزادات | قادمة |
| 4 | لوحة المالك | قادمة |
| 5 | release.yml + التوقيع + صقل | قادمة |
