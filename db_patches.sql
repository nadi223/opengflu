-- ============================================================================
-- Open Gate — db_patches.sql  (ملحق فوق open_gate_schema.sql، لا يستبدله)
-- ----------------------------------------------------------------------------
-- تنبيه صادق: لم أستطع تشغيل هذا الملف على Postgres (لا توجد قاعدة في بيئتي).
-- كُتب بعد قراءة المخطط سطراً سطراً، لكنه غير مُختبر. شغّله أولاً على مشروع
-- Supabase تجريبي. إن فشل أي مقطع فألصق لي رسالة الخطأ وسطرها.
-- الملف قابل لإعادة التشغيل (idempotent) قدر الإمكان.
-- شغّله في SQL Editor كاملاً، أو قسماً قسماً بالترتيب.
-- ============================================================================


-- ============================================================================
-- 1) أعمدة جديدة + دوال مساعدة أساسية
-- ============================================================================

alter table public.profiles add column if not exists is_banned boolean not null default false;

-- أسماء Security Definer كلها تُثبَّت على search_path لمنع اختطاف المسار.
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from admin_users au where au.user_id = auth.uid() and au.is_active
  );
$$;

-- المالك (owner) يملك كل الصلاحيات دائماً حتى لو أُضيفت صلاحيات جديدة لاحقاً
-- أو عُدّلت role_permissions، فلا يمكن قفله خارج مشروعه.
create or replace function public.has_permission(perm_key text)
returns boolean
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_role_id  uuid;
  v_role_key text;
  v_override boolean;
  v_role_has boolean;
begin
  if auth.uid() is null then
    return false;
  end if;

  select au.id, au.role_id, r.key
  into v_admin_id, v_role_id, v_role_key
  from admin_users au
  join roles r on r.id = au.role_id
  where au.user_id = auth.uid() and au.is_active;

  if v_admin_id is null then
    return false;
  end if;

  if v_role_key = 'owner' then
    return true;
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

create or replace function public.is_owner()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from admin_users au
    join roles r on r.id = au.role_id
    where au.user_id = auth.uid() and au.is_active and r.key = 'owner'
  );
$$;

create or replace function public.is_banned()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce((select p.is_banned from profiles p where p.id = auth.uid()), false);
$$;

create or replace function public.current_admin_id()
returns uuid
language sql stable security definer
set search_path = public
as $$
  select au.id from admin_users au where au.user_id = auth.uid() and au.is_active limit 1;
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;


-- ============================================================================
-- 2) جداول جديدة: المدن (اليمن) + إعدادات التطبيق + سجل المشاهدات
-- ============================================================================

-- مدن/محافظات اليمن: ديناميكية يديرها المالك (content.manage).
create table if not exists public.cities (
  id uuid primary key default uuid_generate_v4(),
  key text unique not null,
  name_ar text not null,
  name_en text,
  is_visible boolean not null default true,
  sort_order int not null default 0
);

insert into public.cities (key, name_ar, name_en, sort_order) values
  ('amanat_alasimah', 'أمانة العاصمة', 'Capital Secretariat', 1),
  ('sanaa',      'صنعاء',   'Sanaa', 2),
  ('aden',       'عدن',     'Aden', 3),
  ('taiz',       'تعز',     'Taiz', 4),
  ('hodeidah',   'الحديدة', 'Hodeidah', 5),
  ('ibb',        'إب',      'Ibb', 6),
  ('hadramaut',  'حضرموت',  'Hadramaut', 7),
  ('dhamar',     'ذمار',    'Dhamar', 8),
  ('lahij',      'لحج',     'Lahij', 9),
  ('abyan',      'أبين',    'Abyan', 10),
  ('shabwah',    'شبوة',    'Shabwah', 11),
  ('marib',      'مأرب',    'Marib', 12),
  ('al_jawf',    'الجوف',   'Al Jawf', 13),
  ('amran',      'عمران',   'Amran', 14),
  ('hajjah',     'حجة',     'Hajjah', 15),
  ('saada',      'صعدة',    'Saada', 16),
  ('al_mahwit',  'المحويت', 'Al Mahwit', 17),
  ('raymah',     'ريمة',    'Raymah', 18),
  ('al_bayda',   'البيضاء', 'Al Bayda', 19),
  ('al_dhale',   'الضالع',  'Al Dhale''e', 20),
  ('al_mahrah',  'المهرة',  'Al Mahrah', 21),
  ('socotra',    'سقطرى',   'Socotra', 22)
on conflict (key) do nothing;

alter table public.cities enable row level security;

drop policy if exists "cities_select_visible_or_admin" on public.cities;
create policy "cities_select_visible_or_admin" on public.cities
  for select using (is_visible = true or public.is_admin());

drop policy if exists "cities_insert_content_manager" on public.cities;
create policy "cities_insert_content_manager" on public.cities
  for insert with check (public.has_permission('content.manage'));

drop policy if exists "cities_update_content_manager" on public.cities;
create policy "cities_update_content_manager" on public.cities
  for update using (public.has_permission('content.manage'))
  with check (public.has_permission('content.manage'));

drop policy if exists "cities_delete_content_manager" on public.cities;
create policy "cities_delete_content_manager" on public.cities
  for delete using (public.has_permission('content.manage'));

-- إعدادات عامة يقرأها التطبيق (قيم غير سرّية فقط).
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

insert into public.app_config (key, value) values
  ('phone_auth_enabled', 'false'::jsonb),     -- يفعّله المالك بعد ضبط مزوّد SMS في Supabase
  ('default_currency',   '"YER"'::jsonb),
  ('default_country_code', '"+967"'::jsonb)
on conflict (key) do nothing;

alter table public.app_config enable row level security;

drop policy if exists "app_config_select_all" on public.app_config;
create policy "app_config_select_all" on public.app_config
  for select using (true);

drop policy if exists "app_config_update_content_manager" on public.app_config;
create policy "app_config_update_content_manager" on public.app_config
  for update using (public.has_permission('content.manage'))
  with check (public.has_permission('content.manage'));

revoke update on public.app_config from anon, authenticated;
grant update (value) on public.app_config to authenticated;

drop trigger if exists trg_app_config_updated_at on public.app_config;
create trigger trg_app_config_updated_at before update on public.app_config
  for each row execute function public.set_updated_at();

