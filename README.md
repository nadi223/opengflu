# Open Gate

سوق اليمن: عام، عقارات، سيارات، مزادات. Flutter + Supabase، يُبنى عبر GitHub Actions.

> الحالة: **المرحلة 1** (المصادقة + الرئيسية الحية). لم يُشغَّل أي أمر Flutter أثناء كتابة هذا الكود،
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
| 0 | الهيكل + CI | منجزة ومثبّتة على الهاتف |
| 1 | المصادقة (بريد أو هاتف) + الرئيسية الحية | هذا التسليم |
| 2 | الإعلانات والنشر | قادمة |
| 3 | الدردشة والمزادات | قادمة |
| 4 | لوحة المالك | قادمة |
| 5 | release.yml + التوقيع + صقل | قادمة |

## 6) المرحلة 1: ما الجديد وكيف تختبره يدوياً

بعد رفع الملفات: Actions ← **Format** ← **CI** ← **Size Check**، ثم ثبّت ملف arm64 أو armeabi-v7a.

اختبر على الهاتف بالترتيب:
1. **الرئيسية:** يظهر الشريط الذهبي المتحرك (إن وُجدت عناصر مرئية في `featured_sponsors`)،
   وأسعار الصرف لصنعاء وعدن، وبطاقات أحدث الإعلانات، وشبكة المنصات الأربع.
2. **الوضع بلا إنترنت:** افتح التطبيق مرة بإنترنت ثم أغلقه وأطفئ الإنترنت وافتحه:
   يجب أن ترى نفس البيانات وشريطاً أحمر بالأعلى بلا أي تفاصيل تقنية.
3. **القائمة الجانبية:** الضغط على أيقونة القائمة. "لوحة المالك" لا تظهر إلا لحساب أُضيف مسؤولاً.
4. **التسجيل بالبريد:** إنشاء حساب برقم هاتف اختياري. إن كان "تأكيد البريد" مفعّلاً ستظهر رسالة
   لتأكيد بريدك ثم تسجّل الدخول. بعد الدخول تحقق من Supabase ← Table editor ← profiles أن الصف أُنشئ
   وأن الهاتف حُفظ بصيغة `+967...`.
5. **زائر ثم إجراء يحتاج حساباً:** من القائمة اختر "إضافة إعلان" وأنت غير مسجّل: يجب أن تفتح شاشة الدخول.
6. **المزادات المباشرة:** البانر الأحمر يظهر فقط إن وُجد مزاد حالته live ولم ينتهِ.

### تفعيل التسجيل بالهاتف
مغلق افتراضياً. لا تفعّله قبل ضبط مزوّد SMS في Supabase ← Authentication ← Providers ← Phone.
ثم شغّل في SQL Editor:

    update public.app_config set value = 'true'::jsonb where key = 'phone_auth_enabled';

### أيقونات المنصات (اختياري)
الأيقونة نص من القاعدة (إيموجي مثلاً). إن تركتها فارغة تُعرض أول حرف من الاسم:

    update public.platforms set icon = '🛒' where key = 'marketplace';
    update public.platforms set icon = '🏠' where key = 'real_estate';
    update public.platforms set icon = '🚗' where key = 'cars';
    update public.platforms set icon = '🔨' where key = 'auctions';

### شريط الرعاة وروابط التواصل
    insert into public.featured_sponsors (text_ar, sort_order) values ('معرض النخبة للسيارات - صنعاء', 1);
    update public.social_links set value = 'opengate', is_visible = true where key = 'instagram';
