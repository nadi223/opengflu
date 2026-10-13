-- ============================================================================
-- Open Gate — Supabase (PostgreSQL) Database Schema
-- تصميم قاعدة بيانات ديناميكية قابلة للتوسع بدون تعديل كود
-- ============================================================================

create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- ============================================================================
-- 1) المستخدمون والملفات الشخصية
-- ============================================================================

-- ملاحظة: auth.users يوفرها Supabase Auth تلقائياً (بريد + OAuth لاحقاً)
create type account_type as enum ('individual', 'real_estate_office', 'car_dealer', 'business');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  account_type account_type not null default 'individual',
  business_name text,              -- اسم المكتب العقاري / معرض السيارات
  business_license_no text,        -- رقم ترخيص تجاري (اختياري)
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- 2) المنصات والتصنيفات (الجزء الديناميكي الأساسي)
-- ============================================================================

create table platforms (
  id uuid primary key default uuid_generate_v4(),
  key text unique not null,               -- 'marketplace' | 'real_estate' | 'cars' | 'auctions' | ...
  name_ar text not null,
  name_en text,
  description_ar text,
  icon text,                              -- اسم أيقونة أو رابط
  banner_url text,
  is_visible boolean not null default true,
  sort_order int not null default 0,
  default_listing_duration_days int not null default 30,
  requires_moderation boolean not null default false,  -- مراجعة قبل النشر لهذه المنصة
  allows_business_accounts boolean not null default false, -- تسمح بحسابات تجارية (مكتب/تاجر)
  is_auction_platform boolean not null default false,
  settings jsonb not null default '{}'::jsonb,   -- إعدادات إضافية حرة للمنصة
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table categories (
  id uuid primary key default uuid_generate_v4(),
  platform_id uuid not null references platforms(id) on delete cascade,
  parent_id uuid references categories(id) on delete cascade,  -- لدعم تصنيفات فرعية متعددة المستويات
  key text not null,
  name_ar text not null,
  name_en text,
  icon text,
  is_visible boolean not null default true,
  sort_order int not null default 0,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  unique (platform_id, key)
);

-- تعريف الحقول الديناميكية لكل تصنيف (هذا ما يسمح باستحداث حقول بدون كود)
create type field_type as enum ('text', 'number', 'boolean', 'select', 'multi_select', 'date', 'phone', 'url', 'textarea');

create table category_field_schemas (
  id uuid primary key default uuid_generate_v4(),
  category_id uuid not null references categories(id) on delete cascade,
  field_key text not null,                -- مثال: 'bedrooms', 'mileage_km', 'color'
  label_ar text not null,
  label_en text,
  field_type field_type not null,
  is_required boolean not null default false,
  is_filterable boolean not null default true,   -- يظهر كفلتر بحث
  options jsonb,                           -- لقوائم select/multi_select: ["شقة","فيلا","دور"]
  sort_order int not null default 0,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  unique (category_id, field_key)
);

-- ============================================================================
-- 3) الإعلانات (جدول موحّد لكل المنصات، بحقول ديناميكية عبر JSONB)
-- ============================================================================

create type listing_status as enum ('draft', 'pending_review', 'published', 'rejected', 'sold', 'expired', 'archived');

