-- 004_guest_limit.sql — server-side guest limit (T13, spec/PRODUCT.md §7).
-- Limits come from app_config via event_guest_limit(); nothing is hard-coded here.

create function public.enforce_guest_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit int;
  v_count int;
begin
  if tg_op = 'UPDATE' and new.event_id = old.event_id then
    return new;
  end if;

  -- Serialize concurrent inserts for the same event so two sessions cannot both pass the check.
  perform 1 from public.events where id = new.event_id for update;

  v_limit := public.event_guest_limit(new.event_id);
  -- Rows inserted earlier in the same statement are visible here, so bulk imports are counted too.
  select count(*) into v_count from public.guests where event_id = new.event_id;

  if v_count + 1 > v_limit then
    raise exception 'guest_limit_exceeded'
      using errcode = 'P0001',
            detail = format('limit=%s', v_limit),
            hint = 'purchase_required';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_guest_limit() from public, anon, authenticated;

create trigger guests_enforce_limit
  before insert or update of event_id on public.guests
  for each row execute function public.enforce_guest_limit();
