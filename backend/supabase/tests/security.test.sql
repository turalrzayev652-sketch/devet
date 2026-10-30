-- Security tests (T18): cross-tenant isolation, anon surface, cohost limits.
-- Run with: supabase test db
-- A = seed owner of event 2222…, B = owner of event 9999…, C = cohost of A's event.

begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

-- ---------------------------------------------------------------------------
-- Fixtures (as postgres)
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@devet.test'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'c@devet.test');

insert into public.events (id, type, title_names, starts_at, venue_name, template_id)
values ('99999999-9999-9999-9999-999999999999', 'birthday', 'B event', now() + interval '30 days', 'Hall', 'free-01');
insert into public.event_members (event_id, user_id, role) values
  ('99999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'owner'),
  ('22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'cohost');
insert into public.guests (event_id, code, name) values
  ('99999999-9999-9999-9999-999999999999', 'BBBB0001', 'B guest');
insert into public.purchases (user_id, event_id, kind, store, store_transaction_id) values
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'limit_addon', 'google', 'sec-a'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '99999999-9999-9999-9999-999999999999', 'limit_addon', 'apple', 'sec-b');

-- Runs a DML statement and returns the number of affected rows (RLS hides rows instead of raising).
create function pg_temp.affected(p_sql text) returns int language plpgsql as $$
declare n int;
begin
  execute p_sql;
  get diagnostics n = row_count;
  return n;
end $$;

create function pg_temp.login(p_uid uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true),
         set_config('request.jwt.claims', coalesce(json_build_object('sub', p_uid, 'role', 'authenticated')::text, ''), true);
$$;

-- Migrations revoke the default EXECUTE-to-PUBLIC, so test helpers need explicit grants.
grant execute on function pg_temp.affected(text), pg_temp.login(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- User A cannot see or change B's data (and vice versa)
-- ---------------------------------------------------------------------------

set local role authenticated;
select pg_temp.login('11111111-1111-1111-1111-111111111111');

select is_empty($$ select 1 from public.events where id = '99999999-9999-9999-9999-999999999999' $$, 'A cannot see B''s event');
select is_empty($$ select 1 from public.guests where event_id = '99999999-9999-9999-9999-999999999999' $$, 'A cannot see B''s guests');
select is_empty($$ select 1 from public.purchases where store_transaction_id = 'sec-b' $$, 'A cannot see B''s purchases');
select is_empty($$ select 1 from public.event_members where event_id = '99999999-9999-9999-9999-999999999999' $$, 'A cannot see B''s members');
select is_empty($$ select 1 from public.profiles where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$, 'A cannot see B''s profile');
select is(pg_temp.affected($$ update public.events set title_names = 'x' where id = '99999999-9999-9999-9999-999999999999' $$), 0, 'A cannot update B''s event');
select is(pg_temp.affected($$ update public.guests set name = 'x' where event_id = '99999999-9999-9999-9999-999999999999' $$), 0, 'A cannot update B''s guests');
select is(pg_temp.affected($$ delete from public.guests where event_id = '99999999-9999-9999-9999-999999999999' $$), 0, 'A cannot delete B''s guests');
select is(pg_temp.affected($$ delete from public.events where id = '99999999-9999-9999-9999-999999999999' $$), 0, 'A cannot delete B''s event');
select is(pg_temp.affected($$ update public.profiles set display_name = 'x' where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$), 0, 'A cannot update B''s profile');
select throws_ok($$ insert into public.guests (event_id, name) values ('99999999-9999-9999-9999-999999999999', 'x') $$,
  '42501'::char(5), null::text, 'A cannot add guests to B''s event');
select throws_ok($$ insert into public.event_members (event_id, user_id, role) values ('99999999-9999-9999-9999-999999999999', '11111111-1111-1111-1111-111111111111', 'cohost') $$,
  '42501'::char(5), null::text, 'A cannot join B''s event');
select throws_ok($$ insert into public.purchases (user_id, event_id, kind, store, store_transaction_id) values ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'limit_addon', 'google', 'forged') $$,
  '42501'::char(5), null::text, 'A cannot write purchases');
select throws_ok($$ update public.events set is_paid = true where id = '22222222-2222-2222-2222-222222222222' $$,
  '42501'::char(5), null::text, 'A cannot set is_paid');
select is((select count(*)::int from public.purchases), 1, 'A sees only own purchase');

select pg_temp.login('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
select is_empty($$ select 1 from public.events where id = '22222222-2222-2222-2222-222222222222' $$, 'B cannot see A''s event');
select is_empty($$ select 1 from public.guests where event_id = '22222222-2222-2222-2222-222222222222' $$, 'B cannot see A''s guests');
select is_empty($$ select 1 from public.purchases where store_transaction_id = 'sec-a' $$, 'B cannot see A''s purchases');
select is(pg_temp.affected($$ update public.guests set rsvp_status = 'no' where event_id = '22222222-2222-2222-2222-222222222222' $$), 0, 'B cannot change A''s RSVPs');

-- ---------------------------------------------------------------------------
-- Cohost C: edits but cannot delete
-- ---------------------------------------------------------------------------

select pg_temp.login('cccccccc-cccc-cccc-cccc-cccccccccccc');
select is(pg_temp.affected($$ update public.guests set table_no = '9' where code = 'K7D2M9QX' $$), 1, 'cohost can edit guests');
select is(pg_temp.affected($$ delete from public.guests where code = 'K7D2M9QX' $$), 0, 'cohost cannot delete guests');
select is(pg_temp.affected($$ delete from public.events where id = '22222222-2222-2222-2222-222222222222' $$), 0, 'cohost cannot delete the event');
select is(pg_temp.affected($$ delete from public.event_members where event_id = '22222222-2222-2222-2222-222222222222' $$), 0, 'cohost cannot remove members');
select is(public.create_cohost_invite('22222222-2222-2222-2222-222222222222', 'x@devet.test', 'none')->>'error', 'not_owner', 'cohost cannot invite');
select is_empty($$ select 1 from public.purchases $$, 'cohost cannot see owner''s purchases');

-- ---------------------------------------------------------------------------
-- anon: only the three guest RPCs
-- ---------------------------------------------------------------------------

reset role;
set local role anon;
select pg_temp.login(null);

select throws_ok($$ select 1 from public.events $$, '42501'::char(5), null::text, 'anon cannot read events');
select throws_ok($$ select 1 from public.guests $$, '42501'::char(5), null::text, 'anon cannot read guests');
select throws_ok($$ select 1 from public.purchases $$, '42501'::char(5), null::text, 'anon cannot read purchases');
select throws_ok($$ select 1 from public.profiles $$, '42501'::char(5), null::text, 'anon cannot read profiles');
select throws_ok($$ update public.guests set rsvp_status = 'yes' $$, '42501'::char(5), null::text, 'anon cannot write guests');
select is(public.get_preview('K7D2M9QX')->>'ok', 'true', 'anon can call get_preview');
select is(public.get_invite('K7D2M9QX')->>'ok', 'true', 'anon can call get_invite');
select is(public.submit_rsvp('K7D2M9QX', 'yes', 2)->>'ok', 'true', 'anon can call submit_rsvp');
select throws_ok($$ select public.accept_cohost_invite('ZZZZZZZZ') $$, '42501'::char(5), null::text, 'anon cannot call app RPCs');

reset role;

select is(
  (select array_agg(p.proname::text order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  array['get_invite', 'get_preview', 'submit_rsvp'],
  'anon can execute exactly the three guest RPCs'
);

select is(
  (select array_agg(distinct table_name::text || ':' || privilege_type::text)
   from information_schema.role_table_grants
   where grantee = 'anon' and table_schema = 'public'),
  array['templates:SELECT'],
  'anon has table access only to templates (read)'
);

select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0,
  'RLS enabled on every public table'
);

select * from finish();
rollback;