create table listings (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references profiles(id) on delete cascade,
  platform_id uuid not null references platforms(id),
  category_id uuid not null references categories(id),
  title text not null,
  description text,
  price numeric(14,2),
  currency text not null default 'SAR',
  is_negotiable boolean not null default false,
  condition text,                          -- 'new' | 'used' وغيرها حسب التصنيف
  city text,
  district text,
  latitude double precision,
  longitude double precision,
  contact_phone text,
  contact_whatsapp text,
  attributes jsonb not null default '{}'::jsonb,  -- قيم الحقول الديناميكية من category_field_schemas
  status listing_status not null default 'draft',
  rejection_reason text,
  views_count int not null default 0,
  favorites_count int not null default 0,
  published_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_listings_platform on listings(platform_id);
create index idx_listings_category on listings(category_id);
create index idx_listings_status on listings(status);
create index idx_listings_owner on listings(owner_id);
create index idx_listings_attributes_gin on listings using gin (attributes);

create table listing_images (
  id uuid primary key default uuid_generate_v4(),
  listing_id uuid not null references listings(id) on delete cascade,
  url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table favorites (
  user_id uuid not null references profiles(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

-- ============================================================================
-- 4) المزادات (بدون أي تدخل مالي من التطبيق — تنسيق وعرض فقط)
-- ============================================================================

create type auction_status as enum ('scheduled', 'live', 'ended', 'cancelled');

create table auctions (
  id uuid primary key default uuid_generate_v4(),
  listing_id uuid not null references listings(id) on delete cascade,
  starting_price numeric(14,2) not null,
  min_increment numeric(14,2) not null default 1,
  current_price numeric(14,2),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status auction_status not null default 'scheduled',
  disclaimer_ar text not null default
    'المنصة لا تتحمل أي مسؤولية مالية عن عمليات المزاد، وتقتصر مهمتها على التنسيق والعرض فقط.',
  created_at timestamptz not null default now()
);

create table bids (
  id uuid primary key default uuid_generate_v4(),
  auction_id uuid not null references auctions(id) on delete cascade,
  bidder_id uuid not null references profiles(id),
  amount numeric(14,2) not null,
  created_at timestamptz not null default now()
);

create index idx_bids_auction on bids(auction_id);

-- ============================================================================
-- 5) الدردشة الفورية (عبر Supabase Realtime)
-- ============================================================================

create table conversations (
  id uuid primary key default uuid_generate_v4(),
  listing_id uuid references listings(id) on delete set null,
  buyer_id uuid not null references profiles(id),
  seller_id uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  unique (listing_id, buyer_id, seller_id)
);

create table messages (
  id uuid primary key default uuid_generate_v4(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id),
  content text,
  attachment_url text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_messages_conversation on messages(conversation_id, created_at);

-- ============================================================================
-- 6) نظام الصلاحيات: أدوار جاهزة + تخصيص حر (RBAC + Overrides)
-- ============================================================================

create table roles (
  id uuid primary key default uuid_generate_v4(),
  key text unique not null,          -- 'owner' | 'super_admin' | 'platform_manager' | 'moderator' | ...
  name_ar text not null,
  is_system_role boolean not null default false,  -- true = دور أساسي لا يُحذف (owner مثلاً)
  created_at timestamptz not null default now()
);

create table permissions (
  id uuid primary key default uuid_generate_v4(),
  key text unique not null,          -- 'platforms.create' | 'listings.approve' | 'admins.manage' | ...
  name_ar text not null,
  description_ar text
);

create table role_permissions (
  role_id uuid not null references roles(id) on delete cascade,
  permission_id uuid not null references permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create table admin_users (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null unique references profiles(id) on delete cascade,
  role_id uuid not null references roles(id),
  granted_by uuid references profiles(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- صلاحيات إضافية أو مستثناة فوق الدور الأساسي لكل مسؤول (التخصيص الحر)
create table admin_user_permission_overrides (
  admin_user_id uuid not null references admin_users(id) on delete cascade,
  permission_id uuid not null references permissions(id) on delete cascade,
  is_granted boolean not null,   -- true = إضافة صلاحية، false = سحب صلاحية كانت ضمن الدور
  primary key (admin_user_id, permission_id)
);

create table audit_logs (
  id uuid primary key default uuid_generate_v4(),
  admin_user_id uuid references admin_users(id),
  action text not null,
  target_table text,
  target_id uuid,
  details jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 7) بذر أولي: تسجيل حساب المالك + الأدوار والصلاحيات الأساسية
-- ============================================================================

insert into roles (key, name_ar, is_system_role) values
  ('owner', 'مالك المشروع', true),
  ('super_admin', 'مشرف عام', false),
  ('platform_manager', 'مسؤول منصة', false),
  ('moderator', 'مراجع محتوى', false);

insert into permissions (key, name_ar, description_ar) values
  ('platforms.manage', 'إدارة المنصات', 'إنشاء/إظهار/إخفاء المنصات'),
  ('categories.manage', 'إدارة التصنيفات والحقول', 'استحداث تصنيفات وحقول ديناميكية'),
  ('listings.approve', 'اعتماد الإعلانات', 'مراجعة ونشر أو رفض الإعلانات'),
  ('listings.remove', 'حذف الإعلانات', 'إزالة أي إعلان مخالف'),
  ('admins.manage', 'إدارة المسؤولين', 'تعيين مسؤولين ومنح صلاحيات'),
  ('users.manage', 'إدارة المستخدمين', 'حظر/تفعيل حسابات المستخدمين'),
  ('auctions.manage', 'إدارة المزادات', 'إنشاء وإدارة المزادات'),
  ('content.manage', 'إدارة المحتوى', 'حسابات التواصل الاجتماعي والشريط المتحرك');

-- ربط كل الصلاحيات بدور owner تلقائياً
insert into role_permissions (role_id, permission_id)
select r.id, p.id from roles r cross join permissions p where r.key = 'owner';

-- صلاحيات الأدوار الجاهزة الأخرى (قابلة للتخصيص لكل مسؤول عبر admin_user_permission_overrides)
insert into role_permissions (role_id, permission_id)
select r.id, p.id from roles r join permissions p on
  (r.key = 'super_admin' and p.key in ('platforms.manage','categories.manage','listings.approve','listings.remove','users.manage','auctions.manage','content.manage'))
  or (r.key = 'platform_manager' and p.key in ('platforms.manage','categories.manage'))
  or (r.key = 'moderator' and p.key in ('listings.approve','listings.remove'));

-- منصات افتراضية أولية
insert into platforms (key, name_ar, requires_moderation, allows_business_accounts, is_auction_platform) values
  ('marketplace', 'السوق العام', false, false, false),
  ('real_estate', 'العقارات', true, true, false),
  ('cars', 'السيارات', true, true, false),
  ('auctions', 'المزادات', true, false, true);

-- ============================================================================
-- 7.1) تصنيفات وحقول ديناميكية فعلية (أمثلة تطبيقية جاهزة)
-- ============================================================================

-- ---------- العقارات ----------
insert into categories (platform_id, key, name_ar)
select id, 'apartments_sale', 'شقق للبيع' from platforms where key = 'real_estate'
union all
select id, 'apartments_rent', 'شقق للإيجار' from platforms where key = 'real_estate'
union all
select id, 'villas', 'فلل' from platforms where key = 'real_estate'
union all
select id, 'land', 'أراضي' from platforms where key = 'real_estate'
union all
select id, 'offices_shops', 'مكاتب ومحلات تجارية' from platforms where key = 'real_estate';

-- حقول مشتركة للعقارات السكنية (شقق وفلل)
insert into category_field_schemas (category_id, field_key, label_ar, field_type, is_required, options, sort_order)
select c.id, f.field_key, f.label_ar, f.field_type::field_type, f.is_required, f.options::jsonb, f.sort_order
from categories c
join platforms p on p.id = c.platform_id and p.key = 'real_estate'
cross join (values
  ('area_sqm',      'المساحة (م²)',        'number',  true,  null,                                        1),
  ('bedrooms',      'عدد غرف النوم',        'number',  true,  null,                                        2),
  ('bathrooms',     'عدد دورات المياه',      'number',  true,  null,                                        3),
  ('floor_number',  'رقم الدور',            'number',  false, null,                                        4),
  ('furnishing',    'التأثيث',              'select',  false, '["مفروش","غير مفروش","جزئي"]',              5),
  ('age_years',     'عمر البناء (سنوات)',   'number',  false, null,                                        6)
) as f(field_key, label_ar, field_type, is_required, options, sort_order)
where c.key in ('apartments_sale', 'apartments_rent', 'villas');

-- حقول الأراضي
insert into category_field_schemas (category_id, field_key, label_ar, field_type, is_required, options, sort_order)
select c.id, f.field_key, f.label_ar, f.field_type::field_type, f.is_required, f.options::jsonb, f.sort_order
from categories c
cross join (values
  ('area_sqm',      'المساحة (م²)',    'number', true,  null,                             1),
  ('land_type',     'نوع الأرض',        'select', false, '["سكني","تجاري","زراعي","صناعي"]', 2),
  ('street_width',  'عرض الشارع (م)',   'number', false, null,                             3)
) as f(field_key, label_ar, field_type, is_required, options, sort_order)
where c.key = 'land';

-- ---------- السيارات ----------
insert into categories (platform_id, key, name_ar)
select id, 'sedans', 'سيارات صالون' from platforms where key = 'cars'
union all
select id, 'suvs', 'دفع رباعي' from platforms where key = 'cars'
union all
select id, 'motorcycles', 'دراجات نارية' from platforms where key = 'cars'
union all
select id, 'trucks', 'شاحنات ومعدات' from platforms where key = 'cars';

insert into category_field_schemas (category_id, field_key, label_ar, field_type, is_required, options, sort_order)
select c.id, f.field_key, f.label_ar, f.field_type::field_type, f.is_required, f.options::jsonb, f.sort_order
from categories c
join platforms p on p.id = c.platform_id and p.key = 'cars'
cross join (values
  ('brand',         'الماركة',           'text',    true,  null,                                   1),
  ('model',         'الموديل',           'text',    true,  null,                                   2),
  ('year',          'سنة الصنع',         'number',  true,  null,                                   3),
  ('mileage_km',    'الممشى (كم)',       'number',  true,  null,                                   4),
  ('transmission',  'ناقل الحركة',       'select',  false, '["أوتوماتيك","عادي"]',                 5),
  ('fuel_type',     'نوع الوقود',        'select',  false, '["بنزين","ديزل","هجين","كهربائي"]',    6),
  ('color',         'اللون',             'text',    false, null,                                   7)
) as f(field_key, label_ar, field_type, is_required, options, sort_order)
where c.key in ('sedans', 'suvs', 'motorcycles', 'trucks');

-- ---------- السوق العام ----------
insert into categories (platform_id, key, name_ar)
select id, 'electronics', 'إلكترونيات' from platforms where key = 'marketplace'
union all
select id, 'furniture', 'أثاث' from platforms where key = 'marketplace'
union all
select id, 'clothing', 'ملابس' from platforms where key = 'marketplace'
union all
select id, 'appliances', 'أجهزة منزلية' from platforms where key = 'marketplace'
union all
select id, 'other', 'أخرى' from platforms where key = 'marketplace';

insert into category_field_schemas (category_id, field_key, label_ar, field_type, is_required, options, sort_order)
select c.id, f.field_key, f.label_ar, f.field_type::field_type, f.is_required, f.options::jsonb, f.sort_order
from categories c
join platforms p on p.id = c.platform_id and p.key = 'marketplace'
cross join (values
  ('brand',    'الماركة/النوع', 'text',   false, null,                    1),
  ('condition_detail', 'حالة القطعة', 'select', false, '["جديد بالكرتون","مستعمل ممتاز","مستعمل جيد"]', 2)
) as f(field_key, label_ar, field_type, is_required, options, sort_order)
where c.key in ('electronics', 'furniture', 'clothing', 'appliances', 'other');

-- ⚠️ لإضافة حساب المالك فعلياً (صف profiles يُنشأ تلقائياً الآن عبر trigger أعلاه):
-- 1) سجّل حساباً عادياً بهذا البريد من التطبيق نفسه (أو من Dashboard).
-- 2) من Dashboard → Authentication → Users، افتح هذا المستخدم وانسخ Ref/UUID الخاص به.
-- 3) نفّذ (بعد استبدال UUID الحقيقي):
--
-- update profiles set full_name = 'اسم المالك', account_type = 'business'
-- where id = '<AUTH_USER_UUID>';
--
-- insert into admin_users (user_id, role_id)
-- select '<AUTH_USER_UUID>', id from roles where key = 'owner';

-- ============================================================================
-- 7.2) التقييمات والمراجعات (من الزوار/المشترين/المستخدمين)
-- ============================================================================

