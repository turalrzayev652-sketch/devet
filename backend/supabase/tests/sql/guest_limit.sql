-- Guest limit tests (T13). Run after migrations + seed; everything is rolled back.

begin;

insert into public.events (id, type, title_names, starts_at, venue_name, template_id)
values ('55555555-5555-5555-5555-555555555555', 'birthday', 'Limit test', now() + interval '30 days', 'Hall', 'free-01');
insert into public.event_members (event_id, user_id, role)
values ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'owner');

-- Insert as the signed-in owner (RLS path, like the app).
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);

do $$
declare
  ev constant uuid := '55555555-5555-5555-5555-555555555555';
  rejected boolean;
  msg text;
begin
  -- Free template: 100
  assert public.event_guest_limit(ev) = 100, 'free limit 100';
  insert into public.guests (event_id, name) select ev, 'G' || i from generate_series(1, 100) i;
  assert (select count(*) from public.guests where event_id = ev) = 100, '100 guests inserted';

  begin
    insert into public.guests (event_id, name) values (ev, 'G101');
    rejected := false;
  exception when others then
    rejected := true; msg := sqlerrm;
  end;
  assert rejected and msg = 'guest_limit_exceeded', '101st guest rejected: ' || coalesce(msg, 'not rejected');

  -- Other events are not affected by this event's count
  insert into public.guests (event_id, name) values ('22222222-2222-2222-2222-222222222222', 'Seed event extra');

  -- Bulk import that would cross the limit is rejected as a whole
  delete from public.guests where event_id = ev and name in ('G1', 'G2', 'G3');
  begin
    insert into public.guests (event_id, name) select ev, 'B' || i from generate_series(1, 4) i;
    rejected := false;
  exception when others then
    rejected := true;
  end;
  assert rejected, 'bulk insert crossing the limit rejected';
  assert (select count(*) from public.guests where event_id = ev) = 97, 'failed bulk insert left no rows';
  insert into public.guests (event_id, name) select ev, 'B' || i from generate_series(1, 3) i;
  assert (select count(*) from public.guests where event_id = ev) = 100, 'bulk insert up to the limit allowed';

  -- Updating a guest without moving it is not blocked at the limit
  update public.guests set table_no = '1' where event_id = ev and name = 'G50';
end $$;

-- Paid template and add-ons (written by service role in production; postgres here)
reset role;
update public.events set is_paid = true where id = '55555555-5555-5555-5555-555555555555';
set local role authenticated;

do $$
declare ev constant uuid := '55555555-5555-5555-5555-555555555555'; rejected boolean;
begin
  assert public.event_guest_limit(ev) = 300, 'paid limit 300';
  insert into public.guests (event_id, name) select ev, 'P' || i from generate_series(1, 200) i;
  begin
    insert into public.guests (event_id, name) values (ev, 'P301');
    rejected := false;
  exception when others then rejected := true;
  end;
  assert rejected, '301st guest rejected';
end $$;

reset role;
insert into public.purchases (user_id, event_id, kind, store, store_transaction_id)
values ('11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', 'limit_addon', 'google', 'limit-test-1');
set local role authenticated;

do $$
declare ev constant uuid := '55555555-5555-5555-5555-555555555555'; rejected boolean;
begin
  assert public.event_guest_limit(ev) = 500, 'addon +200 -> 500';
  insert into public.guests (event_id, name) select ev, 'A' || i from generate_series(1, 200) i;
  begin
    insert into public.guests (event_id, name) values (ev, 'A501');
    rejected := false;
  exception when others then rejected := true;
  end;
  assert rejected, '501st guest rejected';
end $$;

-- Limits come from app_config, not code
reset role;
update public.app_config set value = '250' where key = 'addon_guest_step';
do $$ begin
  assert public.event_guest_limit('55555555-5555-5555-5555-555555555555') = 550, 'config change applies';
end $$;

-- Refunded add-on no longer counts
update public.purchases set refunded_at = now() where store_transaction_id = 'limit-test-1';
do $$ begin
  assert public.event_guest_limit('55555555-5555-5555-5555-555555555555') = 300, 'refunded addon ignored';
end $$;

select 'guest_limit: ALL PASSED' as result;
rollback;
