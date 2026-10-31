-- event_guest_limit as seen by apps (migration 012). Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, email) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'c@devet.test'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@devet.test');
insert into public.event_members (event_id, user_id, role)
values ('22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'cohost');
-- Add-on bought by the owner (A).
insert into public.purchases (user_id, event_id, kind, store, store_transaction_id)
values ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'limit_addon', 'google', 'VIS-1');

select is(public.event_guest_limit('22222222-2222-2222-2222-222222222222'), 300, 'server context (no user): 100 + 200');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select is(public.event_guest_limit('22222222-2222-2222-2222-222222222222'), 300, 'owner sees 300');

select set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
select is(public.event_guest_limit('22222222-2222-2222-2222-222222222222'), 300, 'cohost also sees the owner''s add-on');
select is_empty($$ select 1 from public.purchases $$, 'cohost still cannot read the owner''s purchase rows');

select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select is(public.event_guest_limit('22222222-2222-2222-2222-222222222222'), null, 'non-member gets null');

reset role;
select * from finish();
rollback;