create table reviews (
  id uuid primary key default uuid_generate_v4(),
  reviewer_id uuid not null references profiles(id) on delete cascade,   -- من قام بالتقييم
  reviewee_id uuid references profiles(id) on delete cascade,             -- تقييم بائع/تاجر/مكتب بشكل عام
  listing_id uuid references listings(id) on delete cascade,              -- أو تقييم إعلان محدد
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  constraint reviews_target_check check (reviewee_id is not null or listing_id is not null),
  constraint reviews_no_self_review check (reviewer_id is distinct from reviewee_id)
);

create index idx_reviews_reviewee on reviews(reviewee_id);
create index idx_reviews_listing on reviews(listing_id);

-- ملخص تقييم كل بائع/تاجر (متوسط + عدد) — يُستخدم مباشرة من التطبيق بدون حساب يدوي
create view seller_rating_summary as
select reviewee_id as user_id,
       round(avg(rating)::numeric, 2) as average_rating,
       count(*) as reviews_count
from reviews
where reviewee_id is not null
group by reviewee_id;

-- ملخص تقييم كل إعلان
create view listing_rating_summary as
select listing_id,
       round(avg(rating)::numeric, 2) as average_rating,
       count(*) as reviews_count
from reviews
where listing_id is not null
group by listing_id;

