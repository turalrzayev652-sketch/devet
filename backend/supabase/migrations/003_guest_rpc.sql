-- 003_guest_rpc.sql — guest-facing RPCs (T12, spec/PRODUCT.md §6, §8).
-- anon may call only get_preview, get_invite, submit_rsvp.

-- ---------------------------------------------------------------------------
-- Lock down function execution for anon
-- ---------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon;
alter default privileges in schema public revoke execute on functions from public, anon;

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------

insert into public.app_config (key, value) values
  -- get_invite / submit_rsvp return event_past this many days after starts_at.
  ('invite_past_days', '7'),
  -- Public Storage base; preview_url = base || '/' || guests.preview_path. Set per environment.
  ('storage_public_base_url', '"http://127.0.0.1:54321/storage/v1/object/public"');

-- ---------------------------------------------------------------------------
-- Display name forms (PRODUCT.md §8). Must match /spec/i18n/invite.json (T21).
-- ---------------------------------------------------------------------------

create table public.display_name_forms (
  lang public.lang not null,
  salutation public.salutation,          -- null row = with_family suffix pattern
  pattern text not null,                 -- {name} or {display}
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  unique nulls not distinct (lang, salutation)
);

alter table public.display_name_forms enable row level security;
revoke all on public.display_name_forms from anon, authenticated;

insert into public.display_name_forms (lang, salutation, pattern) values
  ('az', 'muellim', '{name} müəllim'), ('az', 'xanim', '{name} xanım'),
  ('az', 'bey', '{name} bəy'),         ('az', 'none', '{name}'),
  ('az', null, '{display} və ailəsi'),
  ('ru', 'muellim', '{name} муаллим'), ('ru', 'xanim', '{name} ханум'),
  ('ru', 'bey', '{name} бей'),         ('ru', 'none', '{name}'),
  ('ru', null, '{display} с семьёй'),
  ('en', 'muellim', 'Mr. {name}'),     ('en', 'xanim', 'Ms. {name}'),
  ('en', 'bey', 'Mr. {name}'),         ('en', 'none', '{name}'),
  ('en', null, '{display} and family'),
  ('tr', 'muellim', '{name} Bey'),     ('tr', 'xanim', '{name} Hanım'),
  ('tr', 'bey', '{name} Bey'),         ('tr', 'none', '{name}'),
  ('tr', null, '{display} ve ailesi');

create function public.format_display_name(
  p_name text, p_salutation public.salutation, p_with_family boolean, p_lang public.lang
)
returns text
language sql
stable
set search_path = ''
as $$
  with base as (
    select replace(
      coalesce(
        (select pattern from public.display_name_forms where lang = p_lang and salutation = p_salutation),
        '{name}'
      ),
      '{name}', btrim(p_name)
    ) as display
  )
  select case
    when p_with_family then replace(
      coalesce(
        (select pattern from public.display_name_forms where lang = p_lang and salutation is null),
        '{display}'
      ),
      '{display}', base.display
    )
    else base.display
  end
  from base;
$$;

-- ---------------------------------------------------------------------------
-- Shared lookup
-- ---------------------------------------------------------------------------