-- سجل مشاهدات لمنع تضخيم العدّاد: مشاهدة واحدة لكل مشاهِد في اليوم.
create table if not exists public.listing_views (
  listing_id uuid not null references public.listings(id) on delete cascade,
  viewer_key text not null,
  view_date date not null default current_date,
  primary key (listing_id, viewer_key, view_date)
);
alter table public.listing_views enable row level security;   -- بلا سياسات = مغلق للعميل
revoke all on public.listing_views from anon, authenticated;


-- ============================================================================
-- 3) الملفات الشخصية: إغلاق تسريب الهاتف + منع التوثيق الذاتي
-- ============================================================================
-- سابقاً: profiles_select_public تكشف phone و business_license_no لكل الناس،
-- وتسمح للمستخدم بتعديل is_verified. الحل: صلاحيات على مستوى العمود.
-- مهم للتطبيق: لا تستخدم select('*') على profiles، اذكر الأعمدة صراحةً.
-- بياناتي الكاملة: view باسم my_profile. للمسؤولين: view باسم admin_profiles.

revoke select, insert, update, delete on public.profiles from anon, authenticated;

grant select (id, full_name, avatar_url, account_type, business_name, is_verified, created_at)
  on public.profiles to anon, authenticated;
grant insert (id, full_name, phone, avatar_url, account_type, business_name, business_license_no)
  on public.profiles to authenticated;
grant update (full_name, phone, avatar_url, account_type, business_name, business_license_no)
  on public.profiles to authenticated;

-- حذف الملفات صار عبر delete_my_account أو الحظر فقط (حذف مباشر يترك مستخدماً يتيماً في auth).
drop policy if exists "profiles_delete_admin_only" on public.profiles;

-- يمنع المستخدم من تغيير is_banned/is_verified حتى لو وصل لهما بطريقة أخرى.
create or replace view public.my_profile as
  select * from public.profiles where id = auth.uid();
revoke all on public.my_profile from public, anon;
grant select on public.my_profile to authenticated;

create or replace view public.admin_profiles as
  select * from public.profiles where public.has_permission('users.manage');
revoke all on public.admin_profiles from public, anon;
grant select on public.admin_profiles to authenticated;

alter table public.profiles drop constraint if exists profiles_phone_e164;
alter table public.profiles add constraint profiles_phone_e164
  check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$') not valid;
alter table public.profiles drop constraint if exists profiles_name_len;
alter table public.profiles add constraint profiles_name_len
  check (full_name is null or char_length(full_name) <= 100) not valid;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace function public.set_user_verified(p_user_id uuid, p_value boolean)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.has_permission('users.manage') then
    raise exception 'ليس لديك صلاحية إدارة المستخدمين';
  end if;
  update profiles set is_verified = p_value where id = p_user_id;
  insert into audit_logs (admin_user_id, action, target_table, target_id, details)
  values (public.current_admin_id(), 'set_verified', 'profiles', p_user_id,
          jsonb_build_object('value', p_value));
end;
$$;

create or replace function public.set_user_banned(p_user_id uuid, p_value boolean)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.has_permission('users.manage') then
    raise exception 'ليس لديك صلاحية إدارة المستخدمين';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'لا يمكنك حظر نفسك';
  end if;
  if exists (select 1 from admin_users where user_id = p_user_id and is_active)
     and not public.is_owner() then
    raise exception 'لا يمكن حظر حساب مسؤول';
  end if;
  update profiles set is_banned = p_value where id = p_user_id;
  if p_value then
    update listings set status = 'archived'
    where owner_id = p_user_id and status in ('published', 'pending_review');
  end if;
  insert into audit_logs (admin_user_id, action, target_table, target_id, details)
  values (public.current_admin_id(), case when p_value then 'ban' else 'unban' end,
          'profiles', p_user_id, '{}'::jsonb);
end;
$$;


-- ============================================================================
-- 4) إنشاء الملف تلقائياً عند التسجيل (بريد أو هاتف) + حفظ الهاتف
-- ============================================================================
-- الهاتف يأتي إما من auth.users.phone (تسجيل بالهاتف) أو من metadata.phone
-- (تسجيل بالبريد مع هاتف اختياري). يُنظَّف ويُتحقق منه كي لا يفشل التسجيل.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_name  text;
begin
  v_phone := case
    when nullif(new.phone, '') is not null then '+' || ltrim(new.phone, '+')
    else nullif(new.raw_user_meta_data->>'phone', '')
  end;
  if v_phone is not null and v_phone !~ '^\+[1-9][0-9]{7,14}$' then
    v_phone := null;
  end if;

  v_name := left(coalesce(
    nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'مستخدم'
  ), 100);

  insert into public.profiles (id, full_name, phone)
  values (new.id, v_name, v_phone)
  on conflict (id) do nothing;
  return new;
end;
$$;


-- ============================================================================
-- 5) المنصات والتصنيفات والحقول: قيود سلامة
-- ============================================================================

alter table public.platforms drop constraint if exists platforms_key_format;
alter table public.platforms add constraint platforms_key_format
  check (key ~ '^[a-z][a-z0-9_]*$') not valid;
alter table public.platforms drop constraint if exists platforms_banner_https;
alter table public.platforms add constraint platforms_banner_https
  check (banner_url is null or banner_url ~* '^https://') not valid;
alter table public.platforms drop constraint if exists platforms_duration_range;
alter table public.platforms add constraint platforms_duration_range
  check (default_listing_duration_days between 1 and 365) not valid;

alter table public.categories drop constraint if exists categories_key_format;
alter table public.categories add constraint categories_key_format
  check (key ~ '^[a-z][a-z0-9_]*$') not valid;

alter table public.category_field_schemas drop constraint if exists field_key_format;
alter table public.category_field_schemas add constraint field_key_format
  check (field_key ~ '^[a-z][a-z0-9_]*$') not valid;
alter table public.category_field_schemas drop constraint if exists field_options_valid;
alter table public.category_field_schemas add constraint field_options_valid
  check (
    (field_type in ('select', 'multi_select')
       and options is not null and jsonb_typeof(options) = 'array' and jsonb_array_length(options) > 0)
    or (field_type not in ('select', 'multi_select'))
  ) not valid;

drop trigger if exists trg_platforms_updated_at on public.platforms;
create trigger trg_platforms_updated_at before update on public.platforms
  for each row execute function public.set_updated_at();


