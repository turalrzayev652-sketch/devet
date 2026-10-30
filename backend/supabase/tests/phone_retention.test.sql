-- Phone retention tests (T16). Run after migrations + seed; everything is rolled back.

begin;
create extension if not exists pgtap with schema extensions;
select plan(1);

insert into public.events (id, type, title_names, starts_at, venue_name, template_id) values
  ('77777777-7777-7777-7777-777777777777', 'wedding', 'Old', now() - interval '91 days', 'Hall', 'free-01'),
  ('88888888-8888-8888-8888-888888888888', 'wedding', 'Recent', now() - interval '89 days', 'Hall', 'free-01');

insert into public.guests (event_id, code, name, phone_e164, rsvp_status, rsvp_count, table_no) values
  ('77777777-7777-7777-7777-777777777777', 'RTD00001', 'Old guest', '+994501110000', 'yes', 2, '4'),
  ('77777777-7777-7777-7777-777777777777', 'RTD00002', 'Old no phone', null, 'no', 0, null),
  ('88888888-8888-8888-8888-888888888888', 'NWW00001', 'Recent guest', '+994502220000', 'yes', 1, null);

do $$
declare n int;
begin
  assert exists (select 1 from cron.job where jobname = 'purge-expired-phones' and command like '%purge_expired_phones%'),
    'cron job scheduled';

  n := public.purge_expired_phones();
  assert n = 1, 'one phone purged, got ' || n;

  assert (select phone_e164 from public.guests where code = 'RTD00001') is null, 'old event phone deleted';
  assert (select name || '|' || rsvp_status || '|' || rsvp_count || '|' || table_no from public.guests where code = 'RTD00001')
         = 'Old guest|yes|2|4', 'name and statistics kept';
  assert (select phone_e164 from public.guests where code = 'NWW00001') = '+994502220000', 'event < 90 days keeps phone';
  assert (select count(*) from public.guests where phone_e164 is not null and event_id = '22222222-2222-2222-2222-222222222222') = 9,
    'future seed event untouched';

  assert public.purge_expired_phones() = 0, 'second run is a no-op';

  -- Retention period comes from app_config
  update public.app_config set value = '30' where key = 'phone_retention_days';
  assert public.purge_expired_phones() = 1, 'shorter retention purges the 89-day event';
end $$;

-- Not callable by clients
set local role authenticated;
do $$
declare denied boolean;
begin
  begin perform public.purge_expired_phones(); denied := false; exception when insufficient_privilege then denied := true; end;
  assert denied, 'authenticated cannot call purge_expired_phones';
end $$;

reset role;
select pass('phone_retention: all assertions passed');
select * from finish();
rollback;