-- Normalizes the code; returns the guest row id or null if the format is wrong / unknown.
create function public.find_guest_id(p_code text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select g.id
  from public.guests g
  where g.code = upper(btrim(p_code))
    and upper(btrim(p_code)) ~ '^[0-9A-HJKMNP-TV-Z]{8}$';
$$;

create function public.is_event_past(p_starts_at timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select now() > p_starts_at + make_interval(days => public.config_int('invite_past_days'));
$$;

-- ---------------------------------------------------------------------------
-- get_preview(code) — no side effects (called by WhatsApp link crawler)
-- ---------------------------------------------------------------------------

create function public.get_preview(code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  g public.guests;
  e public.events;
  v_lang public.lang;
  v_base text;
begin
  select * into g from public.guests where id = public.find_guest_id(get_preview.code);
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  select * into e from public.events where id = g.event_id;
  v_lang := coalesce(g.lang, e.default_lang);
  v_base := (select value #>> '{}' from public.app_config where key = 'storage_public_base_url');

  return jsonb_build_object(
    'ok', true,
    'lang', v_lang,
    'display_name', public.format_display_name(g.name, g.salutation, g.with_family, v_lang),
    'event_type', e.type,
    'title_names', e.title_names,
    'starts_at', e.starts_at,
    'preview_url', case when g.preview_path is not null then v_base || '/' || g.preview_path end,
    'template_id', e.template_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- get_invite(code) — writes opened_at on first call
-- ---------------------------------------------------------------------------

create function public.get_invite(code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g public.guests;
  e public.events;
  v_lang public.lang;
  v_tablemates jsonb;
begin
  select * into g from public.guests where id = public.find_guest_id(get_invite.code);
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  select * into e from public.events where id = g.event_id;
  if public.is_event_past(e.starts_at) then
    return jsonb_build_object('ok', false, 'error', 'event_past');
  end if;

  update public.guests set opened_at = now() where id = g.id and opened_at is null;

  v_lang := coalesce(g.lang, e.default_lang);

  if e.show_tablemates and g.table_no is not null then
    select coalesce(jsonb_agg(public.format_display_name(t.name, t.salutation, false, v_lang) order by t.name), '[]'::jsonb)
      into v_tablemates
    from public.guests t
    where t.event_id = g.event_id
      and t.table_no = g.table_no
      and t.id <> g.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'event', jsonb_build_object(
      'type', e.type,
      'title_names', e.title_names,
      'host_names', e.host_names,
      'starts_at', e.starts_at,
      'venue_name', e.venue_name,
      'venue_address', e.venue_address,
      'maps_url', e.maps_url,
      'lat', e.venue_lat,
      'lng', e.venue_lng,
      'template_id', e.template_id,
      'customization', e.customization,
      'is_paid', e.is_paid
    ),
    'guest', jsonb_build_object(
      'salutation', g.salutation,
      'name', g.name,
      'with_family', g.with_family,
      'invited_count', g.invited_count,
      'lang', v_lang,
      'table_no', g.table_no,
      'rsvp_status', g.rsvp_status,
      'rsvp_count', g.rsvp_count
    ),
    'tablemates', coalesce(v_tablemates, '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- submit_rsvp(code, status, count)
-- ---------------------------------------------------------------------------

create function public.submit_rsvp(code text, status public.rsvp_status, count int)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g public.guests;
  e public.events;
  v_count int;
begin
  select * into g from public.guests where id = public.find_guest_id(submit_rsvp.code);
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  select * into e from public.events where id = g.event_id;
  if public.is_event_past(e.starts_at) then
    return jsonb_build_object('ok', false, 'error', 'event_past');
  end if;

  if submit_rsvp.status = 'yes' then
    if submit_rsvp.count is null or submit_rsvp.count < 1 or submit_rsvp.count > g.invited_count then
      return jsonb_build_object('ok', false, 'error', 'invalid_count');
    end if;
    v_count := submit_rsvp.count;
  elsif submit_rsvp.status = 'no' then
    v_count := 0;
  else
    -- 'pending' is not an answer.
    return jsonb_build_object('ok', false, 'error', 'invalid_count');
  end if;

  update public.guests
  set rsvp_status = submit_rsvp.status, rsvp_count = v_count, rsvp_at = now()
  where id = g.id;

  return jsonb_build_object('ok', true, 'rsvp_status', submit_rsvp.status, 'rsvp_count', v_count);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function public.find_guest_id(text) from public, anon, authenticated;
revoke all on function public.format_display_name(text, public.salutation, boolean, public.lang) from public, anon;
revoke all on function public.is_event_past(timestamptz) from public, anon;

grant execute on function public.get_preview(text) to anon, authenticated;
grant execute on function public.get_invite(text) to anon, authenticated;
grant execute on function public.submit_rsvp(text, public.rsvp_status, int) to anon, authenticated;
