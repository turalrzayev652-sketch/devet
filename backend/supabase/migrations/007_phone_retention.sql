-- 007_phone_retention.sql — delete guest phone numbers after the retention period (T16, PRODUCT.md §7).
-- Names, RSVP answers and statistics stay; only phone_e164 is cleared.

create extension if not exists pg_cron;

create function public.purge_expired_phones()
returns int
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_days int := public.config_int('phone_retention_days');
  v_count int;
begin
  update public.guests g
  set phone_e164 = null
  from public.events e
  where e.id = g.event_id
    and g.phone_e164 is not null
    and e.starts_at + make_interval(days => v_days) < now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.purge_expired_phones() from public, anon, authenticated;

-- Daily at 03:00 UTC. Re-running the migration updates the job with the same name.
select cron.schedule('purge-expired-phones', '0 3 * * *', 'select public.purge_expired_phones()');