-- ============================================================================
-- 6) الإعلانات: فرض المراجعة والتحقق من الحقول في القاعدة نفسها
-- ============================================================================
-- الثغرات التي تُغلق هنا:
--  * المالك كان يستطيع جعل إعلانه published متجاوزاً requires_moderation.
--  * المالك كان يستطيع تزوير views_count / favorites_count / published_at.
--  * لا تحقق أن التصنيف يتبع المنصة، ولا من قيم attributes أو الحقول الإلزامية.
--  * المنصة المخفية كانت إعلاناتها ما زالت قابلة للقراءة عبر الـ API.
-- مسار النشر الجديد: إدراج كمسودة -> رفع الصور وإدراج listing_images ->
-- تحديث status إلى 'published' فتقرر القاعدة (published أو pending_review).

alter table public.listings alter column currency set default 'YER';

alter table public.listings drop constraint if exists listings_currency_allowed;
alter table public.listings add constraint listings_currency_allowed
  check (currency in ('YER', 'SAR', 'USD')) not valid;
alter table public.listings drop constraint if exists listings_price_nonneg;
alter table public.listings add constraint listings_price_nonneg
  check (price is null or price >= 0) not valid;
alter table public.listings drop constraint if exists listings_title_len;
alter table public.listings add constraint listings_title_len
  check (char_length(title) between 3 and 150) not valid;
alter table public.listings drop constraint if exists listings_desc_len;
alter table public.listings add constraint listings_desc_len
  check (description is null or char_length(description) <= 5000) not valid;
alter table public.listings drop constraint if exists listings_geo_range;
alter table public.listings add constraint listings_geo_range
  check ((latitude is null or latitude between -90 and 90)
     and (longitude is null or longitude between -180 and 180)) not valid;
alter table public.listings drop constraint if exists listings_phone_e164;
alter table public.listings add constraint listings_phone_e164
  check ((contact_phone is null or contact_phone ~ '^\+[1-9][0-9]{7,14}$')
     and (contact_whatsapp is null or contact_whatsapp ~ '^\+[1-9][0-9]{7,14}$')) not valid;

create index if not exists idx_listings_feed
  on public.listings (platform_id, status, published_at desc);