-- ============================================================================
-- 7.3) حسابات التواصل الاجتماعي + الشريط المتحرك (يتحكم بهما المالك)
-- ============================================================================

-- حسابات التواصل: تُنشأ فارغة ومخفية، ولا تظهر للجمهور حتى يدخل المالك القيمة ويفعّل الإظهار
create table social_links (
  key text primary key,            -- instagram | x | snapchat | tiktok | whatsapp | website
  label_ar text not null,
  value text not null default '',
  is_visible boolean not null default false,
  sort_order int not null default 0
);

insert into social_links (key, label_ar, sort_order) values
  ('instagram', 'انستقرام', 1), ('x', 'X (تويتر)', 2), ('snapchat', 'سناب شات', 3),
  ('tiktok', 'تيك توك', 4), ('whatsapp', 'واتساب', 5), ('website', 'الموقع الإلكتروني', 6);

-- عناصر الشريط المتحرك أعلى الرئيسية (معارض/مكاتب مميزة لخلق روح التنافس)
create table featured_sponsors (
  id uuid primary key default uuid_generate_v4(),
  text_ar text not null,
  is_visible boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 8) دوال مساعدة للتحقق من الصلاحيات (RBAC + تخصيص حر)
-- ============================================================================

create or replace function public.is_admin()
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1 from admin_users au where au.user_id = auth.uid() and au.is_active
  );
$$;

-- يتحقق من صلاحية معيّنة: يقدّم التخصيص الفردي (override) على صلاحيات الدور الأساسي
create or replace function public.has_permission(perm_key text)
returns boolean
language plpgsql stable security definer
as $$
declare
  v_admin_id uuid;
  v_role_id  uuid;
  v_override boolean;
  v_role_has boolean;
begin
  select au.id, au.role_id into v_admin_id, v_role_id
  from admin_users au
  where au.user_id = auth.uid() and au.is_active;

  if v_admin_id is null then
    return false;
  end if;

  select ov.is_granted into v_override
  from admin_user_permission_overrides ov
  join permissions p on p.id = ov.permission_id
  where ov.admin_user_id = v_admin_id and p.key = perm_key;

  if v_override is not null then
    return v_override;
  end if;

  select exists (
    select 1 from role_permissions rp
    join permissions p on p.id = rp.permission_id
    where rp.role_id = v_role_id and p.key = perm_key
  ) into v_role_has;

  return coalesce(v_role_has, false);
