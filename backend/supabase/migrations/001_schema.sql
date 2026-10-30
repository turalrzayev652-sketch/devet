-- 001_schema.sql — core schema (spec/PRODUCT.md §5, §7).
-- RLS policies are added in a later migration (T11).

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.event_type as enum ('wedding', 'engagement', 'henna', 'birthday', 'jubilee');
create type public.member_role as enum ('owner', 'cohost');
create type public.side as enum ('groom', 'bride', 'none');
create type public.rsvp_status as enum ('pending', 'yes', 'no');
create type public.salutation as enum ('muellim', 'xanim', 'bey', 'none');
create type public.purchase_kind as enum ('template', 'limit_addon');
create type public.store as enum ('google', 'apple');
create type public.lang as enum ('az', 'ru', 'en', 'tr');

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- 8-char code from Crockford-style base32 (no I, L, O, U).
-- 256 is a multiple of 32, so byte % 32 has no modulo bias.
create function public.random_code(len int default 8)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  bytes bytea := extensions.gen_random_bytes(len);
  result text := '';
begin
  for i in 0 .. len - 1 loop
    result := result || substr(alphabet, (get_byte(bytes, i) % 32) + 1, 1);
  end loop;
  return result;
end;
$$;

create function public.new_guest_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  candidate text;
begin
  loop
    candidate := public.random_code(8);
    exit when not exists (select 1 from public.guests where code = candidate);
  end loop;
  return candidate;
end;
$$;

create function public.new_invite_token()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  candidate text;
begin
  loop
    candidate := public.random_code(8);
    exit when not exists (select 1 from public.event_invites where token = candidate);
  end loop;
  return candidate;
end;
$$;

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name text,
  ui_lang public.lang not null default 'az',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table public.templates (
  id text primary key,
  name jsonb not null,
  is_premium boolean not null default false,
  store_product_id text,
  version int not null default 1,
  thumbnail_url text,
  langs public.lang[] not null default '{az,ru,en,tr}',
  sort_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  constraint templates_premium_product check (not is_premium or store_product_id is not null)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  type public.event_type not null,
  title_names text not null,
  host_names text,
  starts_at timestamptz not null,
  venue_name text not null,
  venue_address text,
  venue_lat double precision,
  venue_lng double precision,
  maps_url text,
  default_lang public.lang not null default 'az',
  template_id text references public.templates (id),
  customization jsonb not null default '{}'::jsonb,
  show_tablemates boolean not null default false,
  is_paid boolean not null default false,
  status text not null default 'draft' check (status in ('draft', 'active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  constraint events_lat_range check (venue_lat is null or venue_lat between -90 and 90),
  constraint events_lng_range check (venue_lng is null or venue_lng between -180 and 180)
);

create table public.event_members (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.member_role not null,
  side public.side not null default 'none',
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  unique (event_id, user_id)
);

-- At most 1 owner and 1 cohost per event (PRODUCT.md §2).
create unique index event_members_one_role_per_event on public.event_members (event_id, role);

create table public.event_invites (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  email text not null,
  side public.side not null default 'none',
  token text not null unique default public.new_invite_token()
    check (token ~ '^[0-9A-HJKMNP-TV-Z]{8}$'),
  accepted_at timestamptz,
  expires_at timestamptz not null default now() + interval '14 days',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  event_id uuid not null references public.events (id) on delete cascade,
  kind public.purchase_kind not null,
  template_id text references public.templates (id),
  store public.store not null,
  store_transaction_id text not null unique,
  amount_minor int,
  currency text,
  verified_at timestamptz not null default now(),
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  constraint purchases_template_kind check ((kind = 'template') = (template_id is not null))
);

create table public.guests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  code text not null unique default public.new_guest_code()
    check (code ~ '^[0-9A-HJKMNP-TV-Z]{8}$'),
  salutation public.salutation not null default 'none',
  name text not null check (length(btrim(name)) > 0),
  with_family boolean not null default false,
  invited_count int not null default 1 check (invited_count >= 1),
  phone_e164 text check (phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),
  side public.side not null default 'none',
  table_no text,
  lang public.lang,
  preview_path text,
  sent_at timestamptz,
  opened_at timestamptz,
  rsvp_status public.rsvp_status not null default 'pending',
  rsvp_count int not null default 0 check (rsvp_count >= 0),
  rsvp_at timestamptz,
  added_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table public.app_config (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  value jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index guests_event_id_idx on public.guests (event_id);
-- guests.code, event_invites.token, purchases.store_transaction_id are indexed by their unique constraints.
create index event_members_user_id_idx on public.event_members (user_id);
create index event_invites_event_id_idx on public.event_invites (event_id);
create index purchases_event_id_idx on public.purchases (event_id);
create index purchases_user_id_idx on public.purchases (user_id);
create index events_template_id_idx on public.events (template_id);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger templates_updated_at before update on public.templates
  for each row execute function public.set_updated_at();
create trigger events_updated_at before update on public.events
  for each row execute function public.set_updated_at();
create trigger event_members_updated_at before update on public.event_members
  for each row execute function public.set_updated_at();
create trigger event_invites_updated_at before update on public.event_invites
  for each row execute function public.set_updated_at();
create trigger purchases_updated_at before update on public.purchases
  for each row execute function public.set_updated_at();
create trigger guests_updated_at before update on public.guests
  for each row execute function public.set_updated_at();
create trigger app_config_updated_at before update on public.app_config
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Profile row for every new auth user
-- ---------------------------------------------------------------------------

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Config and guest limit (PRODUCT.md §5 app_config, §7)
-- ---------------------------------------------------------------------------

insert into public.app_config (key, value) values
  ('free_guest_limit', '100'),
  ('premium_guest_limit', '300'),
  ('addon_guest_step', '200'),
  ('daily_send_warning', '120'),
  ('phone_retention_days', '90');

create function public.config_int(config_key text)
returns int
language sql
stable
set search_path = ''
as $$
  select (value #>> '{}')::int from public.app_config where key = config_key;
$$;

-- guest_limit is not stored: free/premium base + one step per active (not refunded) limit_addon.
create function public.event_guest_limit(p_event_id uuid)
returns int
language sql
stable
set search_path = ''
as $$
  select
    case when e.is_paid
      then public.config_int('premium_guest_limit')
      else public.config_int('free_guest_limit')
    end
    + public.config_int('addon_guest_step') * (
      select count(*)::int
      from public.purchases p
      where p.event_id = e.id
        and p.kind = 'limit_addon'
        and p.refunded_at is null
    )
  from public.events e
  where e.id = p_event_id;
$$;
