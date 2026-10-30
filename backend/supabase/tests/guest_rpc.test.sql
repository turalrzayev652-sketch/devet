-- Guest RPC tests (T12). Run after migrations + seed; everything is rolled back.
-- ASSERT-based checks wrapped in one pgTAP test (any failed assert aborts the file).

begin;
create extension if not exists pgtap with schema extensions;
select plan(1);

-- A past event (8 days ago) with one guest.
insert into public.events (id, type, title_names, starts_at, venue_name, default_lang, template_id)
values ('33333333-3333-3333-3333-333333333333', 'birthday', 'Past party', now() - interval '8 days', 'Hall', 'en', 'free-01');
insert into public.guests (event_id, code, name) values ('33333333-3333-3333-3333-333333333333', 'PAST0001', 'Old');
-- A recent event (6 days ago) is still open.
insert into public.events (id, type, title_names, starts_at, venue_name, default_lang, template_id)
values ('44444444-4444-4444-4444-444444444444', 'jubilee', 'Recent', now() - interval '6 days', 'Hall', 'az', 'free-01');
insert into public.guests (event_id, code, name, preview_path)
values ('44444444-4444-4444-4444-444444444444', 'RECENT01', 'New', 'previews/RECENT01.jpg');

set local role anon;
select set_config('request.jwt.claim.sub', '', true);

do $$
declare r jsonb;
begin
  -- get_preview -------------------------------------------------------------
  r := public.get_preview('K7D2M9QX');
  assert r->>'ok' = 'true', 'preview ok';
  assert r->>'display_name' = 'Elçin müəllim və ailəsi', 'az muellim + family: ' || (r->>'display_name');
  assert r->>'lang' = 'az', 'event default lang';
  assert r->>'event_type' = 'wedding' and r->>'title_names' = 'Aysel və Ramin' and r->>'template_id' = 'free-01', 'preview event fields';
  assert r->'preview_url' = 'null'::jsonb, 'no preview_path -> null url';
  assert not (r ? 'phone_e164') and not (r ? 'name'), 'no phone / raw fields';

  r := public.get_preview('r5t6y7b2 ');
  assert r->>'display_name' = 'Rəşad бей с семьёй', 'ru bey + family, code normalized: ' || (r->>'display_name');
  assert r->>'lang' = 'ru', 'guest lang overrides';
  assert public.get_preview('M9N8V7C6')->>'display_name' = 'Aytən', 'en none';
  assert public.get_preview('Q2W3E4R5')->>'display_name' = 'Səbinə Hanım ve ailesi', 'tr xanim + family';
  assert public.get_preview('A1S2D3F4')->>'display_name' = 'Vüqar müəllim', 'az muellim';
  assert public.get_preview('RECENT01')->>'preview_url' like '%/previews/RECENT01.jpg', 'preview_url from path';

  assert public.get_preview('ZZZZZZZZ') = '{"ok":false,"error":"not_found"}', 'preview unknown code';
  assert public.get_preview('bad') = '{"ok":false,"error":"not_found"}', 'preview malformed code';
  assert public.get_preview(null) = '{"ok":false,"error":"not_found"}', 'preview null code';
  assert public.get_preview('PAST0001')->>'ok' = 'true', 'preview still works for past event (crawler)';
end $$;

-- get_preview has no side effects
reset role;
do $$ begin
  assert (select opened_at from public.guests where code = 'K7D2M9QX') is null, 'preview must not set opened_at';
end $$;
set local role anon;