end;
$$;

-- يبحث عن معرّف مستخدم ببريده الإلكتروني — بديل آمن عن نسخ UUID يدوياً من Dashboard.
-- تعمل بصلاحية security definer لتقدر تقرأ auth.users (غير متاحة عادةً عبر الـ API)،
-- لكنها محمية داخلياً: لا تعمل إطلاقاً إلا لمن يملك صلاحية admins.manage الفعلية،
-- ولا ترجع سوى المعرّف (UUID) فقط — لا بيانات حساسة أخرى.
create or replace function public.find_user_id_by_email(p_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_permission('admins.manage') then
    raise exception 'ليس لديك صلاحية للبحث عن مستخدمين';
  end if;
  return (select id from auth.users where lower(email) = lower(p_email) limit 1);
end;
$$;

revoke all on function public.find_user_id_by_email(text) from public;
grant execute on function public.find_user_id_by_email(text) to authenticated;

-- يستخدمها تطبيق الأندرويد للتحقق: هل المستخدم الحالي مسؤول/مالك؟ (صف واحد أو لا شيء)
create view my_admin_status as
select au.id as admin_user_id, au.user_id, r.key as role_key, r.name_ar as role_name, au.is_active
from admin_users au
join roles r on r.id = au.role_id
where au.user_id = auth.uid() and au.is_active;

-- يستخدمها التطبيق لمعرفة الصلاحيات الفعلية للمستخدم الحالي (دور + تخصيص) بسطر واحد لكل صلاحية
create view my_permissions as
select p.key from permissions p where has_permission(p.key);

-- حارس المزايدات: يمنع أي مزايدة أقل من (السعر الحالي + الحد الأدنى للزيادة)،
-- يرفض المزايدة على مزاد غير مباشر، ويحدّث current_price تلقائياً — كل هذا
-- على مستوى القاعدة نفسها حتى لا يقدر أي عميل (chuck تطبيق أندرويد أو غيره)
-- يتلاعب بالسعر من جهته. القفل (for update) يمنع تعارض مزايدتين متزامنتين.
create or replace function public.guard_bid_insert()
returns trigger
language plpgsql
security definer
as $$
declare
  v_current numeric;
  v_starting numeric;
  v_min_inc numeric;
  v_status auction_status;
  v_ends timestamptz;
  v_owner uuid;
begin
  select a.current_price, a.starting_price, a.min_increment, a.status, a.ends_at, l.owner_id
  into v_current, v_starting, v_min_inc, v_status, v_ends, v_owner
  from auctions a join listings l on l.id = a.listing_id
  where a.id = new.auction_id for update of a;

  if v_status is null then
    raise exception 'المزاد غير موجود';
  end if;
  if v_status <> 'live' then
    raise exception 'هذا المزاد غير مباشر حالياً';
  end if;
  if v_ends <= now() then
    raise exception 'انتهى وقت هذا المزاد';
  end if;
  if v_owner = new.bidder_id then
    raise exception 'لا يمكنك المزايدة على مزادك الخاص';
  end if;

  if new.amount < coalesce(v_current, v_starting) + v_min_inc then
    raise exception 'المزايدة يجب أن تكون % على الأقل', (coalesce(v_current, v_starting) + v_min_inc);
  end if;

  update auctions set current_price = new.amount where id = new.auction_id;
  return new;
end;
$$;

create trigger trg_guard_bid_insert
  before insert on bids
  for each row execute function guard_bid_insert();

-- ============================================================================
-- 7.4) إنشاء تلقائي لصف profiles عند تسجيل أي مستخدم — من التطبيق أو من Dashboard
-- ============================================================================
-- هذا يحل مشكلة جذرية: بدون هذا الـ trigger، أي مستخدم (خصوصاً من أُنشئ يدوياً
-- من Supabase Dashboard) لن يملك صف profiles، وبالتالي ستفشل أي محاولة نشر
-- إعلان بخطأ foreign key، لأن listings.owner_id يشير إلى profiles.id.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- 7.5) سياسات رفع/قراءة/حذف صور الإعلانات في Storage (bucket: listing-images)
-- ============================================================================
-- ⚠️ خطوة إلزامية: أنشئ الـ bucket نفسه من Dashboard → Storage باسم listing-images
-- أولاً (وضعه Public اختياري الآن، لأن سياسة القراءة أدناه تكفي وحدها). بدون
-- هذه السياسات، الرفع يفشل دائماً مهما كان إعداد "Public" على الـ bucket.

create policy "listing_images_public_read"
  on storage.objects for select
  to public
  using (bucket_id = 'listing-images');

create policy "listing_images_authenticated_upload"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'listing-images');