-- التحقق من الصور والحقول الديناميكية عند النشر/الإرسال للمراجعة.
create or replace function public.validate_listing_publish(
  p_listing uuid, p_category uuid, p_attrs jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  f record;
  v jsonb;
  v_txt text;
begin
  if (select count(*) from listing_images where listing_id = p_listing) < 1 then
    raise exception 'أضف صورة واحدة على الأقل للإعلان';
  end if;

  if p_attrs is null or jsonb_typeof(p_attrs) <> 'object' then
    raise exception 'بيانات الحقول غير صالحة';
  end if;
  if length(p_attrs::text) > 8000 then
    raise exception 'بيانات الحقول كبيرة جداً';
  end if;

  if exists (
    select 1 from jsonb_object_keys(p_attrs) as k(key)
    where k.key not in (select s.field_key from category_field_schemas s where s.category_id = p_category)
  ) then
    raise exception 'الإعلان يحتوي على حقول غير معرّفة لهذا التصنيف';
  end if;

  for f in
    select * from category_field_schemas where category_id = p_category order by sort_order
  loop
    v := p_attrs -> f.field_key;

    if v is null or jsonb_typeof(v) = 'null'
       or (jsonb_typeof(v) = 'string' and btrim(v #>> '{}') = '') then
      if f.is_required then
        raise exception 'الحقل "%" مطلوب', f.label_ar;
      end if;
      continue;
    end if;

    v_txt := v #>> '{}';

    case f.field_type::text
      when 'number' then
        if jsonb_typeof(v) <> 'number' then
          raise exception 'الحقل "%" يجب أن يكون رقماً', f.label_ar;
        end if;
      when 'boolean' then
        if jsonb_typeof(v) <> 'boolean' then
          raise exception 'الحقل "%" يجب أن يكون نعم/لا', f.label_ar;
        end if;
      when 'text', 'textarea' then
        if jsonb_typeof(v) <> 'string' or char_length(v_txt) > 5000 then
          raise exception 'قيمة الحقل "%" غير صالحة', f.label_ar;
        end if;
      when 'phone' then
        if jsonb_typeof(v) <> 'string' or v_txt !~ '^\+[1-9][0-9]{7,14}$' then
          raise exception 'رقم الهاتف في الحقل "%" غير صالح', f.label_ar;
        end if;
      when 'url' then
        if jsonb_typeof(v) <> 'string' or v_txt !~* '^https?://[^\s]+$' then
          raise exception 'الرابط في الحقل "%" غير صالح', f.label_ar;
        end if;
      when 'date' then
        if jsonb_typeof(v) <> 'string' or v_txt !~ '^\d{4}-\d{2}-\d{2}$' then
          raise exception 'التاريخ في الحقل "%" غير صالح', f.label_ar;
        end if;
        begin
          perform v_txt::date;
        exception when others then
          raise exception 'التاريخ في الحقل "%" غير صالح', f.label_ar;
        end;
      when 'select' then
        if jsonb_typeof(v) <> 'string' or (f.options is not null and not (f.options ? v_txt)) then
          raise exception 'اختيار غير صالح في الحقل "%"', f.label_ar;
        end if;
      when 'multi_select' then
        if jsonb_typeof(v) <> 'array' then
          raise exception 'اختيارات غير صالحة في الحقل "%"', f.label_ar;
        end if;
        if f.options is not null and exists (
          select 1 from jsonb_array_elements_text(v) e(val) where not (f.options ? e.val)
        ) then
          raise exception 'اختيارات غير صالحة في الحقل "%"', f.label_ar;
        end if;
      else
        null;
    end case;
  end loop;
end;
$$;

create or replace function public.guard_listing_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_platform platforms%rowtype;
  v_cat_platform uuid;
  v_cat_visible boolean;
  v_reviewer boolean;
  v_changed boolean := false;
begin
  -- عمليات النظام (cron / مفتاح الخدمة / SQL Editor) بلا مستخدم: تمر دون قيود.
  if auth.uid() is null then
    return new;
  end if;

  v_reviewer := public.has_permission('listings.approve');

  if tg_op = 'INSERT' then
    if public.is_banned() then
      raise exception 'حسابك موقوف ولا يمكنه نشر إعلانات';
    end if;

    if (select count(*) from listings
        where owner_id = new.owner_id and created_at > now() - interval '1 day') >= 30 then
      raise exception 'تجاوزت الحد اليومي لإنشاء الإعلانات';
    end if;

    select * into v_platform from platforms where id = new.platform_id;
    if v_platform.id is null or (not v_platform.is_visible and not public.is_admin()) then
      raise exception 'المنصة غير متاحة';
    end if;

    select c.platform_id, c.is_visible into v_cat_platform, v_cat_visible
    from categories c where c.id = new.category_id;
    if v_cat_platform is distinct from new.platform_id
       or (not coalesce(v_cat_visible, false) and not public.is_admin()) then
      raise exception 'التصنيف غير صالح لهذه المنصة';
    end if;

    if length(new.attributes::text) > 8000 then
      raise exception 'بيانات الحقول كبيرة جداً';
    end if;

    new.status := 'draft'::listing_status;
    new.views_count := 0;
    new.favorites_count := 0;
    new.rejection_reason := null;
    new.published_at := null;
    new.expires_at := null;
    return new;
  end if;

  -- UPDATE
  select * into v_platform from platforms where id = new.platform_id;

  if not v_reviewer then
    if public.is_banned() then
      raise exception 'حسابك موقوف';
    end if;

    if new.status in ('rejected', 'expired') and new.status is distinct from old.status then
      raise exception 'لا يمكنك تعيين هذه الحالة';
    end if;

    new.rejection_reason := old.rejection_reason;

    if new.status in ('published', 'pending_review') then
      perform public.validate_listing_publish(new.id, new.category_id, new.attributes);

      v_changed := (new.title, new.description, new.price, new.currency, new.is_negotiable,
                    new.condition, new.city, new.district, new.latitude, new.longitude,
                    new.contact_phone, new.contact_whatsapp, new.attributes)
                   is distinct from
                   (old.title, old.description, old.price, old.currency, old.is_negotiable,
                    old.condition, old.city, old.district, old.latitude, old.longitude,
                    old.contact_phone, old.contact_whatsapp, old.attributes);

      if old.status = 'rejected' then
        new.status := 'pending_review'::listing_status;
        new.rejection_reason := null;
      elsif v_platform.requires_moderation then
        if not (old.status = 'published' and new.status = 'published' and not v_changed) then
          new.status := 'pending_review'::listing_status;
        end if;
      else
        new.status := 'published'::listing_status;
      end if;
    end if;
  end if;

  if new.status = 'published' and old.status is distinct from 'published' then
    new.published_at := now();
    new.expires_at := now() + make_interval(days => v_platform.default_listing_duration_days);
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_guard_listing_insert on public.listings;
create trigger trg_guard_listing_insert
  before insert on public.listings
  for each row execute function public.guard_listing_write();

-- يعمل فقط عند تعديل هذه الأعمدة، فلا يتأثر عدّادا المشاهدات والمفضلة.
drop trigger if exists trg_guard_listing_update on public.listings;
create trigger trg_guard_listing_update
  before update of title, description, price, currency, is_negotiable, condition, city,
    district, latitude, longitude, contact_phone, contact_whatsapp, attributes, status,
    rejection_reason
  on public.listings
  for each row execute function public.guard_listing_write();

-- صلاحيات الأعمدة: لا أحد يكتب العدّادات أو التواريخ أو المالك من العميل.
revoke insert, update on public.listings from anon, authenticated;
grant insert (id, owner_id, platform_id, category_id, title, description, price, currency,
              is_negotiable, condition, city, district, latitude, longitude, contact_phone,
              contact_whatsapp, attributes)
  on public.listings to authenticated;
grant update (title, description, price, currency, is_negotiable, condition, city, district,
              latitude, longitude, contact_phone, contact_whatsapp, attributes, status,
              rejection_reason)
  on public.listings to authenticated;

drop policy if exists "listings_select_published_or_own_or_reviewer" on public.listings;
create policy "listings_select_visible" on public.listings
  for select using (
    (status = 'published'
       and exists (select 1 from platforms p where p.id = listings.platform_id and p.is_visible))
    or owner_id = auth.uid()
    or has_permission('listings.approve')
  );

drop policy if exists "listings_insert_own" on public.listings;
create policy "listings_insert_own" on public.listings
  for insert with check (owner_id = auth.uid() and not public.is_banned());

drop policy if exists "listings_update_own_or_reviewer" on public.listings;
create policy "listings_update_own_or_reviewer" on public.listings
  for update
  using (owner_id = auth.uid() or has_permission('listings.approve'))
  with check (owner_id = auth.uid() or has_permission('listings.approve'));

-- لا يحذف المالك إعلاناً عليه مزاد جارٍ فيه مزايدات (إخفاء لأدلة المزاد).
drop policy if exists "listings_delete_own_or_remover" on public.listings;
create policy "listings_delete_own_or_remover" on public.listings
  for delete using (
    has_permission('listings.remove')
    or (
      owner_id = auth.uid()
      and not exists (
        select 1 from auctions a
        where a.listing_id = listings.id
          and a.status in ('scheduled', 'live')
          and exists (select 1 from bids b where b.auction_id = a.id)
      )
    )
  );

-- انتهاء صلاحية الإعلانات (لم يكن هناك أي جدولة لذلك).
create or replace function public.expire_listings()
returns void
language sql
security definer
set search_path = public
as $$
  update listings set status = 'expired'
  where status = 'published' and expires_at is not null and expires_at <= now();
$$;


-- ============================================================================
-- 7) صور الإعلانات
-- ============================================================================

alter table public.listing_images drop constraint if exists listing_images_url_bucket;
alter table public.listing_images add constraint listing_images_url_bucket
  check (url ~ '^https://.+/storage/v1/object/public/listing-images/.+') not valid;

create or replace function public.guard_listing_image()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is null then
    return new;
  end if;
  select owner_id into v_owner from listings where id = new.listing_id;
  if (select count(*) from listing_images where listing_id = new.listing_id) >= 8 then
    raise exception 'الحد الأقصى 8 صور لكل إعلان';
  end if;
  -- لا يشير إلى ملفات مستخدم آخر: المسار يجب أن يبدأ بمجلد المالك.
  if not public.has_permission('listings.remove')
     and position(('/listing-images/' || v_owner::text || '/') in new.url) = 0 then
    raise exception 'رابط الصورة غير صالح';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_listing_image on public.listing_images;
create trigger trg_guard_listing_image
  before insert on public.listing_images
  for each row execute function public.guard_listing_image();

-- لا يُترك إعلان منشور/قيد المراجعة بلا صور.
create or replace function public.guard_listing_image_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return null;
  end if;
  if exists (select 1 from listings where id = old.listing_id and status in ('published', 'pending_review'))
     and not exists (select 1 from listing_images where listing_id = old.listing_id) then
    raise exception 'لا يمكن حذف آخر صورة لإعلان منشور';
  end if;
  return null;
end;
$$;

drop trigger if exists trg_guard_listing_image_delete on public.listing_images;
create trigger trg_guard_listing_image_delete
  after delete on public.listing_images
  for each row execute function public.guard_listing_image_delete();


-- ============================================================================
-- 8) عدّاد المشاهدات: حقيقي بلا تضخيم
-- ============================================================================
-- التوقيع الجديد: increment_listing_views(p_listing_id, p_viewer_key default null).
-- المسجَّل يُحتسب بمعرّفه، والزائر يرسل معرّفاً عشوائياً ثابتاً للتثبيت (p_viewer_key).
-- الزائر بلا معرّف لا يُحتسب. مشاهدة المالك لإعلانه لا تُحتسب.

drop function if exists public.increment_listing_views(uuid);

create or replace function public.increment_listing_views(
  p_listing_id uuid, p_viewer_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_key text;
  v_rows int;
begin
  select owner_id into v_owner from listings where id = p_listing_id and status = 'published';
  if v_owner is null then
    return;
  end if;
  if auth.uid() is not null and v_owner = auth.uid() then
    return;
  end if;

  v_key := coalesce(auth.uid()::text, left(nullif(btrim(p_viewer_key), ''), 64));
  if v_key is null then
    return;
  end if;

  insert into listing_views (listing_id, viewer_key) values (p_listing_id, v_key)
  on conflict do nothing;
  get diagnostics v_rows = row_count;

  if v_rows > 0 then
    update listings set views_count = views_count + 1 where id = p_listing_id;
  end if;
end;
$$;

create or replace function public.purge_listing_views()
returns void
language sql
security definer
set search_path = public
as $$
  delete from listing_views where view_date < current_date;
$$;


-- ============================================================================
-- 9) المزادات والمزايدات
-- ============================================================================
-- الثغرات: المالك كان يُدخل current_price/status/disclaimer كما يشاء، ولا شيء ينقل
-- المزاد من scheduled إلى live، ولا يوجد حد لمزاد واحد نشط لكل إعلان.

create unique index if not exists uq_auctions_one_active_per_listing
  on public.auctions (listing_id) where status in ('scheduled', 'live');
create index if not exists idx_auctions_status_ends on public.auctions (status, ends_at);
create index if not exists idx_bids_auction_time on public.bids (auction_id, created_at desc);

alter table public.auctions drop constraint if exists auctions_prices_positive;
alter table public.auctions add constraint auctions_prices_positive
  check (starting_price > 0 and min_increment > 0) not valid;
alter table public.auctions drop constraint if exists auctions_time_order;
alter table public.auctions add constraint auctions_time_order
  check (ends_at > starts_at) not valid;

revoke insert, update on public.auctions from anon, authenticated;
grant insert (listing_id, starting_price, min_increment, starts_at, ends_at)
  on public.auctions to authenticated;
grant update (status, ends_at) on public.auctions to authenticated;

create or replace function public.guard_auction_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_status listing_status;
  v_is_auction boolean;
begin
  if auth.uid() is null then
    return new;
  end if;
  if public.is_banned() then
    raise exception 'حسابك موقوف';
  end if;

  select l.owner_id, l.status, p.is_auction_platform
  into v_owner, v_status, v_is_auction
  from listings l join platforms p on p.id = l.platform_id
  where l.id = new.listing_id;

  if v_owner is null then
    raise exception 'الإعلان غير موجود';
  end if;
  if v_owner <> auth.uid() and not public.has_permission('auctions.manage') then
    raise exception 'لا يمكنك بدء مزاد على إعلان لا تملكه';
  end if;
  if not v_is_auction then
    raise exception 'المزادات متاحة لإعلانات منصة المزادات فقط';
  end if;
  if v_status <> 'published' then
    raise exception 'يجب أن يكون الإعلان منشوراً قبل بدء المزاد';
  end if;
  if new.starting_price <= 0 or new.min_increment <= 0 then
    raise exception 'السعر والحد الأدنى للزيادة يجب أن يكونا أكبر من صفر';
  end if;
  if new.ends_at < greatest(new.starts_at, now()) + interval '10 minutes' then
    raise exception 'يجب ألا تقل مدة المزاد عن 10 دقائق';
  end if;
  if new.ends_at > greatest(new.starts_at, now()) + interval '30 days' then
    raise exception 'أقصى مدة للمزاد 30 يوماً';
  end if;

  new.current_price := null;
  new.status := (case when new.starts_at <= now() then 'live' else 'scheduled' end)::auction_status;
  return new;
end;
$$;

drop trigger if exists trg_guard_auction_insert on public.auctions;
create trigger trg_guard_auction_insert
  before insert on public.auctions
  for each row execute function public.guard_auction_insert();

-- إلغاء المالك لمزاده قبل أي مزايدة.
create or replace function public.cancel_my_auction(p_auction_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'سجّل الدخول أولاً';
  end if;
  if not exists (
    select 1 from auctions a join listings l on l.id = a.listing_id
    where a.id = p_auction_id and l.owner_id = auth.uid() and a.status in ('scheduled', 'live')
  ) then
    raise exception 'لا يمكن إلغاء هذا المزاد';
  end if;
  if exists (select 1 from bids where auction_id = p_auction_id) then
    raise exception 'لا يمكن إلغاء مزاد عليه مزايدات';
  end if;
  update auctions set status = 'cancelled' where id = p_auction_id;
end;
$$;

-- نفس منطق التحقق الأصلي ورسائله العربية كما هي، مع search_path وفحص الحظر فقط.
create or replace function public.guard_bid_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current numeric;
  v_starting numeric;
  v_min_inc numeric;
  v_status auction_status;
  v_ends timestamptz;
  v_owner uuid;
begin
  if auth.uid() is not null and public.is_banned() then
    raise exception 'حسابك موقوف';
  end if;

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

-- حذف المستخدم لا يمنعه وجود مزايدات له: تبقى المزايدة بلا اسم.
alter table public.bids alter column bidder_id drop not null;
alter table public.bids drop constraint if exists bids_bidder_id_fkey;
alter table public.bids add constraint bids_bidder_id_fkey
  foreign key (bidder_id) references public.profiles(id) on delete set null;

-- تفعيل المجدولة وإنهاء المنتهية. الوظيفة المجدولة الأصلية تستدعي هذه الدالة بالاسم نفسه.
create or replace function public.close_expired_auctions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update auctions set status = 'live'
  where status = 'scheduled' and starts_at <= now() and ends_at > now();
  update auctions set status = 'ended'
  where status in ('live', 'scheduled') and ends_at <= now();
end;
$$;


-- ============================================================================
-- 10) الدردشة
-- ============================================================================
-- الثغرات: أي مستخدم كان يُنشئ محادثة بين طرفين آخرين أو بائع مزيّف، ويُعدّل
-- نص أي رسالة في محادثته.

drop policy if exists "conversations_participants_only" on public.conversations;

create policy "conversations_select_participants" on public.conversations
  for select using (buyer_id = auth.uid() or seller_id = auth.uid());

create policy "conversations_insert_buyer_to_owner" on public.conversations
  for insert with check (
    buyer_id = auth.uid()
    and listing_id is not null
    and not public.is_banned()
    and exists (
      select 1 from listings l
      where l.id = conversations.listing_id
        and l.owner_id = conversations.seller_id
        and l.owner_id <> auth.uid()
        and l.status = 'published'
    )
  );

alter table public.messages drop constraint if exists messages_content_valid;
alter table public.messages add constraint messages_content_valid
  check (
    (content is not null and btrim(content) <> '' and char_length(content) <= 2000)
    or attachment_url is not null
  ) not valid;
alter table public.messages drop constraint if exists messages_attachment_bucket;
alter table public.messages add constraint messages_attachment_bucket
  check (attachment_url is null
         or attachment_url ~ '^https://.+/storage/v1/object/public/listing-images/.+') not valid;

drop policy if exists "messages_insert_participant_as_sender" on public.messages;
create policy "messages_insert_participant_as_sender" on public.messages
  for insert with check (
    sender_id = auth.uid()
    and not public.is_banned()
    and exists (
      select 1 from conversations c
      where c.id = messages.conversation_id
        and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );

-- التعديل الوحيد المسموح: وضع علامة "مقروء" من المستلم فقط.
revoke update on public.messages from anon, authenticated;
grant update (is_read) on public.messages to authenticated;

drop policy if exists "messages_update_mark_read_by_recipient" on public.messages;
create policy "messages_update_mark_read_by_recipient" on public.messages
  for update
  using (
    sender_id <> auth.uid()
    and exists (
      select 1 from conversations c
      where c.id = messages.conversation_id
        and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  )
  with check (
    sender_id <> auth.uid()
    and exists (
      select 1 from conversations c
      where c.id = messages.conversation_id
        and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );

create or replace function public.guard_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  if (select count(*) from messages
      where sender_id = new.sender_id and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'أرسلت رسائل كثيرة، انتظر قليلاً ثم أعد المحاولة';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_message_insert on public.messages;
create trigger trg_guard_message_insert
  before insert on public.messages
  for each row execute function public.guard_message_insert();


-- ============================================================================
-- 11) التقييمات: منع تقييم الذات وتكرار التقييم والتلاعب
-- ============================================================================
-- ملاحظة: إن وُجدت تقييمات مكررة قديمة فسيفشل إنشاء الفهرس الفريد؛ احذف المكرر أولاً.

create unique index if not exists uq_reviews_per_listing
  on public.reviews (reviewer_id, listing_id) where listing_id is not null;
create unique index if not exists uq_reviews_per_seller
  on public.reviews (reviewer_id, reviewee_id) where listing_id is null;

alter table public.reviews drop constraint if exists reviews_comment_len;
alter table public.reviews add constraint reviews_comment_len
  check (comment is null or char_length(comment) <= 1000) not valid;

revoke update on public.reviews from anon, authenticated;
grant update (rating, comment) on public.reviews to authenticated;

drop policy if exists "reviews_insert_authenticated_not_self" on public.reviews;
create policy "reviews_insert_authenticated_not_self" on public.reviews
  for insert with check (
    reviewer_id = auth.uid()
    and reviewer_id is distinct from reviewee_id
    and not public.is_banned()
  );

drop policy if exists "reviews_update_own_only" on public.reviews;
create policy "reviews_update_own_only" on public.reviews
  for update using (reviewer_id = auth.uid()) with check (reviewer_id = auth.uid());

create or replace function public.guard_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is null then
    return new;
  end if;
  if new.listing_id is not null then
    select owner_id into v_owner from listings where id = new.listing_id and status = 'published';
    if v_owner is null then
      raise exception 'لا يمكن تقييم هذا الإعلان';
    end if;
    if v_owner = new.reviewer_id then
      raise exception 'لا يمكنك تقييم إعلانك';
    end if;
    new.reviewee_id := v_owner;   -- يتّسق التقييم مع ملخص البائع
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_review on public.reviews;
create trigger trg_guard_review
  before insert on public.reviews
  for each row execute function public.guard_review();


-- ============================================================================
-- 12) لوحة المالك: حماية سلسلة الصلاحيات من التصعيد
-- ============================================================================
-- الثغرات: أي مسؤول بـ admins.manage كان يستطيع ترقية نفسه إلى owner، أو
-- تعطيل المالك، أو تعديل role_permissions لأي دور، أو تزوير audit_logs.

-- الأدوار وصلاحياتها: للمالك فقط، ودور owner نفسه لا يُعدَّل.
drop policy if exists "roles_write_admins_manage_only" on public.roles;
drop policy if exists "roles_update_admins_manage_only" on public.roles;
create policy "roles_insert_owner_only" on public.roles
  for insert with check (public.is_owner() and is_system_role = false);
create policy "roles_update_owner_only" on public.roles
  for update using (public.is_owner() and is_system_role = false)
  with check (public.is_owner() and is_system_role = false);

drop policy if exists "role_permissions_write_admins_manage_only" on public.role_permissions;
create policy "role_permissions_write_owner_only" on public.role_permissions
  for all
  using (public.is_owner() and role_id not in (select id from roles where key = 'owner'))
  with check (public.is_owner() and role_id not in (select id from roles where key = 'owner'));

create or replace function public.guard_admin_users()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_role uuid;
  v_old_owner boolean := false;
  v_new_owner boolean := false;
  v_other_owners int;
begin
  -- SQL Editor / مفتاح الخدمة (بلا مستخدم): مسموح، مثل بذر المالك الأول.
  if auth.uid() is null then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  select id into v_owner_role from roles where key = 'owner';
  if tg_op <> 'INSERT' then v_old_owner := (old.role_id = v_owner_role); end if;
  if tg_op <> 'DELETE' then v_new_owner := (new.role_id = v_owner_role); end if;

  if public.is_owner() then
    -- حتى المالك لا يزيل آخر مالك فعّال.
    if v_old_owner and (tg_op = 'DELETE' or not v_new_owner or not new.is_active) then
      select count(*) into v_other_owners
      from admin_users where role_id = v_owner_role and is_active and id <> old.id;
      if v_other_owners = 0 then
        raise exception 'لا يمكن إزالة أو تعطيل آخر مالك للمشروع';
      end if;
    end if;
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if v_old_owner or v_new_owner then
    raise exception 'لا يمكنك تعديل حساب المالك أو منح دوره';
  end if;

  if tg_op = 'INSERT' then
    if new.user_id = auth.uid() then
      raise exception 'لا يمكنك منح نفسك صلاحيات';
    end if;
    new.granted_by := auth.uid();
  elsif tg_op = 'UPDATE' then
    if old.user_id = auth.uid() or new.user_id is distinct from old.user_id then
      raise exception 'لا يمكنك تعديل هذا السجل';
    end if;
  else
    if old.user_id = auth.uid() then
      raise exception 'لا يمكنك حذف صلاحياتك بنفسك';
    end if;
  end if;

  -- سقف الصلاحيات: لا تمنح دوراً فيه ما لا تملكه أنت.
  if tg_op <> 'DELETE' then
    if exists (
      select 1 from role_permissions rp join permissions p on p.id = rp.permission_id
      where rp.role_id = new.role_id and not public.has_permission(p.key)
    ) then
      raise exception 'لا يمكنك منح دور يحوي صلاحيات لا تملكها';
    end if;
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_admin_users on public.admin_users;
create trigger trg_guard_admin_users
  before insert or update or delete on public.admin_users
  for each row execute function public.guard_admin_users();

create or replace function public.guard_admin_overrides()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_target_user uuid;
  v_target_role uuid;
  v_perm_key text;
begin
  if auth.uid() is null then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  v_admin_id := case when tg_op = 'DELETE' then old.admin_user_id else new.admin_user_id end;
  select au.user_id, au.role_id into v_target_user, v_target_role
  from admin_users au where au.id = v_admin_id;

  if v_target_role = (select id from roles where key = 'owner') then
    raise exception 'لا يمكن تخصيص صلاحيات المالك';
  end if;

  if not public.is_owner() then
    if v_target_user = auth.uid() then
      raise exception 'لا يمكنك تعديل صلاحياتك بنفسك';
    end if;
    if tg_op <> 'DELETE' and new.is_granted then
      select key into v_perm_key from permissions where id = new.permission_id;
      if not public.has_permission(v_perm_key) then
        raise exception 'لا يمكنك منح صلاحية لا تملكها';
      end if;
    end if;
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_admin_overrides on public.admin_user_permission_overrides;
create trigger trg_guard_admin_overrides
  before insert or update or delete on public.admin_user_permission_overrides
  for each row execute function public.guard_admin_overrides();

-- سجل التدقيق: لا يُكتب من العميل أبداً، بل بـ triggers تلقائية لا تُزوَّر.
drop policy if exists "audit_logs_insert_any_admin" on public.audit_logs;
revoke insert, update, delete on public.audit_logs from anon, authenticated;

create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb;
  v_id uuid;
begin
  if auth.uid() is null then
    return null;
  end if;
  v_row := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  begin
    v_id := nullif(v_row->>'id', '')::uuid;
  exception when others then
    v_id := null;
  end;
  insert into audit_logs (admin_user_id, action, target_table, target_id, details)
  values (public.current_admin_id(), tg_op, tg_table_name, v_id, jsonb_build_object('row', v_row));
  return null;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'platforms', 'categories', 'category_field_schemas', 'roles', 'role_permissions',
    'admin_users', 'admin_user_permission_overrides', 'exchange_rates', 'social_links',
    'featured_sponsors', 'cities', 'app_config'
  ] loop
    execute format('drop trigger if exists trg_audit_%1$s on public.%1$I', t);
    execute format(
      'create trigger trg_audit_%1$s after insert or update or delete on public.%1$I
         for each row execute function public.audit_row_change()', t);
  end loop;
end $$;


-- ============================================================================
-- 13) المحتوى: أسعار الصرف، حسابات التواصل، الشريط المتحرك
-- ============================================================================

alter table public.exchange_rates drop constraint if exists exchange_rates_positive;
alter table public.exchange_rates add constraint exchange_rates_positive
  check (rate_to_yer > 0) not valid;
revoke update on public.exchange_rates from anon, authenticated;
grant update (rate_to_yer) on public.exchange_rates to authenticated;
drop trigger if exists trg_exchange_rates_updated_at on public.exchange_rates;
create trigger trg_exchange_rates_updated_at before update on public.exchange_rates
  for each row execute function public.set_updated_at();

-- منع مخططات خطرة في الروابط (javascript: وأخواتها). المفتاح key لا يُعدَّل.
alter table public.social_links drop constraint if exists social_links_value_safe;
alter table public.social_links add constraint social_links_value_safe
  check (value !~* '^\s*(javascript|data|file|vbscript):' and char_length(value) <= 300) not valid;
revoke update on public.social_links from anon, authenticated;
grant update (value, is_visible, label_ar, sort_order) on public.social_links to authenticated;

alter table public.featured_sponsors drop constraint if exists sponsors_text_len;
alter table public.featured_sponsors add constraint sponsors_text_len
  check (char_length(text_ar) between 1 and 120) not valid;


-- ============================================================================
-- 14) التخزين: مجلد لكل مستخدم + قيود الحجم والنوع
-- ============================================================================
-- المسار المعتمد للرفع: <uid>/<listing_id>/<uuid>.jpg
-- (الشرط يعتمد storage.foldername الموثّقة بدل العمود owner الذي لم أتحقق منه).

drop policy if exists "listing_images_authenticated_upload" on storage.objects;
drop policy if exists "listing_images_owner_delete" on storage.objects;
drop policy if exists "listing_images_upload_own_folder" on storage.objects;
drop policy if exists "listing_images_delete_own_folder" on storage.objects;

create policy "listing_images_upload_own_folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'listing-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.is_banned()
  );