do $$
declare r jsonb; first_open timestamptz;
begin
  -- get_invite ----------------------------------------------------------------
  r := public.get_invite('K7D2M9QX');
  assert r->>'ok' = 'true', 'invite ok';
  assert r->'event'->>'venue_name' = 'Gülüstan sarayı' and (r->'event'->>'lat')::float = 40.3536, 'event fields';
  assert r->'event'->>'is_paid' = 'false', 'is_paid exposed';
  assert r->'guest'->>'name' = 'Elçin' and r->'guest'->>'salutation' = 'muellim', 'guest fields';
  assert (r->'guest'->>'invited_count')::int = 4 and r->'guest'->>'with_family' = 'true', 'guest counts';
  assert r->'guest'->>'lang' = 'az' and r->'guest'->>'table_no' = '12', 'guest lang/table';
  assert not (r->'guest' ? 'phone_e164') and not (r->'guest' ? 'code'), 'no phone/code in invite';
  assert r->'tablemates' = '["Leyla xanım", "Rəşad bəy"]'::jsonb, 'tablemates in viewer lang, self excluded: ' || (r->>'tablemates');

  -- tablemates in guest's own language
  r := public.get_invite('R5T6Y7B2');
  assert r->'tablemates' = '["Elçin муаллим", "Leyla ханум"]'::jsonb, 'ru tablemates: ' || (r->>'tablemates');

  -- no table -> empty tablemates
  assert public.get_invite('Z9X8C7V6')->'tablemates' = '[]'::jsonb, 'no table_no -> []';

  assert public.get_invite('ZZZZZZZZ') = '{"ok":false,"error":"not_found"}', 'invite unknown code';
  assert public.get_invite('PAST0001') = '{"ok":false,"error":"event_past"}', 'invite past event';
  assert public.get_invite('RECENT01')->>'ok' = 'true', 'event 6 days ago still open';

  -- submit_rsvp -----------------------------------------------------------------
  r := public.submit_rsvp('K7D2M9QX', 'yes', 3);
  assert r = '{"ok":true,"rsvp_status":"yes","rsvp_count":3}', 'rsvp yes 3: ' || r::text;
  r := public.submit_rsvp('K7D2M9QX', 'yes', 4);
  assert r->>'rsvp_count' = '4', 'rsvp yes = invited_count allowed, answer can change';
  assert public.submit_rsvp('K7D2M9QX', 'yes', 5) = '{"ok":false,"error":"invalid_count"}', 'over invited_count';
  assert public.submit_rsvp('K7D2M9QX', 'yes', 0) = '{"ok":false,"error":"invalid_count"}', 'yes with 0';
  assert public.submit_rsvp('K7D2M9QX', 'yes', null) = '{"ok":false,"error":"invalid_count"}', 'yes with null';
  assert public.submit_rsvp('K7D2M9QX', 'pending', 1) = '{"ok":false,"error":"invalid_count"}', 'pending is not an answer';
  r := public.submit_rsvp('K7D2M9QX', 'no', 7);
  assert r = '{"ok":true,"rsvp_status":"no","rsvp_count":0}', 'no forces count 0: ' || r::text;
  assert public.submit_rsvp('ZZZZZZZZ', 'yes', 1) = '{"ok":false,"error":"not_found"}', 'rsvp unknown code';
  assert public.submit_rsvp('PAST0001', 'yes', 1) = '{"ok":false,"error":"event_past"}', 'rsvp past event';

  -- get_invite reflects the answer
  r := public.get_invite('K7D2M9QX');
  assert r->'guest'->>'rsvp_status' = 'no' and r->'guest'->>'rsvp_count' = '0', 'invite shows latest rsvp';
end $$;

-- opened_at written once; rsvp_at written
reset role;
do $$
declare t1 timestamptz;
begin
  select opened_at into t1 from public.guests where code = 'K7D2M9QX';
  assert t1 is not null, 'get_invite sets opened_at';
  assert (select rsvp_at from public.guests where code = 'K7D2M9QX') is not null, 'rsvp_at set';
  assert (select opened_at from public.guests where code = 'PAST0001') is null, 'past event not marked opened';
end $$;

-- anon: no tables, no other functions
set local role anon;
do $$
declare denied boolean;
begin
  begin perform 1 from public.guests limit 1; denied := false; exception when insufficient_privilege then denied := true; end;
  assert denied, 'anon cannot read guests';
  begin perform public.event_guest_limit('22222222-2222-2222-2222-222222222222'); denied := false; exception when insufficient_privilege then denied := true; end;
  assert denied, 'anon cannot call event_guest_limit';
  begin perform public.format_display_name('x', 'none', false, 'az'); denied := false; exception when insufficient_privilege then denied := true; end;
  assert denied, 'anon cannot call format_display_name';
  begin perform public.config_int('free_guest_limit'); denied := false; exception when insufficient_privilege then denied := true; end;
  assert denied, 'anon cannot call config_int';
  begin perform 1 from public.display_name_forms; denied := false; exception when insufficient_privilege then denied := true; end;
  assert denied, 'anon cannot read display_name_forms';
end $$;

reset role;
select pass('guest_rpc: all assertions passed');
select * from finish();
rollback;