create policy "listing_images_owner_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'listing-images' and owner = auth.uid());

-- ============================================================================
-- 7.6) أسعار الصرف — اليمن له سوقان منفصلان فعلياً (صنعاء وعدن) بأسعار مختلفة
-- ============================================================================
-- العملة الأساسية للمنصة: الريال اليمني (YER). لا يوجد مصدر رسمي موثوق للأسعار
-- الموازية عبر أي API خارجي، لذلك الأسعار هنا يُدخلها المالك/المسؤول يدوياً
-- (تماماً كبقية المحتوى الديناميكي بالمشروع) ويحدّثها كل ما تغيّر السعر فعلياً.

create table exchange_rates (
  id uuid primary key default uuid_generate_v4(),
  city text not null check (city in ('sanaa', 'aden')),
  currency text not null check (currency in ('USD', 'SAR')),
  rate_to_yer numeric(12,2) not null,
  updated_at timestamptz not null default now(),
  unique (city, currency)
);

insert into exchange_rates (city, currency, rate_to_yer) values
  ('sanaa', 'USD', 530), ('sanaa', 'SAR', 141),
  ('aden', 'USD', 1650), ('aden', 'SAR', 440);

alter table exchange_rates enable row level security;

create policy "exchange_rates_select_all"
  on exchange_rates for select
  using (true);

create policy "exchange_rates_write_content_manager"
  on exchange_rates for update
  using (has_permission('content.manage'));

-- ============================================================================
-- 7.7) عدّاد مشاهدات حقيقي (ليس أرقاماً وهمية) — أي زائر يقدر يزيد العداد
-- ============================================================================
-- RLS العادية تمنع أي شخص غير صاحب الإعلان من تحديث صف listings (محق تماماً)،
-- لكن عدّاد المشاهدات حالة خاصة: نريد أي زائر (حتى غير مسجّل) يزيد العدد،
-- بدون منحه صلاحية تعديل أي عمود آخر. لذلك دالة معزولة بصلاحية محدودة جداً.

create or replace function public.increment_listing_views(p_listing_id uuid)
returns void
language sql
security definer
as $$
  update listings set views_count = views_count + 1
  where id = p_listing_id and status = 'published';
$$;

grant execute on function public.increment_listing_views(uuid) to anon, authenticated;

-- ============================================================================
-- 9) Row Level Security — سياسات كاملة لكل جدول
-- ============================================================================

-- ---------- profiles ----------
alter table profiles enable row level security;

create policy "profiles_select_public"
  on profiles for select
  using (true);  -- الملفات العامة مرئية للجميع (اسم/صورة تظهر مع الإعلان)

create policy "profiles_insert_self"
  on profiles for insert
  with check (id = auth.uid());

create policy "profiles_update_self_or_admin"
  on profiles for update
  using (id = auth.uid() or has_permission('users.manage'));

create policy "profiles_delete_admin_only"
  on profiles for delete
  using (has_permission('users.manage'));

-- ---------- platforms ----------
alter table platforms enable row level security;

create policy "platforms_select_visible_or_admin"
  on platforms for select
  using (is_visible = true or is_admin());

create policy "platforms_write_admin_only"
  on platforms for insert
  with check (has_permission('platforms.manage'));

create policy "platforms_update_admin_only"
  on platforms for update
  using (has_permission('platforms.manage'));

create policy "platforms_delete_admin_only"
  on platforms for delete
  using (has_permission('platforms.manage'));

-- ---------- categories ----------
alter table categories enable row level security;

create policy "categories_select_visible_or_admin"
  on categories for select
  using (is_visible = true or is_admin());

create policy "categories_insert_admin_only"
  on categories for insert
  with check (has_permission('categories.manage'));

create policy "categories_update_admin_only"
  on categories for update
  using (has_permission('categories.manage'));

create policy "categories_delete_admin_only"
  on categories for delete
  using (has_permission('categories.manage'));

-- ---------- category_field_schemas ----------
alter table category_field_schemas enable row level security;

create policy "field_schemas_select_all"
  on category_field_schemas for select
  using (true);  -- تعريف الحقول عام حتى يبني التطبيق النموذج الديناميكي

create policy "field_schemas_write_admin_only"
  on category_field_schemas for insert
  with check (has_permission('categories.manage'));

create policy "field_schemas_update_admin_only"
  on category_field_schemas for update
  using (has_permission('categories.manage'));

create policy "field_schemas_delete_admin_only"
  on category_field_schemas for delete
  using (has_permission('categories.manage'));

-- ---------- listings ----------
alter table listings enable row level security;

create policy "listings_select_published_or_own_or_reviewer"
  on listings for select
  using (
    status = 'published'
    or owner_id = auth.uid()
    or has_permission('listings.approve')
  );

create policy "listings_insert_own"
  on listings for insert
  with check (owner_id = auth.uid());

