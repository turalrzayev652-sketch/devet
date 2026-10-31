-- Account deletion tests (T17). Run with: supabase test db
-- A (seed) owns event 2222… and is cohost of B's event; B stays.

begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@devet.test');
insert into public.events (id, type, title_names, starts_at, venue_name, template_id)
values ('efefefef-efef-efef-efef-efefefefefef', 'birthday', 'B event', now() + interval '10 days', 'Hall', 'free-01');
insert into public.event_members (event_id, user_id, role) values
  ('efefefef-efef-efef-efef-efefefefefef', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'owner'),
  ('efefefef-efef-efef-efef-efefefefefef', '11111111-1111-1111-1111-111111111111', 'cohost');
insert into public.guests (event_id, code, name, added_by)
values ('efefefef-efef-efef-efef-efefefefefef', 'BGST0001', 'Added by A', '11111111-1111-1111-1111-111111111111');
insert into public.purchases (user_id, event_id, kind, store, store_transaction_id) values
  ('11111111-1111-1111-1111-111111111111', 'efefefef-efef-efef-efef-efefefefefef', 'limit_addon', 'google', 'GPA.A-FOR-B'),
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'limit_addon', 'google', 'GPA.A-OWN');

-- Plan
select is(public.account_deletion_plan('11111111-1111-1111-1111-111111111111')->'owned_events', '["22222222-2222-2222-2222-222222222222"]'::jsonb, 'plan: owned events');
select is(public.account_deletion_plan('11111111-1111-1111-1111-111111111111')->'cohost_events', '["efefefef-efef-efef-efef-efefefefefef"]'::jsonb, 'plan: cohost events');
select is(jsonb_array_length(public.account_deletion_plan('11111111-1111-1111-1111-111111111111')->'preview_files'), 10, 'plan: preview file per guest of owned events');
select ok(public.account_deletion_plan('11111111-1111-1111-1111-111111111111')->'preview_files' ? 'K7D2M9QX.jpg', 'plan: preview names are <CODE>.jpg');

-- Delete data
select is(public.delete_account_data('11111111-1111-1111-1111-111111111111'), '{"ok": true, "deleted_events": 1, "left_events": 1}'::jsonb, 'owned event deleted, cohost membership removed');
select is((select count(*)::int from public.events where id = '22222222-2222-2222-2222-222222222222'), 0, 'owned event gone');
select is((select count(*)::int from public.guests where event_id = '22222222-2222-2222-2222-222222222222'), 0, 'its guests gone');
select is((select count(*)::int from public.purchases where store_transaction_id = 'GPA.A-OWN'), 0, 'its purchases gone');
select is((select count(*)::int from public.events where id = 'efefefef-efef-efef-efef-efefefefefef'), 1, 'other owner''s event stays');
select is((select count(*)::int from public.event_members where user_id = '11111111-1111-1111-1111-111111111111'), 0, 'no memberships left');
select is(public.event_guest_limit('efefefef-efef-efef-efef-efefefefefef'), 300, 'add-on bought as cohost still counts for the event');

-- Auth user deletion (what the Auth admin API does)
delete from auth.identities where user_id = '11111111-1111-1111-1111-111111111111';
delete from auth.users where id = '11111111-1111-1111-1111-111111111111';
select is((select user_id from public.purchases where store_transaction_id = 'GPA.A-FOR-B'), null, 'purchase kept, buyer cleared');
select is((select count(*)::int from public.profiles where id = '11111111-1111-1111-1111-111111111111'), 0, 'profile gone');

set local role authenticated;
select throws_ok($$ select public.delete_account_data('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$, '42501'::char(5), null::text, 'apps cannot call delete_account_data');
reset role;

select * from finish();
rollback;