create policy "listing_images_delete_own_folder" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'listing-images'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.has_permission('listings.remove'))
  );

do $$
begin
  update storage.buckets
  set file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
  where id = 'listing-images';
exception when others then
  raise notice 'تعذّر ضبط حدود الـ bucket من SQL، اضبطها يدوياً: 5MB وأنواع jpeg/png/webp. (%)', sqlerrm;
end $$;


-- ============================================================================
-- 15) حذف الحساب (مطلب Google Play لأي تطبيق ينشئ حسابات)
-- ============================================================================

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'سجّل الدخول أولاً';
  end if;
  if exists (select 1 from admin_users where user_id = v_uid) then
    raise exception 'لا يمكن حذف حساب مسؤول؛ أزل صلاحياته الإدارية أولاً';
  end if;
  if exists (
    select 1 from auctions a join listings l on l.id = a.listing_id
    where l.owner_id = v_uid and a.status in ('scheduled', 'live')
      and exists (select 1 from bids b where b.auction_id = a.id)
  ) then
    raise exception 'لديك مزاد جارٍ عليه مزايدات؛ انتظر انتهاءه ثم أعد المحاولة';
  end if;

  delete from conversations where buyer_id = v_uid or seller_id = v_uid;
  delete from auth.users where id = v_uid;   -- يحذف الملف والإعلانات والمفضلات والتقييمات بالتسلسل