create policy "listings_update_own_or_reviewer"
  on listings for update
  using (owner_id = auth.uid() or has_permission('listings.approve'));

create policy "listings_delete_own_or_remover"
  on listings for delete
  using (owner_id = auth.uid() or has_permission('listings.remove'));

-- ---------- listing_images ----------
alter table listing_images enable row level security;

create policy "listing_images_select_if_listing_visible"
  on listing_images for select
  using (
    exists (
      select 1 from listings l
      where l.id = listing_images.listing_id
      and (l.status = 'published' or l.owner_id = auth.uid() or has_permission('listings.approve'))
    )
  );

create policy "listing_images_write_owner_or_admin"
  on listing_images for insert
  with check (
    exists (
      select 1 from listings l
      where l.id = listing_images.listing_id
      and (l.owner_id = auth.uid() or has_permission('listings.remove'))
    )
  );

create policy "listing_images_delete_owner_or_admin"
  on listing_images for delete
  using (
    exists (
      select 1 from listings l
      where l.id = listing_images.listing_id
      and (l.owner_id = auth.uid() or has_permission('listings.remove'))
    )
  );

-- ---------- favorites ----------
alter table favorites enable row level security;

create policy "favorites_owner_only"
  on favorites for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------- auctions ----------
alter table auctions enable row level security;

create policy "auctions_select_if_listing_visible"
  on auctions for select
  using (
    exists (
      select 1 from listings l
      where l.id = auctions.listing_id
      and (l.status = 'published' or l.owner_id = auth.uid() or has_permission('auctions.manage'))
    )
  );

create policy "auctions_write_owner_or_manager"
  on auctions for insert
  with check (
    exists (select 1 from listings l where l.id = listing_id and l.owner_id = auth.uid())
    or has_permission('auctions.manage')
  );

create policy "auctions_update_manager_only"
  on auctions for update
  using (has_permission('auctions.manage'));

-- ---------- bids ----------
alter table bids enable row level security;

create policy "bids_select_if_auction_visible"
  on bids for select
  using (
    exists (
      select 1 from auctions a
      join listings l on l.id = a.listing_id
      where a.id = bids.auction_id and l.status = 'published'
    )
  );

create policy "bids_insert_self_only"
  on bids for insert
  with check (bidder_id = auth.uid());

-- لا توجد سياسة update/delete: المزايدات غير قابلة للتعديل أو الحذف (سجل ثابت)

-- ---------- conversations ----------
alter table conversations enable row level security;

create policy "conversations_participants_only"
  on conversations for all
  using (buyer_id = auth.uid() or seller_id = auth.uid())
  with check (buyer_id = auth.uid() or seller_id = auth.uid());

-- ---------- messages ----------
alter table messages enable row level security;

create policy "messages_select_participants_only"
  on messages for select
  using (
    exists (
      select 1 from conversations c
      where c.id = messages.conversation_id
      and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );

create policy "messages_insert_participant_as_sender"
  on messages for insert
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from conversations c
      where c.id = conversation_id
      and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );

create policy "messages_update_mark_read_by_recipient"
  on messages for update
  using (
    exists (
      select 1 from conversations c
      where c.id = messages.conversation_id
      and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );

-- ---------- roles / permissions / role_permissions ----------
alter table roles enable row level security;
alter table permissions enable row level security;
alter table role_permissions enable row level security;

create policy "roles_select_admins_only"
  on roles for select
  using (is_admin());

create policy "roles_write_admins_manage_only"
  on roles for insert
  with check (has_permission('admins.manage'));

create policy "roles_update_admins_manage_only"
  on roles for update
  using (has_permission('admins.manage') and is_system_role = false);

create policy "permissions_select_admins_only"
  on permissions for select
  using (is_admin());

create policy "role_permissions_select_admins_only"
  on role_permissions for select
  using (is_admin());

create policy "role_permissions_write_admins_manage_only"
  on role_permissions for all
  using (has_permission('admins.manage'))
  with check (has_permission('admins.manage'));

-- ---------- admin_users ----------
alter table admin_users enable row level security;

create policy "admin_users_select_self_or_manager"
  on admin_users for select
  using (user_id = auth.uid() or has_permission('admins.manage'));

create policy "admin_users_write_manager_only"
  on admin_users for insert
  with check (has_permission('admins.manage'));

create policy "admin_users_update_manager_only"
  on admin_users for update
  using (has_permission('admins.manage'));

create policy "admin_users_delete_manager_only_not_owner"
  on admin_users for delete
  using (
    has_permission('admins.manage')
    and role_id not in (select id from roles where key = 'owner')
  );

-- ---------- admin_user_permission_overrides ----------
alter table admin_user_permission_overrides enable row level security;

create policy "overrides_select_self_or_manager"
  on admin_user_permission_overrides for select
  using (
    exists (select 1 from admin_users au where au.id = admin_user_id and au.user_id = auth.uid())
    or has_permission('admins.manage')
  );

create policy "overrides_write_manager_only"
  on admin_user_permission_overrides for all
  using (has_permission('admins.manage'))
  with check (has_permission('admins.manage'));

-- ---------- audit_logs ----------
alter table audit_logs enable row level security;

create policy "audit_logs_select_managers_only"
  on audit_logs for select
  using (has_permission('admins.manage'));

create policy "audit_logs_insert_any_admin"
  on audit_logs for insert
  with check (is_admin());

-- ---------- reviews ----------
alter table reviews enable row level security;

create policy "reviews_select_all"
  on reviews for select
  using (true);  -- التقييمات عامة ومرئية للجميع (زوار، مشترين، مستخدمين)

create policy "reviews_insert_authenticated_not_self"
  on reviews for insert
  with check (
    reviewer_id = auth.uid()
    and reviewer_id is distinct from reviewee_id
  );

create policy "reviews_update_own_only"
  on reviews for update
  using (reviewer_id = auth.uid());

create policy "reviews_delete_own_or_moderator"
  on reviews for delete
  using (reviewer_id = auth.uid() or has_permission('listings.remove'));

-- ---------- social_links ----------
alter table social_links enable row level security;

create policy "social_links_select_visible_or_admin"
  on social_links for select
  using ((is_visible = true and value <> '') or is_admin());

create policy "social_links_update_content_manager"
  on social_links for update
  using (has_permission('content.manage'));

-- ---------- featured_sponsors ----------
alter table featured_sponsors enable row level security;

create policy "sponsors_select_visible_or_admin"
  on featured_sponsors for select
  using (is_visible = true or is_admin());

create policy "sponsors_write_content_manager"
  on featured_sponsors for all
  using (has_permission('content.manage'))
  with check (has_permission('content.manage'));

-- ============================================================================
-- 7.7) عداد مشاهدات حقيقي — جزء من "روح الحياة": يزيد لحظة فتح أي إعلان
-- ============================================================================
-- دالة بدل تحديث مباشر من التطبيق، لأن الزائر (anon) وحتى المستخدم العادي لا
-- يملكان صلاحية UPDATE على listings أصلاً (محصورة بصاحب الإعلان/المراجع) —
-- وهذا صحيح؛ لا نريد لأي زائر تعديل أي عمود آخر غير المشاهدات.

create or replace function public.increment_listing_views(p_listing_id uuid)
returns void
language sql
security definer
as $$
  update listings set views_count = views_count + 1
  where id = p_listing_id and status = 'published';
$$;

grant execute on function public.increment_listing_views(uuid) to anon, authenticated;


-- ============================================================================
-- 7.8) إغلاق المزادات المنتهية تلقائياً (pg_cron) + تصنيفات منصة المزادات
-- ============================================================================
-- حارس المزايدات أعلاه يرفض أي مزايدة بعد ends_at حتى لو لم تُغلق الحالة، فلا ثغرة
-- بدون الجدولة. الجدولة فقط لتحديث الحالة إلى "ended" كي تختفي من قائمة المباشر.
-- لو لم تكن إضافة pg_cron مفعّلة بمشروعك، فعّلها من Dashboard → Database → Extensions
-- ثم أعد تنفيذ هذا الجزء فقط؛ الكتلة أدناه لا تُفشل بقية السكربت إن لم تتوفر.

create or replace function public.close_expired_auctions()
returns void
language sql
security definer
as $$
  update auctions set status = 'ended' where status = 'live' and ends_at <= now();
$$;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('close-expired-auctions', '* * * * *', 'select public.close_expired_auctions()');
exception when others then
  raise notice 'pg_cron غير متاح — فعّله من Dashboard ثم أعد تشغيل هذا الجزء. (%)', sqlerrm;
end $$;

-- تصنيفات منصة المزادات (كانت تصنيفاً واحداً "عام" فقط)
insert into categories (platform_id, key, name_ar, sort_order)
select p.id, v.key, v.name_ar, v.ord
from platforms p
cross join (values
  ('auction_cars', 'سيارات', 1),
  ('auction_realestate', 'عقارات وأراضي', 2),
  ('auction_electronics', 'إلكترونيات', 3),
  ('auction_antiques', 'تحف ومقتنيات', 4)
) as v(key, name_ar, ord)
where p.key = 'auctions'
on conflict (platform_id, key) do nothing;

-- ============================================================================
-- 7.9) المفضلة: صلاحية الحذف/الإضافة موجودة (favorites_owner_only)، وهنا العدّاد
-- ============================================================================
create or replace function public.sync_favorites_count()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'INSERT' then
    update listings set favorites_count = favorites_count + 1 where id = new.listing_id;
  elsif tg_op = 'DELETE' then
    update listings set favorites_count = greatest(favorites_count - 1, 0) where id = old.listing_id;
  end if;
  return null;
end;
$$;

create trigger trg_sync_favorites_count
  after insert or delete on favorites
  for each row execute function sync_favorites_count();