end;
$$;


-- ============================================================================
-- 16) Realtime + الجدولة
-- ============================================================================
-- بدون هذا القسم لا تعمل الدردشة ولا المزايدة اللحظية إطلاقاً.

do $$
declare
  t text;
begin
  foreach t in array array['messages', 'bids', 'auctions'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception
      when duplicate_object then null;
      when undefined_object then
        raise notice 'publication باسم supabase_realtime غير موجود: فعّل Realtime من لوحة Supabase.';
    end;
  end loop;
end $$;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('close-expired-auctions', '* * * * *', 'select public.close_expired_auctions()');
  perform cron.schedule('open-gate-expire-listings', '*/10 * * * *', 'select public.expire_listings()');
  perform cron.schedule('open-gate-purge-views', '5 0 * * *', 'select public.purge_listing_views()');
exception when others then
  raise notice 'pg_cron غير متاح — فعّله من Dashboard ثم أعد تشغيل هذا القسم. (%)', sqlerrm;
end $$;


-- ============================================================================
-- 17) صلاحيات تنفيذ الدوال
-- ============================================================================
-- الدوال الداخلية (triggers والجدولة) لا تُستدعى من العميل أبداً.

revoke all on function public.guard_listing_write() from public, anon, authenticated;
revoke all on function public.validate_listing_publish(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function public.guard_listing_image() from public, anon, authenticated;
revoke all on function public.guard_listing_image_delete() from public, anon, authenticated;
revoke all on function public.guard_auction_insert() from public, anon, authenticated;
revoke all on function public.guard_bid_insert() from public, anon, authenticated;
revoke all on function public.guard_message_insert() from public, anon, authenticated;
revoke all on function public.guard_review() from public, anon, authenticated;
revoke all on function public.guard_admin_users() from public, anon, authenticated;
revoke all on function public.guard_admin_overrides() from public, anon, authenticated;
revoke all on function public.audit_row_change() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.sync_favorites_count() from public, anon, authenticated;
revoke all on function public.close_expired_auctions() from public, anon, authenticated;
revoke all on function public.expire_listings() from public, anon, authenticated;
revoke all on function public.purge_listing_views() from public, anon, authenticated;
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.current_admin_id() from public, anon, authenticated;

-- دوال RPC التي يستدعيها التطبيق.
revoke all on function public.increment_listing_views(uuid, text) from public;
grant execute on function public.increment_listing_views(uuid, text) to anon, authenticated;

revoke all on function public.cancel_my_auction(uuid) from public, anon;
grant execute on function public.cancel_my_auction(uuid) to authenticated;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
revoke all on function public.set_user_verified(uuid, boolean) from public, anon;
grant execute on function public.set_user_verified(uuid, boolean) to authenticated;
revoke all on function public.set_user_banned(uuid, boolean) from public, anon;
grant execute on function public.set_user_banned(uuid, boolean) to authenticated;
revoke all on function public.find_user_id_by_email(text) from public, anon;
grant execute on function public.find_user_id_by_email(text) to authenticated;

-- (is_admin / has_permission / is_owner / is_banned تبقى قابلة للتنفيذ لأن سياسات RLS تستدعيها.)


-- ============================================================================
-- 18) تحديث ذاكرة PostgREST
-- ============================================================================
notify pgrst, 'reload schema';


-- ============================================================================
-- فحوص يدوية بعد التشغيل (انسخها في SQL Editor)
-- ============================================================================
-- 1) هل أُضيفت الجداول إلى Realtime؟
--    select tablename from pg_publication_tables where pubname = 'supabase_realtime';
--    المتوقع: messages, bids, auctions
-- 2) هل الهاتف مخفي عن الزوار؟ من تطبيق/REST بمفتاح anon:
--    GET /rest/v1/profiles?select=phone  => يجب أن يعود خطأ permission denied
-- 3) هل المهام مجدولة؟
--    select jobname, schedule from cron.job;
-- 4) كل الدوال الداخلية مسحوب تنفيذها:
--    select routine_name, grantee from information_schema.routine_privileges
--    where specific_schema = 'public' and grantee in ('anon','authenticated');
